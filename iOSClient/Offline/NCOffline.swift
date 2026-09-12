// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import RealmSwift

class NCOffline: NCCollectionViewCommon {

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        titleCurrentFolder = NSLocalizedString("_manage_file_offline_", comment: "")
        layoutKey = NCGlobal.shared.layoutViewOffline
        enableSearchBar = false
        headerRichWorkspaceDisable = true
        emptyImageName = "icloud.and.arrow.down"
        emptyTitle = "_files_no_files_"
        emptyDescription = "_tutorial_offline_view_"
        emptyDataPortaitOffset = 30
        emptyDataLandscapeOffset = 20
    }

    // MARK: - View Life Cycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        Task {
            await getServerData()
        }
    }

    // MARK: - DataSource

    override func reloadDataSource() async {
        var ocIds: [String] = []
        var predicate: NSPredicate?

        if self.serverUrl.isEmpty {
            let directories = await self.database.getTablesDirectoryAsync(predicate: NSPredicate(format: "account == %@ AND offline == true", session.account), sorted: "serverUrl", ascending: true)
            for directory: tableDirectory in directories {
                ocIds.append(directory.ocId)
            }

            let files = await self.database.getTableLocalFilesAsync(predicate: NSPredicate(format: "account == %@ AND offline == true", session.account))
            for file in files {
                ocIds.append(file.ocId)
            }

            predicate = NSPredicate(format: "account == %@ AND ocId IN %@ AND NOT (status IN %@)", session.account, ocIds, global.metadataStatusHideInView)
        }

        let metadatas = await self.database.getMetadatasAsyncDataSource(withServerUrl: self.serverUrl,
                                                                        withUserId: self.session.userId,
                                                                        withAccount: self.session.account,
                                                                        withLayout: self.layoutForView,
                                                                        withPreficate: predicate)

        self.dataSource = NCCollectionViewDataSource(metadatas: metadatas,
                                                     layoutForView: layoutForView,
                                                     account: session.account)
        await super.reloadDataSource()
    }

    override func getServerData(forced: Bool = false) async {
        defer {
            stopGUIGetServerData()
        }

        await self.reloadDataSource()
    }
}
