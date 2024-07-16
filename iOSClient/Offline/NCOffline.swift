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

class NCOffline: NCCollectionViewCommon {

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        titleCurrentFolder = NSLocalizedString("_manage_file_offline_", comment: "")
        layoutKey = NCGlobal.shared.layoutViewOffline
        enableSearchBar = false
        headerRichWorkspaceDisable = true
        emptyImage = NCUtility().loadImage(named: "icloud.and.arrow.down", colors: [NCBrandColor.shared.brandElement])
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

    // MARK: - DataSource + NC Endpoint

    override func queryDB() {
        super.queryDB()

        var ocIds: [String] = []
        var metadatas: [tableMetadata] = []

        if self.serverUrl.isEmpty {
            if let directories = NCManageDatabase.shared.getTablesDirectory(predicate: NSPredicate(format: "account == %@ AND offline == true", self.appDelegate.account), sorted: "serverUrl", ascending: true) {
                for directory: tableDirectory in directories {
                    ocIds.append(directory.ocId)
                }
            }
            let files = NCManageDatabase.shared.getTableLocalFiles(predicate: NSPredicate(format: "account == %@ AND offline == true", self.appDelegate.account), sorted: "fileName", ascending: true)
            for file in files {
                ocIds.append(file.ocId)
            }
            metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND ocId IN %@", self.appDelegate.account, ocIds))
        } else {
            metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, self.serverUrl))
        }

        self.dataSource = NCDataSource(metadatas: metadatas, account: self.appDelegate.account, layoutForView: layoutForView, providers: self.providers, searchResults: self.searchResults)
    }

    override func reloadDataSourceNetwork(withQueryDB: Bool = false) {
        super.reloadDataSourceNetwork(withQueryDB: withQueryDB)
        reloadDataSource()
    }
}
