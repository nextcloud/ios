// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import Alamofire
import LucidBanner

extension NCCollectionViewCommon: UICollectionViewDelegate {
    @MainActor
    func didSelectMetadata(_ metadata: tableMetadata, withOcIds: Bool, viewerTransitionSource: NCMediaViewerTransitionSource?) async {
        let capabilities = await NKCapabilities.shared.getCapabilities(for: session.account)

        if metadata.e2eEncrypted {
            if capabilities.e2EEEnabled {
                if !NCPreferences().isEndToEndEnabled(account: metadata.account) {
                    do {
                        let e2ee = NCEndToEndSetup(controller: controller)
                        try await e2ee.start()
                    } catch let error as NKError {
                        if error.errorCode == NSUserCancelledError {
                            return
                        }
                        await showErrorBanner(
                            windowScene: windowScene,
                            text: error.errorDescription
                        )
                        return
                    } catch {
                        // fallback (non NKError)
                        await showErrorBanner(
                            windowScene: windowScene,
                            text: error.localizedDescription
                        )
                        return
                    }
                }
            } else {
                await showInfoBanner(windowScene: windowScene, text: "_e2e_server_disabled_")
                return
            }
        }

        func downloadFile() async {
            var downloadRequest: DownloadRequest?
            var banner: LucidBanner?
            var token: Int?

            (banner, token) = showHudBanner(windowScene: windowScene,
                                            title: "_download_in_progress_",
                                            stage: .button,
                                            onButtonTap: {
                if let request = downloadRequest {
                    request.cancel()
                }
            })

            guard let  metadata = await database.setMetadataSessionInWaitDownloadAsync(ocId: metadata.ocId,
                                                                                       session: self.networking.sessionDownload,
                                                                                       selector: global.selectorLoadFileView,
                                                                                       sceneIdentifier: self.controller?.sceneIdentifier) else {
                return
            }

            let results = await self.networking.downloadFile(metadata: metadata) { request in
                downloadRequest = request
            } progressHandler: { progress in
                Task {@MainActor in
                    banner?.update(
                        payload: LucidBannerPayload.Update(progress: Double(progress.fractionCompleted)),
                        for: token)
                }
            }

            if let banner {
                await banner.dismissAsync()
            }

            if results.nkError == .success || results.nkError == .cancelled {
                print("ok")
            } else {
                await showErrorBanner(windowScene: windowScene, text: results.nkError.errorDescription, errorCode: results.nkError.errorCode)
            }
        }

        if metadata.directory {
            await pushMetadata(metadata)
        } else {
            let image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: self.global.previewExt1024, userId: metadata.userId, urlBase: metadata.urlBase)
            let fileExists = utilityFileSystem.fileProviderStorageExists(metadata)

            // --- E2EE -------
            if metadata.isDirectoryE2EE {
                if fileExists {
                    if let vc = await NCViewer().getViewerController(metadata: metadata, delegate: self, viewerTransitionSource: viewerTransitionSource) {
                        self.navigationController?.pushViewController(vc, animated: true)
                    }
                } else {
                    await downloadFile()
                }
                return
            }
            // ---------------

            if metadata.isImage || metadata.isAudioOrVideo {
                let metadatas = self.dataSource.getMetadatas()
                let ocIds = metadatas.filter { $0.classFile == NKTypeClassFile.image.rawValue ||
                    $0.classFile == NKTypeClassFile.video.rawValue ||
                    $0.classFile == NKTypeClassFile.audio.rawValue }.map(\.ocId)

                if let vc = await NCViewer().getViewerController(metadata: metadata, ocIds: withOcIds ? ocIds : nil, image: image, delegate: self, viewerTransitionSource: viewerTransitionSource) {
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            } else if !metadata.isDirectoryE2EE, metadata.isDocumentEditorAvailable || utilityFileSystem.fileProviderStorageExists(metadata) || metadata.name == self.global.talkName {
                if let vc = await NCViewer().getViewerController(metadata: metadata, image: image, delegate: self, viewerTransitionSource: viewerTransitionSource) {
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            } else if NextcloudKit.shared.isNetworkReachable() {
                guard let  metadata = await database.setMetadataSessionInWaitDownloadAsync(ocId: metadata.ocId,
                                                                                           session: self.networking.sessionDownload,
                                                                                           selector: global.selectorLoadFileView,
                                                                                           sceneIdentifier: self.controller?.sceneIdentifier) else {
                    return
                }

                if metadata.name == "files" {
                    await downloadFile()
                } else if !metadata.url.isEmpty,
                          let vc = await NCViewer().getViewerController(metadata: metadata, delegate: self, viewerTransitionSource: viewerTransitionSource) {
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            } else {
                await showErrorBanner(windowScene: windowScene, text: "_go_online_", errorCode: NCGlobal.shared.errorOfflineNotAllowed)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let metadata = self.dataSource.getMetadata(indexPath: indexPath) else {
            return
        }
        var viewerTransitionSource: NCMediaViewerTransitionSource?

        if self.isEditMode {
            if let index = self.fileSelect.firstIndex(of: metadata.ocId) {
                self.fileSelect.remove(at: index)
            } else {
                self.fileSelect.append(metadata.ocId)
            }
            self.collectionView.reloadItems(at: [indexPath])
            self.tabBarSelect?.update(fileSelect: self.fileSelect, metadatas: self.getSelectedMetadatas(), userId: metadata.userId)
            self.collectionView.collectionViewLayout.invalidateLayout()
            return
        }

        if let cell = collectionView.cellForItem(at: indexPath) as? NCCellMainProtocol {
            viewerTransitionSource = cell.viewerTransitionSource()
        }

        Task {
            await didSelectMetadata(metadata, withOcIds: true, viewerTransitionSource: viewerTransitionSource)
        }
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
        guard let indexPath = indexPaths.first,
              let metadata = self.dataSource.getMetadata(indexPath: indexPath),
              metadata.classFile != NKTypeClassFile.url.rawValue,
              !isEditMode
        else {
            return nil
        }
        let identifier = indexPath as NSCopying
        let cell = collectionView.cellForItem(at: indexPath)

        return UIContextMenuConfiguration(identifier: identifier, previewProvider: {
            return nil
        }, actionProvider: { _ in
            let contextMenu = NCContextMenuMain(metadata: metadata.detachedCopy(), viewController: self, controller: self.controller, sender: cell)
            return contextMenu.viewMenu()
        })
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfiguration configuration: UIContextMenuConfiguration, highlightPreviewForItemAt indexPath: IndexPath) -> UITargetedPreview? {
        contextMenuPreview = nil

        // A problematic name keeps the standard preview, where the extension has its own label.
        guard let cell = collectionView.cellForItem(at: indexPath),
              let metadata = dataSource.getMetadata(indexPath: indexPath),
              !NCContextMenuPreviewView.isProblematic(metadata.fileNameView),
              let copies = cellCopies(of: cell, at: indexPath, metadata: metadata)
        else {
            return nil
        }
        let preview = NCContextMenuPreviewView(sourceCell: cell, rowCell: copies.row, fullNameCell: copies.fullName, rowAlignment: cell is NCGridCell ? .top : .center)
        let parameters = UIPreviewParameters()

        // Keeps the room for the whole name invisible until the menu opens.
        parameters.backgroundColor = .clear
        parameters.shadowPath = preview.rowShadowPath

        // Places the row copy exactly over the pressed cell.
        let center = CGPoint(x: cell.center.x, y: cell.frame.minY - preview.rowFrame.minY + preview.bounds.midY)
        let targetedPreview = UITargetedPreview(view: preview, parameters: parameters, target: UIPreviewTarget(container: collectionView, center: center))

        contextMenuPreview = targetedPreview

        return targetedPreview
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfiguration configuration: UIContextMenuConfiguration, dismissalPreviewForItemAt indexPath: IndexPath) -> UITargetedPreview? {
        contextMenuPreview
    }

    func collectionView(_ collectionView: UICollectionView, willDisplayContextMenu configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
        contextMenuPreviewView?.setFullNameVisible(true, alongside: animator)
    }

    func collectionView(_ collectionView: UICollectionView, willEndContextMenuInteraction configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
        contextMenuPreviewView?.setFullNameVisible(false, alongside: animator)

        guard let animator else {
            contextMenuPreview = nil
            return
        }

        let endingPreview = contextMenuPreview

        // A new press may have stored its own preview before this dismissal finished.
        animator.addCompletion { [weak self] in
            if self?.contextMenuPreview === endingPreview {
                self?.contextMenuPreview = nil
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        animator.addCompletion {
            if let indexPath = configuration.identifier as? IndexPath {
                self.collectionView(collectionView, didSelectItemAt: indexPath)
            }
        }
    }

    private var contextMenuPreviewView: NCContextMenuPreviewView? {
        contextMenuPreview?.view as? NCContextMenuPreviewView
    }

    /// Copies of the item's list or grid cell, one as is and one wrapping its whole name; `nil` for photo cells, which show no name.
    private func cellCopies(of cell: UICollectionViewCell, at indexPath: IndexPath, metadata: tableMetadata) -> (row: UICollectionViewCell, fullName: UICollectionViewCell)? {
        guard cell is NCListCell || cell is NCGridCell else { return nil }

        let nib = UINib(nibName: cell is NCListCell ? "NCListCell" : "NCGridCell", bundle: nil)
        let existsImagePreview = utilityFileSystem.fileProviderStorageImageExists(metadata.ocId, etag: metadata.etag, userId: metadata.userId, urlBase: metadata.urlBase)

        func copy(showingFullName: Bool) -> UICollectionViewCell? {
            guard let copy = nib.instantiate(withOwner: nil).first as? UICollectionViewCell else { return nil }

            copy.frame = cell.bounds
            copy.backgroundColor = collectionView.backgroundColor

            if let listCopy = copy as? NCListCell {
                _ = listCell(cell: listCopy, indexPath: indexPath, metadata: metadata, existsImagePreview: existsImagePreview)

                if showingFullName {
                    listCopy.showFullName()
                }
            } else if let gridCopy = copy as? NCGridCell {
                _ = gridCell(cell: gridCopy, indexPath: indexPath, metadata: metadata, existsImagePreview: existsImagePreview)

                if showingFullName {
                    gridCopy.showFullName()
                }
            }

            return copy
        }

        guard let row = copy(showingFullName: false), let fullName = copy(showingFullName: true) else { return nil }

        return (row, fullName)
    }
}
