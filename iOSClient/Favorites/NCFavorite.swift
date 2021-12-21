//
//  NCFavorite.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 26/08/2020.
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

class NCFavorite: NCCollectionViewCommon {

    // MARK: - View Life Cycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        titleCurrentFolder = NSLocalizedString("_favorites_", comment: "")
        layoutKey = NCGlobal.shared.layoutViewFavorite
        enableSearchBar = true
        emptyImage = UIImage(named: "star.fill")?.image(color: NCBrandColor.shared.yellowFavorite, size: UIScreen.main.bounds.width)
        emptyTitle = "_favorite_no_files_"
        emptyDescription = "_tutorial_favorite_view_"
    }

    // MARK: - DataSource + NC Endpoint

    override func reloadDataSource() {
        super.reloadDataSource()

        DispatchQueue.global().async {

            if !self.isSearching {

                if self.serverUrl == "" {
                    self.metadatasSource = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND favorite == true", self.appDelegate.account))
                } else {
                    self.metadatasSource = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, self.serverUrl))
                }
            }

            self.dataSource = NCDataSource(metadatasSource: self.metadatasSource, sort: self.layoutForView?.sort, ascending: self.layoutForView?.ascending, directoryOnTop: self.layoutForView?.directoryOnTop, favoriteOnTop: true, filterLivePhoto: true)

            DispatchQueue.main.async {
                self.refreshControl.endRefreshing()
                self.collectionView.reloadData()
            }
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

        if serverUrl == "" {

            NCNetworking.shared.listingFavoritescompletion(selector: NCGlobal.shared.selectorListingFavorite) { _, _, errorCode, errorDescription in
                if errorCode != 0 {
                    NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                }

                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
                    self.isReloadDataSourceNetworkInProgress = false
                    self.reloadDataSource()
                }
            }

        } else {

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

                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
                    self.isReloadDataSourceNetworkInProgress = false
                    self.richWorkspaceText = tableDirectory?.richWorkspace
                    if metadatasUpdate?.count ?? 0 > 0 || metadatasDelete?.count ?? 0 > 0 || forced {
                        self.reloadDataSource()
                    } else {
                        self.collectionView?.reloadData()
                    }
                }
            }
        }
    }
}
