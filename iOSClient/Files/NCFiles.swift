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
        headerMenuButtonsCommand = true
        headerMenuButtonsView = true
        headerRichWorkspaceDisable = false
        emptyImage = UIImage(named: "folder")?.image(color: NCBrandColor.shared.brandElement, size: UIScreen.main.bounds.width)
        emptyTitle = "_files_no_files_"
        emptyDescription = "_no_file_pull_down_"
    }

    override func viewWillAppear(_ animated: Bool) {

        if isRoot {
            serverUrl = NCUtilityFileSystem.shared.getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId)
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

    // MARK: - NotificationCenter

    override func initialize() {

        if isRoot {
            serverUrl = NCUtilityFileSystem.shared.getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId)
            titleCurrentFolder = getNavigationTitle()
        }
        super.initialize()

        /*
        if let userInfo = notification.userInfo as NSDictionary?, userInfo["atStart"] as? Int == 1 {
            return
        }
        */

        reloadDataSource(forced: false)
        reloadDataSourceNetwork()
    }

    // MARK: - DataSource + NC Endpoint
    //
    // forced: do no make the etag of directory test (default)
    //

    override func reloadDataSource(forced: Bool = true) {
        super.reloadDataSource()

        DispatchQueue.main.async { self.refreshControl.endRefreshing() }
        DispatchQueue.global().async {
            guard !self.isSearchingMode, !self.appDelegate.account.isEmpty, !self.appDelegate.urlBase.isEmpty, !self.serverUrl.isEmpty else { return }

            let metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, self.serverUrl))
            if self.metadataFolder == nil {
                self.metadataFolder = NCManageDatabase.shared.getMetadataFolder(account: self.appDelegate.account, urlBase: self.appDelegate.urlBase, userId: self.appDelegate.userId, serverUrl: self.serverUrl)
            }
            let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, self.serverUrl))
            let metadataTransfer = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "status != %i AND serverUrl == %@", NCGlobal.shared.metadataStatusNormal, self.serverUrl))
            self.richWorkspaceText = directory?.richWorkspace

            // FORCED false: test the directory.etag
            if !forced, let directory = directory, directory.etag == self.dataSource.directory?.etag, metadataTransfer == nil, self.fileNameBlink == nil, self.fileNameOpen == nil {
                return
            }

            self.dataSource = NCDataSource(
                metadatas: metadatas,
                account: self.appDelegate.account,
                directory: directory,
                sort: self.layoutForView?.sort,
                ascending: self.layoutForView?.ascending,
                directoryOnTop: self.layoutForView?.directoryOnTop,
                favoriteOnTop: true,
                filterLivePhoto: true,
                groupByField: self.groupByField,
                providers: self.providers,
                searchResults: self.searchResults)

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

    override func reloadDataSourceNetwork(forced: Bool = false) {
        super.reloadDataSourceNetwork(forced: forced)
        guard !isSearchingMode else {
            networkSearch()
            return
        }
        isReloadDataSourceNetworkInProgress = true
        collectionView?.reloadData()

        networkReadFolder(forced: forced) { tableDirectory, metadatas, metadatasUpdate, metadatasDelete, error in
            if error == .success {
                for metadata in metadatas ?? [] where !metadata.directory && NCManageDatabase.shared.isDownloadMetadata(metadata, download: false) {
                    NCOperationQueue.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorDownloadFile)
                }
            }

            self.isReloadDataSourceNetworkInProgress = false
            self.richWorkspaceText = tableDirectory?.richWorkspace

            if metadatasUpdate?.count ?? 0 > 0 || metadatasDelete?.count ?? 0 > 0 || forced {
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
