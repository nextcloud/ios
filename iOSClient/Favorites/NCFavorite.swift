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

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        titleCurrentFolder = NSLocalizedString("_favorites_", comment: "")
        layoutKey = NCGlobal.shared.layoutViewFavorite
        enableSearchBar = false
        headerRichWorkspaceDisable = true
        emptyImage = utility.loadImage(named: "star.fill", colors: [NCBrandColor.shared.yellowFavorite])
        emptyTitle = "_favorite_no_files_"
        emptyDescription = "_tutorial_favorite_view_"
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

        if self.serverUrl.isEmpty {
            metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND favorite == true", self.appDelegate.account))
        } else {
            metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, self.serverUrl))
        }

        self.dataSource = NCDataSource(metadatas: metadatas, account: self.appDelegate.account, layoutForView: layoutForView, providers: self.providers, searchResults: self.searchResults)
    }

    override func reloadDataSourceNetwork(withQueryDB: Bool = false) {
        super.reloadDataSourceNetwork()

        NextcloudKit.shared.listingFavorites(showHiddenFiles: NCKeychain().showHiddenFiles, account: self.appDelegate.account, options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { task in
            self.dataSourceTask = task
            self.collectionView.reloadData()
        } completion: { account, files, _, error in
            if error == .success {
                NCManageDatabase.shared.convertFilesToMetadatas(files, useFirstAsMetadataFolder: false) { _, metadatas in
                    NCManageDatabase.shared.updateMetadatasFavorite(account: account, metadatas: metadatas)
                    self.reloadDataSource()
                }
            } else {
                self.reloadDataSource(withQueryDB: withQueryDB)
            }
        }
    }
}
