//
//  NCShares.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 20/10/2020.
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

class NCShares: NCCollectionViewCommon {

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        titleCurrentFolder = NSLocalizedString("_list_shares_", comment: "")
        layoutKey = NCGlobal.shared.layoutViewShares
        enableSearchBar = false
        headerRichWorkspaceDisable = true
        emptyImage = UIImage(named: "share")?.image(color: .gray, size: UIScreen.main.bounds.width)
        emptyTitle = "_list_shares_no_files_"
        emptyDescription = "_tutorial_list_shares_view_"
    }

    // MARK: - View Life Cycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if dataSource.metadatas.isEmpty {
            reloadDataSource()
        }
        reloadDataSourceNetwork()
    }

    // MARK: - DataSource + NC Endpoint

    override func queryDB() {
        super.queryDB()

        var metadatas: [tableMetadata] = []

        func reload() {
            self.dataSource = NCDataSource(metadatas: metadatas,
                                           account: appDelegate.account,
                                           sort: layoutForView?.sort,
                                           ascending: layoutForView?.ascending,
                                           directoryOnTop: layoutForView?.directoryOnTop,
                                           favoriteOnTop: true,
                                           groupByField: groupByField,
                                           providers: providers,
                                           searchResults: searchResults)
            DispatchQueue.main.async {
                self.refreshControl.endRefreshing()
                self.collectionView.reloadData()
            }
        }

        let sharess = NCManageDatabase.shared.getTableShares(account: appDelegate.account)
        for share in sharess {
            if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", appDelegate.account, share.serverUrl, share.fileName)) {
                if !(metadatas.contains { $0.ocId == metadata.ocId }) {
                    metadatas.append(metadata)
                }
            } else {
                let serverUrlFileName = share.serverUrl + "/" + share.fileName
                NCNetworking.shared.readFile(serverUrlFileName: serverUrlFileName) { task in
                    self.dataSourceTask = task
                    self.collectionView.reloadData()
                } completion: { _, metadata, _ in
                    if let metadata {
                        NCManageDatabase.shared.addMetadata(metadata)
                        if !(metadatas.contains { $0.ocId == metadata.ocId }) {
                            metadatas.append(metadata)
                            reload()
                        }
                    }
                }
            }
        }

        reload()
    }

    override func reloadDataSourceNetwork() {
        super.reloadDataSourceNetwork()

        NextcloudKit.shared.readShares(parameters: NKShareParameter()) { task in
            self.dataSourceTask = task
            self.collectionView.reloadData()
        } completion: { account, shares, _, error in
            if error == .success {
                NCManageDatabase.shared.deleteTableShare(account: account)
                if let shares = shares, !shares.isEmpty {
                    let home = self.utilityFileSystem.getHomeServer(urlBase: self.appDelegate.urlBase, userId: self.appDelegate.userId)
                    NCManageDatabase.shared.addShare(account: self.appDelegate.account, home: home, shares: shares)
                }
                self.reloadDataSource()
            } else {
                self.reloadDataSource(withQueryDB: false)
            }
        }
    }
}
