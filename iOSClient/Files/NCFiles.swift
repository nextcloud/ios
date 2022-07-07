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
import NCCommunication

class NCFiles: NCCollectionViewCommon {

    internal var isRoot: Bool = true

    // MARK: - View Life Cycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        appDelegate.activeFiles = self
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
            serverUrl = NCUtilityFileSystem.shared.getHomeServer(account: appDelegate.account)
            titleCurrentFolder = getNavigationTitle()
        }

        super.viewWillAppear(animated)
    }

    // MARK: - NotificationCenter

    override func initialize() {

        if isRoot {
            serverUrl = NCUtilityFileSystem.shared.getHomeServer(account: appDelegate.account)
            titleCurrentFolder = getNavigationTitle()
            reloadDataSourceNetwork(forced: true)
        }

        super.initialize()
    }

    // MARK: - DataSource + NC Endpoint

    override func reloadDataSource(removeEtagFolder: Bool = true) {
        super.reloadDataSource()

        guard !self.isSearching, !self.appDelegate.account.isEmpty, !self.appDelegate.urlBase.isEmpty else { return }
        var etag: String?

        self.metadatasSource = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, self.serverUrl))
        if self.metadataFolder == nil {
            self.metadataFolder = NCManageDatabase.shared.getMetadataFolder(account: self.appDelegate.account, urlBase: self.appDelegate.urlBase, serverUrl: self.serverUrl)
        }

        // etagFolder verify
        if removeEtagFolder {
            self.dataSource.etag = nil
        }
        if let etag = self.dataSource.etag, let etagFolder = self.metadataFolder?.etag, etag == etagFolder {
            return
        } else if let etagFolder = self.metadataFolder?.etag, !self.metadatasSource.isEmpty {
            etag = etagFolder
        }

        self.dataSource = NCDataSource(
            metadatasSource: self.metadatasSource,
            account: self.appDelegate.account,
            etag: etag,
            sort: self.layoutForView?.sort,
            ascending: self.layoutForView?.ascending,
            directoryOnTop: self.layoutForView?.directoryOnTop,
            favoriteOnTop: true,
            filterLivePhoto: true,
            groupByField: self.groupByField,
            providers: self.providers,
            searchResults: self.searchResults)

        DispatchQueue.main.async {
            self.refreshControl.endRefreshing()
            self.collectionView.reloadData()
        }
    }

    override func reloadDataSourceNetwork(forced: Bool = false) {
        super.reloadDataSourceNetwork(forced: forced)

        if isSearching {
            networkSearch()
            return
        }

        isReloadDataSourceNetworkInProgress = true
        collectionView?.reloadData()

        networkReadFolder(forced: forced) { tableDirectory, metadatas, metadatasUpdate, metadatasDelete, errorCode, _ in
            if errorCode == 0 {
                for metadata in metadatas ?? [] {
                    if !metadata.directory {
                        if NCManageDatabase.shared.isDownloadMetadata(metadata, download: false) {
                            NCOperationQueue.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorDownloadFile)
                        }
                    }
                }
            }

            // clear etag datasource
            if forced {
                self.dataSource.etag = nil
            }

            DispatchQueue.main.async {
                self.refreshControl.endRefreshing()
                self.isReloadDataSourceNetworkInProgress = false
                self.richWorkspaceText = tableDirectory?.richWorkspace
                if metadatasUpdate?.count ?? 0 > 0 || metadatasDelete?.count ?? 0 > 0 || forced {
                    self.reloadDataSource(removeEtagFolder: forced)
                } else {
                    self.collectionView?.reloadData()
                }
            }
        }
    }
}
