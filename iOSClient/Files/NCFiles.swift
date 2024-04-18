//
//  NCFiles.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 26/09/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import NextcloudKit

class NCFiles: NCCollectionViewCommon {

    internal var isRoot: Bool = true
    internal var fileNameBlink: String?
    internal var fileNameOpen: String?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        titleCurrentFolder = NCBrandOptions.shared.brand
        layoutKey = NCGlobal.shared.layoutViewFiles
        enableSearchBar = true
        headerRichWorkspaceDisable = false
        headerMenuTransferView = true
        emptyImage = UIImage(named: "folder")?.image(color: NCBrandColor.shared.brandElement, size: UIScreen.main.bounds.width)
        emptyTitle = "_files_no_files_"
        emptyDescription = "_no_file_pull_down_"
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        if isRoot {
            NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeUser), object: nil, queue: nil) { _ in

                self.navigationController?.popToRootViewController(animated: false)

                self.serverUrl = self.utilityFileSystem.getHomeServer(urlBase: self.appDelegate.urlBase, userId: self.appDelegate.userId)
                self.isSearchingMode = false
                self.isEditMode = false
                self.selectOcId.removeAll()

                self.layoutForView = NCManageDatabase.shared.getLayoutForView(account: self.appDelegate.account, key: self.layoutKey, serverUrl: self.serverUrl)
                self.gridLayout.itemForLine = CGFloat(self.layoutForView?.itemForLine ?? 3)
                if self.layoutForView?.layout == NCGlobal.shared.layoutList {
                    self.collectionView?.collectionViewLayout = self.listLayout
                } else {
                    self.collectionView?.collectionViewLayout = self.gridLayout
                }

                self.titleCurrentFolder = self.getNavigationTitle()
                self.setNavigationLeftItems()

                self.reloadDataSource()
                self.reloadDataSourceNetwork()
            }
        }

        collectionView.dragInteractionEnabled = true
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
    }

    override func viewWillAppear(_ animated: Bool) {

        if isRoot {
            serverUrl = utilityFileSystem.getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId)
            titleCurrentFolder = getNavigationTitle()
        }
        super.viewWillAppear(animated)

        if dataSource.metadatas.isEmpty {
            reloadDataSource()
        }
        reloadDataSourceNetwork()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        fileNameBlink = nil
        fileNameOpen = nil
    }

    // MARK: - Layout

    override func setNavigationLeftItems() {
        super.setNavigationLeftItems()

        let dropInteraction = UIDropInteraction(delegate: self)
        backButton.addInteraction(dropInteraction)
    }

    // MARK: - Menu Item

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if #selector(pasteFilesMenu) == action {
            if !UIPasteboard.general.items.isEmpty, !(metadataFolder?.e2eEncrypted ?? false) {
                return true
            }
        } else if #selector(copyMenuFile) == action {
            return true
        } else if #selector(moveMenuFile) == action {
            return true
        }

        return false
    }

    // MARK: - DataSource + NC Endpoint

    override func queryDB() {
        super.queryDB()

        var metadatas: [tableMetadata] = []
        if NCKeychain().getPersonalFilesOnly(account: self.appDelegate.account) {
            metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND (ownerId == %@ || ownerId == '') AND mountType == ''", self.appDelegate.account, self.serverUrl, self.appDelegate.userId))
        } else {
            metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, self.serverUrl))
        }
        let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, self.serverUrl))
        if self.metadataFolder == nil {
            self.metadataFolder = NCManageDatabase.shared.getMetadataFolder(account: self.appDelegate.account, urlBase: self.appDelegate.urlBase, userId: self.appDelegate.userId, serverUrl: self.serverUrl)
        }

        self.richWorkspaceText = directory?.richWorkspace
        self.dataSource = NCDataSource(
            metadatas: metadatas,
            account: self.appDelegate.account,
            directory: directory,
            sort: self.layoutForView?.sort,
            ascending: self.layoutForView?.ascending,
            directoryOnTop: self.layoutForView?.directoryOnTop,
            favoriteOnTop: true,
            groupByField: self.groupByField,
            providers: self.providers,
            searchResults: self.searchResults)
    }

    override func reloadDataSource(withQueryDB: Bool = true) {
        super.reloadDataSource(withQueryDB: withQueryDB)

        if !self.dataSource.metadatas.isEmpty {
            self.blinkCell(fileName: self.fileNameBlink)
            self.openFile(fileName: self.fileNameOpen)
            self.fileNameBlink = nil
            self.fileNameOpen = nil
        }
    }

    override func reloadDataSourceNetwork(withQueryDB: Bool = false) {
        guard !isSearchingMode else {
            return networkSearch()
        }

        func downloadMetadata(_ metadata: tableMetadata) -> Bool {

            let fileSize = utilityFileSystem.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView)
            guard fileSize > 0 else { return false }

            if let localFile = NCManageDatabase.shared.getResultsTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))?.first {
                if localFile.etag != metadata.etag {
                    return true
                }
            }

            return false
        }

        super.reloadDataSourceNetwork()

        networkReadFolder { tableDirectory, metadatas, metadatasDifferentCount, metadatasModified, error in
            if error == .success {
                for metadata in metadatas ?? [] where !metadata.directory && downloadMetadata(metadata) {
                    if NCNetworking.shared.downloadQueue.operations.filter({ ($0 as? NCOperationDownload)?.metadata.ocId == metadata.ocId }).isEmpty {
                        NCNetworking.shared.downloadQueue.addOperation(NCOperationDownload(metadata: metadata, selector: NCGlobal.shared.selectorDownloadFile))
                    }
                }
                self.richWorkspaceText = tableDirectory?.richWorkspace

                if metadatasDifferentCount != 0 || metadatasModified != 0 {
                    self.reloadDataSource()
                } else {
                    self.reloadDataSource(withQueryDB: withQueryDB)
                }
            } else {
                self.reloadDataSource(withQueryDB: withQueryDB)
            }
        }
    }

    private func networkReadFolder(completion: @escaping(_ tableDirectory: tableDirectory?, _ metadatas: [tableMetadata]?, _ metadatasDifferentCount: Int, _ metadatasModified: Int, _ error: NKError) -> Void) {

        var tableDirectory: tableDirectory?

        NCNetworking.shared.readFile(serverUrlFileName: serverUrl) { task in
            self.dataSourceTask = task
            self.collectionView.reloadData()
        } completion: { account, metadataFolder, error in
            guard error == .success, let metadataFolder else {
                return completion(nil, nil, 0, 0, error)
            }
            tableDirectory = NCManageDatabase.shared.setDirectory(serverUrl: self.serverUrl, richWorkspace: metadataFolder.richWorkspace, account: account)
            // swiftlint:disable empty_string
            let forceReplaceMetadatas = tableDirectory?.etag == ""
            // swiftlint:enable empty_string

            if tableDirectory?.etag != metadataFolder.etag || metadataFolder.e2eEncrypted {
                NCNetworking.shared.readFolder(serverUrl: self.serverUrl,
                                               account: self.appDelegate.account,
                                               forceReplaceMetadatas: forceReplaceMetadatas) { task in
                    self.dataSourceTask = task
                    self.collectionView.reloadData()
                } completion: { _, metadataFolder, metadatas, metadatasDifferentCount, metadatasModified, error in
                    guard error == .success else {
                        return completion(tableDirectory, nil, 0, 0, error)
                    }
                    self.metadataFolder = metadataFolder
                    // E2EE
                    if let metadataFolder = metadataFolder,
                       metadataFolder.e2eEncrypted,
                       NCKeychain().isEndToEndEnabled(account: self.appDelegate.account),
                       !NCNetworkingE2EE().isInUpload(account: self.appDelegate.account, serverUrl: self.serverUrl) {
                        let lock = NCManageDatabase.shared.getE2ETokenLock(account: self.appDelegate.account, serverUrl: self.serverUrl)
                        NCNetworkingE2EE().getMetadata(fileId: metadataFolder.ocId, e2eToken: lock?.e2eToken) { account, version, e2eMetadata, signature, _, error in
                            if error == .success, let e2eMetadata = e2eMetadata {
                                let error = NCEndToEndMetadata().decodeMetadata(e2eMetadata, signature: signature, serverUrl: self.serverUrl, account: account, urlBase: self.appDelegate.urlBase, userId: self.appDelegate.userId)
                                if error == .success {
                                    if version == "v1", NCGlobal.shared.capabilityE2EEApiVersion == NCGlobal.shared.e2eeVersionV20 {
                                        NextcloudKit.shared.nkCommonInstance.writeLog("[E2EE] Conversion v1 to v2")
                                        NCActivityIndicator.shared.start()
                                        Task {
                                            let serverUrl = metadataFolder.serverUrl + "/" + metadataFolder.fileName
                                            let error = await NCNetworkingE2EE().uploadMetadata(account: metadataFolder.account, serverUrl: serverUrl, userId: metadataFolder.userId, updateVersionV1V2: true)
                                            if error != .success {
                                                NCContentPresenter().showError(error: error)
                                            }
                                            NCActivityIndicator.shared.stop()
                                            self.reloadDataSource()
                                        }
                                    } else {
                                        self.reloadDataSource()
                                    }
                                } else {
                                    // Client Diagnostic
                                    NCManageDatabase.shared.addDiagnostic(account: account, issue: NCGlobal.shared.diagnosticIssueE2eeErrors)
                                    NCContentPresenter().showError(error: error)
                                }
                            } else if error.errorCode == NCGlobal.shared.errorResourceNotFound {
                                // no metadata found, send a new metadata
                                Task {
                                    let serverUrl = metadataFolder.serverUrl + "/" + metadataFolder.fileName
                                    let error = await NCNetworkingE2EE().uploadMetadata(account: metadataFolder.account, serverUrl: serverUrl, userId: metadataFolder.userId)
                                    if error != .success {
                                        NCContentPresenter().showError(error: error)
                                    }
                                }
                            } else {
                                NCContentPresenter().showError(error: NKError(errorCode: NCGlobal.shared.errorE2EEKeyDecodeMetadata, errorDescription: "_e2e_error_"))
                            }
                            completion(tableDirectory, metadatas, metadatasDifferentCount, metadatasModified, error)
                        }
                    } else {
                        completion(tableDirectory, metadatas, metadatasDifferentCount, metadatasModified, error)
                    }
                }
            } else {
                completion(tableDirectory, nil, 0, 0, NKError())
            }
        }
    }

    func blinkCell(fileName: String?) {

        if let fileName = fileName, let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", self.appDelegate.account, self.serverUrl, fileName)) {
            let (indexPath, _) = self.dataSource.getIndexPathMetadata(ocId: metadata.ocId)
            if let indexPath = indexPath {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    UIView.animate(withDuration: 0.3) {
                        self.collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
                    } completion: { _ in
                        if let cell = self.collectionView.cellForItem(at: indexPath) {
                            cell.backgroundColor = .darkGray
                            UIView.animate(withDuration: 2) {
                                cell.backgroundColor = .clear
                            }
                        }
                    }
                }
            }
        }
    }

    func openFile(fileName: String?) {

        if let fileName = fileName, let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", self.appDelegate.account, self.serverUrl, fileName)) {
            let (indexPath, _) = self.dataSource.getIndexPathMetadata(ocId: metadata.ocId)
            if let indexPath = indexPath {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.collectionView(self.collectionView, didSelectItemAt: indexPath)
                }
            }
        }
    }
}

// MARK: - Drag

extension NCFiles: UICollectionViewDragDelegate {
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

extension NCFiles: UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        cleanPushDragDropHover()
        let location = coordinator.session.location(in: collectionView)
        if let destinationIndexPath = coordinator.destinationIndexPath {
            DragDropHover.shared.destinationMetadata = dataSource.cellForItemAt(indexPath: destinationIndexPath)
        }
        if DragDropHover.shared.sourceMetadata != nil {
            self.openMenu(collectionView: collectionView, location: location)
        }

        /* Exsternal ?
        if let item = coordinator.items.first,
           let provider = item.dragItem.itemProvider.copy() as? NSItemProvider {
            provider.loadObject(ofClass: NSString.self) { data, error in
                if error == nil,
                   let ocId = data as? NSString,
                   let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId as String) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.openMenu(collectionView: collectionView, location: location)
                    }
                }
            }
        }
        */
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

    @objc private func copyMenuFile() {
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

    @objc private func moveMenuFile() {
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

extension NCFiles: UIDropInteractionDelegate {
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
