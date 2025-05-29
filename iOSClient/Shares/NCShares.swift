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
    private var backgroundTask: Task<Void, Never>?

    @MainActor private var ocIdShares: Set<String> = []

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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        backgroundTask?.cancel()
    }

    // MARK: - DataSource

    override func reloadDataSource() {
        database.getMetadatas(predicate: NSPredicate(format: "ocId IN %@", ocIdShares),
                              layoutForView: layoutForView,
                              account: session.account) { metadatas, layoutForView, account in
            self.dataSource = NCCollectionViewDataSource(metadatas: metadatas, layoutForView: layoutForView, account: account)
            self.dataSource.caching(metadatas: metadatas) {
                super.reloadDataSource()
            }
        }
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
                self.backgroundTask = Task.detached(priority: .background) { [weak self] in
                    guard let self = self
                    else {
                        return
                    }
                    let sharess = await self.database.getTableShares(account: self.session.account)

                    for share in sharess {
                        if let ocId = await self.database.getResultMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", session.account, share.serverUrl, share.fileName))?.ocId {
                            _ = await MainActor.run {
                                self.ocIdShares.insert(ocId)
                            }
                        } else {
                            let serverUrlFileName = share.serverUrl + "/" + share.fileName
                            let result = await NCNetworking.shared.readFile(serverUrlFileName: serverUrlFileName, account: session.account)
                            if result.error == .success, let metadata = result.metadata {
                                let ocId = metadata.ocId
                                self.database.addMetadata(metadata)
                                _ = await MainActor.run {
                                    self.ocIdShares.insert(ocId)
                                }
                            }
                        }
                        if Task.isCancelled {
                            return
                        }
                    }

                    await MainActor.run {
                        self.reloadDataSource()
                        self.refreshControlEndRefreshing()
                    }
                }
            } else {
                self.reloadDataSource()
                self.refreshControlEndRefreshing()
            }
        }
    }
}
