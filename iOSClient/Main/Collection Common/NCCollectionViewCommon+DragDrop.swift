//
//  NCCollectionViewCommon+DragDrop.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 19/04/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation

// MARK: - Drag

extension NCCollectionViewCommon: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath),
              metadata.status == 0,
              !isEditMode,
              !isDirectoryE2EE(metadata: metadata) else { return [] }

        DragDropHover.shared.sourceMetadata = metadata
        DragDropHover.shared.destinationMetadata = nil

        let itemProvider = NSItemProvider(object: metadata.ocId as NSString)
        return [UIDragItem(itemProvider: itemProvider)]
    }

    func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        let previewParameters = UIDragPreviewParameters()

        if layoutForView?.layout == NCGlobal.shared.layoutList, let cell = collectionView.cellForItem(at: indexPath) as? NCListCell {
            let width = (collectionView.frame.width / 3) * 2
            previewParameters.visiblePath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: width, height: cell.frame.height), cornerRadius: 10)
            return previewParameters
        } else if let cell = collectionView.cellForItem(at: indexPath) as? NCGridCell {
            previewParameters.visiblePath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: cell.frame.width, height: cell.frame.height - 40), cornerRadius: 10)
            return previewParameters
        }

        return nil
    }
}

// MARK: - Drop

extension NCCollectionViewCommon: UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        if session.canLoadObjects(ofClass: NSString.self) || session.canLoadObjects(ofClass: UIImage.self) {
            return true
        } else if session.hasItemsConforming(toTypeIdentifiers: ["public.movie"]) {
            return true
        }
        return false
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        cleanPushDragDropHover()
        var serverUrl: String = self.serverUrl
        let location = coordinator.session.location(in: collectionView)
        if let destinationIndexPath = coordinator.destinationIndexPath {
            DragDropHover.shared.destinationMetadata = dataSource.cellForItemAt(indexPath: destinationIndexPath)
        }

        func uploadFile(fileNamePath: String) async {
            if let destinationMetadata = DragDropHover.shared.destinationMetadata, destinationMetadata.directory {
                serverUrl = destinationMetadata.serverUrl + "/" + destinationMetadata.fileName
            }
            let ocId = NSUUID().uuidString
            let ext = (fileNamePath as NSString).pathExtension
            let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + ext, account: self.appDelegate.account, serverUrl: serverUrl)
            let toPath = utilityFileSystem.getDirectoryProviderStorageOcId(ocId, fileNameView: fileName)
            utilityFileSystem.copyFile(atPath: fileNamePath, toPath: toPath)

            let metadataForUpload = NCManageDatabase.shared.createMetadata(account: appDelegate.account, user: appDelegate.user, userId: appDelegate.userId, fileName: fileName, fileNameView: fileName, ocId: ocId, serverUrl: serverUrl, urlBase: appDelegate.urlBase, url: "", contentType: "")

            metadataForUpload.session = NCNetworking.shared.sessionUploadBackground
            metadataForUpload.sessionSelector = NCGlobal.shared.selectorUploadFile
            metadataForUpload.size = utilityFileSystem.getFileSize(filePath: toPath)
            metadataForUpload.status = NCGlobal.shared.metadataStatusWaitUpload
            metadataForUpload.sessionDate = Date()

            NCManageDatabase.shared.addMetadata(metadataForUpload)
        }

        if DragDropHover.shared.sourceMetadata != nil {
            self.openMenu(collectionView: collectionView, location: location)
        } else {
            if coordinator.session.canLoadObjects(ofClass: UIImage.self) {
                coordinator.session.loadObjects(ofClass: UIImage.self) { items in
                    Task {
                        for case let image as UIImage in items {
                            if let data = image.jpegData(compressionQuality: 1) {
                                do {
                                    let fileNamePath = NSTemporaryDirectory() + NSUUID().uuidString + ".jpg"
                                    try data.write(to: URL(fileURLWithPath: fileNamePath))
                                    await uploadFile(fileNamePath: fileNamePath)
                                } catch {  }
                            }
                        }
                    }
                }
            }

            for item in coordinator.items {
                item.dragItem.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.movie") { (url, error) in
                    if let url = url {

                    }
                }
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        disabeHighlightedCells()
        if destinationIndexPath == nil && DragDropHover.shared.sourceMetadata?.serverUrl == self.serverUrl {
            cleanPushDragDropHover()
            return UICollectionViewDropProposal(operation: .forbidden)
        }
        guard let destinationIndexPath,
              let destinationMetadata = dataSource.cellForItemAt(indexPath: destinationIndexPath) else {
            cleanPushDragDropHover()
            return UICollectionViewDropProposal(operation: .copy)
        }

        if isDirectoryE2EE(metadata: destinationMetadata) || destinationMetadata.ocId == DragDropHover.shared.sourceMetadata?.ocId {
            cleanPushDragDropHover()
            return UICollectionViewDropProposal(operation: .forbidden)
        }
        if !destinationMetadata.directory && DragDropHover.shared.sourceMetadata?.serverUrl == self.serverUrl {
            cleanPushDragDropHover()
            return UICollectionViewDropProposal(operation: .forbidden)
        }

        if destinationMetadata.directory {
            let cell = collectionView.cellForItem(at: destinationIndexPath) as? NCCellProtocol
            cell?.setHighlighted(true)
        }

        // Push Metadata
        if DragDropHover.shared.pushIndexPath != destinationIndexPath || DragDropHover.shared.pushCollectionView != collectionView {
            DragDropHover.shared.pushIndexPath = destinationIndexPath
            DragDropHover.shared.pushCollectionView = collectionView
            DragDropHover.shared.pushTimerIndexPath?.invalidate()
            DragDropHover.shared.pushTimerIndexPath = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
                guard let self else { return }
                if DragDropHover.shared.pushIndexPath == destinationIndexPath,
                   DragDropHover.shared.pushCollectionView == collectionView,
                   let metadata = self.dataSource.cellForItemAt(indexPath: destinationIndexPath),
                   metadata.directory {
                    self.cleanPushDragDropHover()
                    self.disabeHighlightedCells()
                    self.pushMetadata(metadata)
                }
            }
        }

        return UICollectionViewDropProposal(operation: .copy)
    }

    func collectionView(_ collectionView: UICollectionView, dropSessionDidExit session: UIDropSession) {
        cleanPushDragDropHover()
        disabeHighlightedCells()
    }

    // Update collectionView after ending the drop operation
    func collectionView(_ collectionView: UICollectionView, dropSessionDidEnd session: UIDropSession) {
        cleanPushDragDropHover()
        disabeHighlightedCells()
    }

    private func disabeHighlightedCells() {
        for mainTabBarController in SceneManager.shared.getAllMainTabBarController() {
            if let viewController = mainTabBarController.currentViewController() as? NCFiles,
               let indexPathsForVisibleItems = viewController.collectionView?.indexPathsForVisibleItems {
                for indexPathVisible in indexPathsForVisibleItems {
                    let cell = viewController.collectionView.cellForItem(at: indexPathVisible) as? NCCellProtocol
                    cell?.setHighlighted(false)
                }
            }
        }
    }

    private func openMenu(collectionView: UICollectionView, location: CGPoint) {
        var listMenuItems: [UIMenuItem] = []
        listMenuItems.append(UIMenuItem(title: NSLocalizedString("_copy_", comment: ""), action: #selector(copyMenuFile)))
        listMenuItems.append(UIMenuItem(title: NSLocalizedString("_move_", comment: ""), action: #selector(moveMenuFile)))
        UIMenuController.shared.menuItems = listMenuItems
        UIMenuController.shared.showMenu(from: collectionView, rect: CGRect(x: location.x, y: location.y, width: 0, height: 0))
    }

    @objc func copyMenuFile() {
        let serverUrl: String?
        if let destinationMetadata = DragDropHover.shared.destinationMetadata, destinationMetadata.directory {
            serverUrl = destinationMetadata.serverUrl + "/" + destinationMetadata.fileName
        } else {
            serverUrl = self.serverUrl
        }
        guard let serverUrl, let metadata = DragDropHover.shared.sourceMetadata else { return }
        Task {
            let error = await NCNetworking.shared.copyMetadata(metadata, serverUrlTo: serverUrl, overwrite: false)
            if error != .success {
                NCContentPresenter().showError(error: error)
            } else {
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSourceNetwork, userInfo: ["withQueryDB": true])
            }
        }
    }

    @objc func moveMenuFile() {
        let serverUrl: String?
        if let destinationMetadata = DragDropHover.shared.destinationMetadata, destinationMetadata.directory {
            serverUrl = destinationMetadata.serverUrl + "/" + destinationMetadata.fileName
        } else {
            serverUrl = self.serverUrl
        }
        guard let serverUrl, let metadata = DragDropHover.shared.sourceMetadata else { return }
        Task {
            let error = await NCNetworking.shared.moveMetadata(metadata, serverUrlTo: serverUrl, overwrite: false)
            if error != .success {
                NCContentPresenter().showError(error: error)
            } else {
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSourceNetwork, userInfo: ["withQueryDB": true])
            }
        }
    }

    private func cleanPushDragDropHover() {
        DragDropHover.shared.pushTimerIndexPath?.invalidate()
        DragDropHover.shared.pushTimerIndexPath = nil
        DragDropHover.shared.pushCollectionView = nil
        DragDropHover.shared.pushIndexPath = nil
    }

    private func isDirectoryE2EE(metadata: tableMetadata) -> Bool {
        if !metadata.directory { return false }
        return NCUtilityFileSystem().isDirectoryE2EE(account: metadata.account, urlBase: metadata.urlBase, userId: metadata.userId, serverUrl: metadata.serverUrl + "/" + metadata.fileName)
    }
}

// MARK: - Drop Interaction Delegate

extension NCCollectionViewCommon: UIDropInteractionDelegate {
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: NSString.self)
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnter session: UIDropSession) {
        cleanPushDragDropHover()
        disabeHighlightedCells()
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        DragDropHover.shared.pushTimerIndexPath = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
            guard let self else { return }
            backButtonPressed()
        }
        return UIDropProposal(operation: .copy)
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {
        cleanPushDragDropHover()
    }

    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
    }
}

class DragDropHover {
    static let shared = DragDropHover()

    var pushTimerDropInteraction: Timer?
    var pushTimerIndexPath: Timer?
    var pushCollectionView: UICollectionView?
    var pushIndexPath: IndexPath?

    var sourceMetadata: tableMetadata?
    var destinationMetadata: tableMetadata?
}
