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
import NextcloudKit

class NCFavorite: NCCollectionViewCommon {

    // MARK: - View Life Cycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        titleCurrentFolder = NSLocalizedString("_favorites_", comment: "")
        layoutKey = NCGlobal.shared.layoutViewFavorite
        enableSearchBar = false
        headerMenuButtonsView = true
        headerRichWorkspaceDisable = false
        emptyImage = UIImage(named: "star.fill")?.image(color: NCBrandColor.shared.yellowFavorite, size: UIScreen.main.bounds.width)
        emptyTitle = "_favorite_no_files_"
        emptyDescription = "_tutorial_favorite_view_"
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setFileAppreance()
    }

    // MARK: - DataSource + NC Endpoint

    override func queryDB(isForced: Bool) {

        var metadatas: [tableMetadata] = []

        if self.serverUrl.isEmpty {
            metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND favorite == true", self.appDelegate.account))
        } else {
            metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, self.serverUrl))
        }

        self.dataSource = NCDataSource(metadatas: metadatas,
                                       account: self.appDelegate.account,
                                       sort: self.layoutForView?.sort,
                                       ascending: self.layoutForView?.ascending,
                                       directoryOnTop: self.layoutForView?.directoryOnTop,
                                       favoriteOnTop: true,
                                       filterLivePhoto: true,
                                       groupByField: self.groupByField,
                                       providers: self.providers,
                                       searchResults: self.searchResults)
    }

    override func reloadDataSource(isForced: Bool = true) {
        super.reloadDataSource()

        DispatchQueue.global().async {
            self.queryDB(isForced: isForced)
            DispatchQueue.main.async {
                self.refreshControl.endRefreshing()
                self.collectionView.reloadData()
            }
        }
    }

    override func reloadDataSourceNetwork(isForced: Bool = false) {
        super.reloadDataSourceNetwork(isForced: isForced)

        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Reload data source network favorite forced \(isForced)")

        isReloadDataSourceNetworkInProgress = true
        collectionView?.reloadData()

        if serverUrl.isEmpty {

            NextcloudKit.shared.listingFavorites(showHiddenFiles: CCUtility.getShowHiddenFiles(),
                                                 options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { account, files, _, error in

                self.isReloadDataSourceNetworkInProgress = false
                if error == .success {
                    NCManageDatabase.shared.convertFilesToMetadatas(files, useMetadataFolder: false) { _, _, metadatas in
                        NCManageDatabase.shared.updateMetadatasFavorite(account: account, metadatas: metadatas)
                        self.reloadDataSource()
                    }
                } else {
                    NCContentPresenter.shared.showError(error: error)
                    self.reloadDataSource()
                }
            }

        } else {

            networkReadFolder(isForced: isForced) { tableDirectory, metadatas, _, _, error in

                self.isReloadDataSourceNetworkInProgress = false
                if error == .success, let metadatas {
                    for metadata in metadatas where (!metadata.directory && NCManageDatabase.shared.isDownloadMetadata(metadata, download: false)) {
                        NCOperationQueue.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorDownloadFile)
                    }
                }
                self.richWorkspaceText = tableDirectory?.richWorkspace
                self.reloadDataSource()
            }
        }
    }
}
