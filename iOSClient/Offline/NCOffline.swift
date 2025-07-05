//
//  NCOffline.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 24/10/2018.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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
            await self.reloadDataSource()
        }
    }

    // MARK: - DataSource

    override func reloadDataSource() async {
        var ocIds: [String] = []
        var predicate: NSPredicate = defaultPredicate

        if self.serverUrl.isEmpty {
            let directories = await self.database.getTablesDirectoryAsync(predicate: NSPredicate(format: "account == %@ AND offline == true", session.account), sorted: "serverUrl", ascending: true)
            for directory: tableDirectory in directories {
                ocIds.append(directory.ocId)
            }

            let files = await self.database.getTableLocalFilesAsync(predicate: NSPredicate(format: "account == %@ AND offline == true", session.account), sorted: "fileName", ascending: true)
            for file in files {
                ocIds.append(file.ocId)
            }

            predicate = NSPredicate(format: "account == %@ AND ocId IN %@ AND NOT (status IN %@)", session.account, ocIds, global.metadataStatusHideInView)
        }

        let metadatas = await self.database.getMetadatasAsync(predicate: predicate,
                                                              layoutForView: layoutForView,
                                                              account: session.account)

        self.dataSource = NCCollectionViewDataSource(metadatas: metadatas, layoutForView: layoutForView, account: session.account)
        await super.reloadDataSource()

        cachingAsync(metadatas: metadatas)
    }

    override func getServerData(refresh: Bool = false) async {
        await super.getServerData()

        await self.reloadDataSource()
    }
}
