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

    // MARK: - View Life Cycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        titleCurrentFolder = NCBrandOptions.shared.brand
        layoutKey = NCGlobal.shared.layoutViewFiles
        enableSearchBar = true
        headerMenuButtonsView = true
        headerRichWorkspaceDisable = false
        headerMenuTransferView = true
        emptyImage = UIImage(named: "folder")?.image(color: NCBrandColor.shared.brandElement, size: UIScreen.main.bounds.width)
        emptyTitle = "_files_no_files_"
        emptyDescription = "_no_file_pull_down_"
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if isRoot {
            NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeUser), object: nil, queue: nil) { _ in

                self.navigationController?.popToRootViewController(animated: false)

                self.serverUrl = self.utilityFileSystem.getHomeServer(urlBase: self.appDelegate.urlBase, userId: self.appDelegate.userId)
                self.appDelegate.activeServerUrl = self.serverUrl

                self.isSearchingMode = false
                self.isEditMode = false
                self.selectOcId.removeAll()
                self.selectIndexPath.removeAll()

                self.layoutForView = NCManageDatabase.shared.getLayoutForView(account: self.appDelegate.account, key: self.layoutKey, serverUrl: self.serverUrl)
                self.gridLayout.itemForLine = CGFloat(self.layoutForView?.itemForLine ?? 3)
                if self.layoutForView?.layout == NCGlobal.shared.layoutList {
                    self.collectionView?.collectionViewLayout = self.listLayout
                } else {
                    self.collectionView?.collectionViewLayout = self.gridLayout
                }

                self.titleCurrentFolder = self.getNavigationTitle()
                self.setNavigationItem()

                self.reloadDataSource(isForced: false)
                self.reloadDataSourceNetwork()
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {

        if isRoot {
            serverUrl = utilityFileSystem.getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId)
            titleCurrentFolder = getNavigationTitle()
        }
        super.viewWillAppear(animated)
        navigationController?.setFileAppreance()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        fileNameBlink = nil
        fileNameOpen = nil
    }

    // MARK: - DataSource + NC Endpoint
    //
    // forced: do no make the etag of directory test (default)
    //

    override func queryDB(isForced: Bool) {

        let metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, self.serverUrl))
        let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, self.serverUrl))
        let metadataTransfer = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "status != %i AND serverUrl == %@", NCGlobal.shared.metadataStatusNormal, self.serverUrl))
        if self.metadataFolder == nil {
            self.metadataFolder = NCManageDatabase.shared.getMetadataFolder(account: self.appDelegate.account, urlBase: self.appDelegate.urlBase, userId: self.appDelegate.userId, serverUrl: self.serverUrl)
        }

        if !isForced, let directory, directory.etag == self.dataSource.directory?.etag, metadataTransfer == nil, self.fileNameBlink == nil, self.fileNameOpen == nil {
            return
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

    override func reloadDataSource(isForced: Bool = true) {
        super.reloadDataSource()

        DispatchQueue.main.async { self.refreshControl.endRefreshing() }
        DispatchQueue.global().async {
            guard !self.isSearchingMode, !self.appDelegate.account.isEmpty, !self.appDelegate.urlBase.isEmpty, !self.serverUrl.isEmpty else { return }

            self.queryDB(isForced: isForced)

            DispatchQueue.main.async {
                self.collectionView.reloadData()
                if !self.dataSource.metadatas.isEmpty {
                    self.blinkCell(fileName: self.fileNameBlink)
                    self.openFile(fileName: self.fileNameOpen)
                    self.fileNameBlink = nil
                    self.fileNameOpen = nil
                }
            }
        }
    }

    override func reloadDataSourceNetwork(isForced: Bool = false) {
        super.reloadDataSourceNetwork(isForced: isForced)
        guard !isSearchingMode else {
            networkSearch()
            return
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

        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Reload data source network files forced \(isForced)")

        isReloadDataSourceNetworkInProgress = true
        collectionView?.reloadData()

        networkReadFolder(isForced: isForced) { tableDirectory, metadatas, metadatasUpdate, metadatasDelete, error in
            if error == .success {
                for metadata in metadatas ?? [] where !metadata.directory && downloadMetadata(metadata) {
                    if self.appDelegate.downloadQueue.operations.filter({ ($0 as? NCOperationDownload)?.metadata.ocId == metadata.ocId }).isEmpty {
                        self.appDelegate.downloadQueue.addOperation(NCOperationDownload(metadata: metadata, selector: NCGlobal.shared.selectorDownloadFile))
                    }
                }
            }

            self.isReloadDataSourceNetworkInProgress = false
            self.richWorkspaceText = tableDirectory?.richWorkspace

            if metadatasUpdate?.count ?? 0 > 0 || metadatasDelete?.count ?? 0 > 0 || isForced {
                self.reloadDataSource()
            } else if self.dataSource.getMetadataSourceForAllSections().isEmpty {
                DispatchQueue.main.async {
                    self.collectionView.reloadData()
                }
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
