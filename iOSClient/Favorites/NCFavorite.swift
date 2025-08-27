// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

class NCFavorite: NCCollectionViewCommon {
    lazy var networkingTasksIdentifier: String = {
        return self.session.account + NCGlobal.shared.taskIdentifierListingFavorites
    }()

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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        Task {
            await NCNetworking.shared.networkingTasks.cancel(identifier: self.networkingTasksIdentifier)
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

        self.dataSource = NCCollectionViewDataSource(metadatas: metadatas,
                                                     layoutForView: layoutForView,
                                                     account: session.account)
        await super.reloadDataSource()

        cachingAsync(metadatas: metadatas)
    }

    override func getServerData(forced: Bool = false) async {
        defer {
            restoreDefaultTitle()
        }

        Task {
            await networking.networkingTasks.cancel(identifier: self.networkingTasksIdentifier)
        }

        showLoadingTitle()

        let showHiddenFiles = NCPreferences().getShowHiddenFiles(account: session.account)
        let resultsListingFavorites = await NextcloudKit.shared.listingFavoritesAsync(showHiddenFiles: showHiddenFiles,
                                                                                      account: session.account) { task in
            Task {
                await NCNetworking.shared.networkingTasks.track(identifier: self.networkingTasksIdentifier, task: task)
            }
            if self.dataSource.isEmpty() {
                self.collectionView.reloadData()
            }
        }

        if resultsListingFavorites.error == .success, let files = resultsListingFavorites.files {
            let (_, metadatas) = await self.database.convertFilesToMetadatasAsync(files)
            await self.database.updateMetadatasFavoriteAsync(account: session.account, metadatas: metadatas)
            await self.reloadDataSource()
        }
    }
}
