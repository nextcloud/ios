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

        Task {
            await self.reloadDataSource()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        Task {
            await getServerData()
        }
    }

    // MARK: - DataSource

    override func reloadDataSource() async {
        var predicate = self.defaultPredicate

        if self.serverUrl.isEmpty {
           predicate = NSPredicate(format: "account == %@ AND favorite == true AND NOT (status IN %@)", session.account, global.metadataStatusHideInView)
        }

        let metadatas = await self.database.getMetadatasAsync(predicate: predicate,
                                                              withLayout: layoutForView,
                                                              withAccount: session.account)

        self.dataSource = NCCollectionViewDataSource(metadatas: metadatas, layoutForView: layoutForView, account: session.account)
        await super.reloadDataSource()

        cachingAsync(metadatas: metadatas)
    }

    override func getServerData(refresh: Bool = false) async {
        await super.getServerData()

        defer {
            restoreDefaultTitle()
        }

        showLoadingTitle()

        let showHiddenFiles = NCKeychain().getShowHiddenFiles(account: session.account)

        let resultsListingFavorites = await NextcloudKit.shared.listingFavoritesAsync(showHiddenFiles: showHiddenFiles,
                                                                                      account: session.account) { task in
            self.dataSourceTask = task
            if self.dataSource.isEmpty() {
                self.collectionView.reloadData()
            }
        }

        if resultsListingFavorites.error == .success, let files = resultsListingFavorites.files {
            let (_, metadatas) = await self.database.convertFilesToMetadatasAsync(files, useFirstAsMetadataFolder: false)
            await self.database.updateMetadatasFavoriteAsync(account: session.account, metadatas: metadatas)
            await self.reloadDataSource()
        }
    }
}
