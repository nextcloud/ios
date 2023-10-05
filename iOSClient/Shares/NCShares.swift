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

    // MARK: - View Life Cycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        titleCurrentFolder = NSLocalizedString("_list_shares_", comment: "")
        layoutKey = NCGlobal.shared.layoutViewShares
        enableSearchBar = false
        headerMenuButtonsView = true
        headerRichWorkspaceDisable = true
        emptyImage = UIImage(named: "share")?.image(color: .gray, size: UIScreen.main.bounds.width)
        emptyTitle = "_list_shares_no_files_"
        emptyDescription = "_tutorial_list_shares_view_"
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setFileAppreance()
    }

    // MARK: - DataSource + NC Endpoint

    override func queryDB(isForced: Bool) {

        var metadatas: [tableMetadata] = []

        func reload() {
            self.dataSource = NCDataSource(metadatas: metadatas,
                                           account: appDelegate.account,
                                           sort: layoutForView?.sort,
                                           ascending: layoutForView?.ascending,
                                           directoryOnTop: layoutForView?.directoryOnTop,
                                           favoriteOnTop: true,
                                           filterLivePhoto: true,
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
                NCNetworking.shared.readFile(serverUrlFileName: serverUrlFileName) { _, metadata, _ in
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

    override func reloadDataSource(isForced: Bool = true) {
        super.reloadDataSource()

        DispatchQueue.global().async {
            self.queryDB(isForced: isForced)
        }
    }

    override func reloadDataSourceNetwork(isForced: Bool = false) {
        super.reloadDataSourceNetwork(isForced: isForced)

        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Reload data source network shares forced \(isForced)")

        isReloadDataSourceNetworkInProgress = true
        collectionView?.reloadData()

        NextcloudKit.shared.readShares(parameters: NKShareParameter()) { account, shares, _, error in

            self.refreshControl.endRefreshing()
            self.isReloadDataSourceNetworkInProgress = false

            if error == .success {
                NCManageDatabase.shared.deleteTableShare(account: account)
                if let shares = shares, !shares.isEmpty {
                    let home = NCUtilityFileSystem.shared.getHomeServer(urlBase: self.appDelegate.urlBase, userId: self.appDelegate.userId)
                    NCManageDatabase.shared.addShare(account: self.appDelegate.account, home: home, shares: shares)
                }
            }
            self.reloadDataSource()
        }
    }
}
