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
        emptyImageName = "person.fill.badge.plus"
        emptyTitle = "_list_shares_no_files_"
        emptyDescription = "_tutorial_list_shares_view_"
    }

    // MARK: - View Life Cycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        reloadDataSource()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        getServerData()
    }

    // MARK: - DataSource

    override func reloadDataSource() {
        var ocId: [String] = []
        let sharess = self.database.getTableShares(account: session.account)
        let directoryOnTop = NCKeychain().getDirectoryOnTop(account: session.account)

        for share in sharess {
            if let result = self.database.getResultMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", session.account, share.serverUrl, share.fileName)) {
                if !(ocId.contains { $0 == result.ocId }) {
                    ocId.append(result.ocId)
                }
            } else {
                let serverUrlFileName = share.serverUrl + "/" + share.fileName
                NCNetworking.shared.readFile(serverUrlFileName: serverUrlFileName, account: session.account) { task in
                    self.dataSourceTask = task
                    if self.dataSource.isEmpty() {
                        self.collectionView.reloadData()
                    }
                } completion: { _, metadata, _ in
                    if let metadata {
                        self.database.addMetadata(metadata)
                        if !(ocId.contains { $0 == metadata.ocId }) {
                            ocId.append(metadata.ocId)
                        }
                    }
                }
            }
        }

        let metadatas = self.database.getResultsMetadatasPredicate(NSPredicate(format: "ocId IN %@", ocId), layoutForView: layoutForView, directoryOnTop: directoryOnTop)

        self.dataSource = NCCollectionViewDataSource(metadatas: metadatas, layoutForView: layoutForView, directoryOnTop: directoryOnTop)

        super.reloadDataSource()
    }

    override func getServerData() {
        NextcloudKit.shared.readShares(parameters: NKShareParameter(), account: session.account) { task in
            self.dataSourceTask = task
            if self.dataSource.isEmpty() {
                self.collectionView.reloadData()
            }
        } completion: { account, shares, _, error in
            if error == .success {
                self.database.deleteTableShare(account: account)
                if let shares = shares, !shares.isEmpty {
                    let home = self.utilityFileSystem.getHomeServer(session: self.session)
                    self.database.addShare(account: account, home: home, shares: shares)
                }
                self.reloadDataSource()
            }
            self.refreshControl.endRefreshing()
        }
    }
}
