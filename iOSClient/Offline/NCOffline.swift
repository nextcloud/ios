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

        reloadDataSource()
    }

    // MARK: - DataSource

    override func reloadDataSource() {
        var ocIds: [String] = []

        if self.serverUrl.isEmpty {
            if let directories = self.database.getTablesDirectory(predicate: NSPredicate(format: "account == %@ AND offline == true", session.account), sorted: "serverUrl", ascending: true) {
                for directory: tableDirectory in directories {
                    ocIds.append(directory.ocId)
                }
            }
            let files = self.database.getTableLocalFiles(predicate: NSPredicate(format: "account == %@ AND offline == true", session.account), sorted: "fileName", ascending: true)
            for file in files {
                ocIds.append(file.ocId)
            }
            let predicate = NSPredicate(format: "account == %@ AND ocId IN %@ AND NOT (status IN %@)", session.account, ocIds, global.metadataStatusHideInView)

            self.database.getMetadatas(predicate: predicate,
                                       layoutForView: layoutForView,
                                       account: session.account) { metadatas, layoutForView, account in
                self.dataSource = NCCollectionViewDataSource(metadatas: metadatas, layoutForView: layoutForView, account: account)
                self.dataSource.caching(metadatas: metadatas) {
                    super.reloadDataSource()
                }
            }
        } else {
            self.database.getMetadatas(predicate: defaultPredicate,
                                       layoutForView: layoutForView,
                                       account: session.account) { metadatas, layoutForView, account in
                self.dataSource = NCCollectionViewDataSource(metadatas: metadatas, layoutForView: layoutForView, account: account)
                self.dataSource.caching(metadatas: metadatas) {
                    super.reloadDataSource()
                }
            }
        }
    }

    override func getServerData() {
        reloadDataSource()
    }
}
