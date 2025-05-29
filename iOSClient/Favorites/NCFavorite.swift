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
        emptyImageName = "star.fill"
        emptyImageColors = [NCBrandColor.shared.yellowFavorite]
        emptyTitle = "_favorite_no_files_"
        emptyDescription = "_tutorial_favorite_view_"
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
        var predicate = self.defaultPredicate

        if self.serverUrl.isEmpty {
           predicate = NSPredicate(format: "account == %@ AND favorite == true AND NOT (status IN %@)", session.account, global.metadataStatusHideInView)
        }

        self.database.getMetadatas(predicate: predicate,
                                   layoutForView: layoutForView,
                                   account: session.account) { metadatas, layoutForView, account in
            self.dataSource = NCCollectionViewDataSource(metadatas: metadatas, layoutForView: layoutForView, account: account)
            self.dataSource.caching(metadatas: metadatas) {
                super.reloadDataSource()
            }
        }
    }

    override func getServerData() {
        let showHiddenFiles = NCKeychain().getShowHiddenFiles(account: session.account)

        NextcloudKit.shared.listingFavorites(showHiddenFiles: showHiddenFiles, account: session.account) { task in
            self.dataSourceTask = task
            if self.dataSource.isEmpty() {
                self.collectionView.reloadData()
            }
        } completion: { account, files, _, error in
            if error == .success, let files {
                self.database.convertFilesToMetadatas(files, useFirstAsMetadataFolder: false) { _, metadatas in
                    self.database.updateMetadatasFavorite(account: account, metadatas: metadatas)
                    self.reloadDataSource()
                }
            }
            self.refreshControlEndRefreshing()
        }
    }
}
