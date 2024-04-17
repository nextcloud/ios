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
    internal var dragStartedOcId: String?

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

        if UIApplication.shared.supportsMultipleScenes {
            collectionView.dragInteractionEnabled = true
            collectionView.dragDelegate = self
            collectionView.dropDelegate = self
        }
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

        // DD
        /*
        if let navigationBar = self.navigationController?.navigationBar {
            let dropZoneView = UIView(frame: CGRect(x: 0, y: 0, width: navigationBar.bounds.width, height: navigationBar.bounds.height))
            dropZoneView.backgroundColor = .clear
            navigationBar.addSubview(dropZoneView)
            dropZoneView.isUserInteractionEnabled = true

            let dropInteraction = UIDropInteraction(delegate: self)
            dropZoneView.addInteraction(dropInteraction)
        }
        */
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

    override func reloadDataSourceNetwork() {
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
                    self.reloadDataSource(withQueryDB: false)
                }
            } else {
                self.reloadDataSource(withQueryDB: false)
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
              !isEditMode else { return [] }
        dragStartedOcId = metadata.ocId
        let itemProvider = NSItemProvider(object: metadata.ocId as NSString)
        return [UIDragItem(itemProvider: itemProvider)]
    }

    func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        if let cell = collectionView.cellForItem(at: indexPath) as? NCCellProtocol,
           let frame = cell.filePreviewImageView?.frame {
            let previewParameters = UIDragPreviewParameters()
            previewParameters.visiblePath = UIBezierPath(roundedRect: CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height), cornerRadius: 10)
            return previewParameters
        }
        return nil
    }
}

// MARK: - Drop

extension NCFiles: UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        let location = coordinator.session.location(in: collectionView)

        cleanDDVariable()

        if let item = coordinator.items.first,
           let provider = item.dragItem.itemProvider.copy() as? NSItemProvider {
            provider.loadObject(ofClass: NSString.self) { data, error in
                if error == nil,
                   let ocId = data as? NSString,
                   let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId as String) {
                    DispatchQueue.main.async {
                        // self.openMenu(collectionView: collectionView, location: location, metadata: metadata)
                    }
                }
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        disabeHighlightedCells()

        guard let destinationIndexPath,
              let metadata = dataSource.cellForItemAt(indexPath: destinationIndexPath) else {
            cleanDDVariable()
            return UICollectionViewDropProposal(operation: .copy)
        }

        if metadata.directory, metadata.ocId != dragStartedOcId {
            let cell = collectionView.cellForItem(at: destinationIndexPath) as? NCCellProtocol
            cell?.setHighlighted(true)
        }

        if appDelegate.ddCurrentHoverIndexPath != destinationIndexPath || appDelegate.ddCurrentHoverCollectionView != collectionView {
            appDelegate.ddCurrentHoverIndexPath = destinationIndexPath
            appDelegate.ddCurrentHoverCollectionView = collectionView
            appDelegate.ddHoverTimerIndexPath?.invalidate()
            appDelegate.ddHoverTimerIndexPath = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
                guard let self else { return }
                if self.appDelegate.ddCurrentHoverIndexPath == destinationIndexPath,
                   let metadata = self.dataSource.cellForItemAt(indexPath: destinationIndexPath),
                   metadata.directory {
                    self.cleanDDVariable()
                    self.disabeHighlightedCells()
                    self.pushMetadata(metadata)
                }
            }
        }

        return UICollectionViewDropProposal(operation: .copy)
    }

    func collectionView(_ collectionView: UICollectionView, dropSessionDidExit session: UIDropSession) {
        cleanDDVariable()
        disabeHighlightedCells()
    }

    // Update collectionView after ending the drop operation
    func collectionView(_ collectionView: UICollectionView, dropSessionDidEnd session: UIDropSession) {
        cleanDDVariable()
        disabeHighlightedCells()
    }

    private func disabeHighlightedCells() {
        for mainTabBarController in SceneManager.shared.getAllMainTabBarController() {
            if let viewController = mainTabBarController.currentViewController() as? NCFiles {
                for indexPathVisible in viewController.collectionView.indexPathsForVisibleItems {
                    let cell = viewController.collectionView.cellForItem(at: indexPathVisible) as? NCCellProtocol
                    cell?.setHighlighted(false)
                }
            }
        }
    }

    private func openMenu(collectionView: UICollectionView, location: CGPoint, metadata: tableMetadata) {
        var listMenuItems: [UIMenuItem] = []
        listMenuItems.append(UIMenuItem(title: NSLocalizedString("_paste_file_", comment: ""), action: #selector(pasteFilesMenu)))
        UIMenuController.shared.menuItems = listMenuItems
        UIMenuController.shared.showMenu(from: collectionView, rect: CGRect(x: location.x, y: location.y, width: 0, height: 0))
    }

    private func cleanDDVariable() {
        appDelegate.ddHoverTimerIndexPath?.invalidate()
        appDelegate.ddHoverTimerIndexPath = nil
        appDelegate.ddCurrentHoverCollectionView = nil
        appDelegate.ddCurrentHoverIndexPath = nil
    }
}

// MARK: - Drop Interaction

extension NCFiles: UIDropInteractionDelegate {
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: NSString.self)
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnter session: UIDropSession) {
        cleanDDVariable()
        disabeHighlightedCells()
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        appDelegate.ddHoverTimerIndexPath = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.navigationController?.popViewController(animated: true)
        }
        return UIDropProposal(operation: .copy)
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {
        cleanDDVariable()
    }

    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
    }
}
