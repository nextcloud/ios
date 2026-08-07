// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import QuickLook
import SwiftUI

class NCViewer: NSObject {
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let database = NCManageDatabase.shared
    private var viewerQuickLook: NCViewerQuickLook?

    @MainActor
    func getViewerController(metadata: tableMetadata, ocIds: [String]? = nil, image: UIImage? = nil, delegate: UIViewController? = nil, viewerTransitionSource: NCMediaViewerTransitionSource?, selectedEditor: String? = nil) async -> UIViewController? {
        let session = NCSession.shared.getSession(account: metadata.account)
        // Set Last Opening Date
        await self.database.setLocalFileLastOpeningDateAsync(metadata: metadata)

        // URL
        if metadata.classFile == NKTypeClassFile.url.rawValue,
           !NCUtilityFileSystem().isDirectoryE2EE(serverUrl: metadata.serverUrl, urlBase: session.urlBase, userId: session.userId, account: session.account) {
            // nextcloudtalk://open-conversation?server={serverURL}&user={userId}&withRoomToken={roomToken}
            if metadata.name == NCGlobal.shared.talkName {
                let pathComponents = metadata.url.components(separatedBy: "/")
                if pathComponents.contains("call") {
                    let talkComponents = pathComponents.last?.components(separatedBy: "#")
                    if let roomToken = talkComponents?.first {
                        let urlString = "nextcloudtalk://open-conversation?server=\(session.urlBase)&user=\(session.userId)&withRoomToken=\(roomToken)"
                        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
                            await UIApplication.shared.open(url)
                        }
                    }
                }
            } else if let url = URL(string: metadata.url) {
                await UIApplication.shared.open(url)
            }
            return nil
        }

        // IMAGE AUDIO VIDEO
        else if metadata.isImage || metadata.isAudioOrVideo {
            let mediaOcIds = ocIds ?? [metadata.ocId]
            let model = NCMediaViewerModel(currentMetadata: metadata, ocIds: mediaOcIds, session: session, loader: NCMediaViewerLoader())

            NCMediaViewerPresenter.shared.show(
                model: model,
                viewerTransitionSource: viewerTransitionSource,
                from: delegate?.view,
                contextMenuController: delegate?.tabBarController as? NCMainTabBarController,
                closingTransitionSourceProvider: { ocId in
                    if let provider = delegate as? NCCollectionViewCommon {
                        return provider.viewerTransitionSource(for: ocId)
                    } else if let provider = delegate as? NCMedia {
                        return provider.viewerTransitionSource(for: ocId)
                    } else {
                        return nil
                    }
                }
            )
            return nil
        }

        // DOCUMENTS
        else if metadata.classFile == NKTypeClassFile.document.rawValue,
                !NCUtilityFileSystem().isDirectoryE2EE(serverUrl: metadata.serverUrl, urlBase: session.urlBase, userId: session.userId, account: session.account) {

            // PDF
            if metadata.isPDF, selectedEditor == nil {
                let vc = UIStoryboard(name: "NCViewerPDF", bundle: nil).instantiateInitialViewController() as? NCViewerPDF

                vc?.metadata = metadata
                vc?.imageIcon = image
                vc?.navigationItem.setBidiSafeTitle(metadata.fileNameView)

                return vc
            }

            // TEXT - OFFICE
            let documentEditorCoordinator = NCDocumentEditorCoordinator(metadata: metadata, image: image, selectedEditor: selectedEditor, delegate: delegate)
            if let viewController = await documentEditorCoordinator.selectEditor() {
                return viewController
            }

            self.QLPreview(metadata: metadata, delegate: delegate)

            return nil
        }

        // iOS QL-Preview
        self.QLPreview(metadata: metadata, delegate: delegate)

        return nil
    }

    private func QLPreview(metadata: tableMetadata, delegate: UIViewController? = nil) {
        let item = URL(fileURLWithPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId,
                                                                                          fileName: metadata.fileNameView,
                                                                                          userId: metadata.userId,
                                                                                          urlBase: metadata.urlBase))
        if QLPreviewController.canPreview(item as QLPreviewItem) {
            let fileNamePath = NSTemporaryDirectory() + metadata.fileNameView
            utilityFileSystem.copyFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId,
                                                                                                 fileName: metadata.fileNameView,
                                                                                                 userId: metadata.userId,
                                                                                                 urlBase: metadata.urlBase), toPath: fileNamePath)
            let viewerQuickLook = NCViewerQuickLook(with: URL(fileURLWithPath: fileNamePath), isEditingEnabled: false, metadata: metadata)
            delegate?.present(viewerQuickLook, animated: true)
        } else {
            // Document Interaction Controller
            if let controller = delegate?.tabBarController as? NCMainTabBarController {
                Task {
                    await NCCreate().createActivityViewController(selectedMetadata: [metadata], controller: controller, presentViewController: controller, sender: nil)
                }
            }
        }
    }
}
