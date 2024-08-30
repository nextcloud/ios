//
//  NCGroupfolders.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 14/04/2023.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
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

class NCGroupfolders: NCCollectionViewCommon {

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        titleCurrentFolder = NSLocalizedString("_group_folders_", comment: "")
        layoutKey = NCGlobal.shared.layoutViewGroupfolders
        enableSearchBar = false
        headerRichWorkspaceDisable = true
        emptyImageName = "folder_group"
        emptyTitle = "_files_no_files_"
        emptyDescription = "_tutorial_groupfolders_view_"
    }

    // MARK: - View Life Cycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if self.dataSource.metadatas.isEmpty {
            reloadDataSource()
        }
        reloadDataSourceNetwork()
    }

    // MARK: - DataSource + NC Endpoint

    override func queryDB() {
        super.queryDB()
        var metadatas: [tableMetadata] = []

        if self.serverUrl.isEmpty {
            metadatas = NCManageDatabase.shared.getMetadatasFromGroupfolders(session: session)
        } else {
            metadatas = NCManageDatabase.shared.getMetadatasAccount(session.account, serverUrl: self.serverUrl, layoutForView: layoutForView)
        }

        self.dataSource = NCDataSource(metadatas: metadatas, layoutForView: layoutForView)
    }

    override func reloadDataSourceNetwork(withQueryDB: Bool = false) {
        super.reloadDataSourceNetwork()
        let homeServerUrl = utilityFileSystem.getHomeServer(session: session)

        NextcloudKit.shared.getGroupfolders(account: session.account, options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { task in
            self.dataSourceTask = task
            self.collectionView.reloadData()
        } completion: { account, results, _, error in
            if error == .success, let groupfolders = results {
                NCManageDatabase.shared.addGroupfolders(account: account, groupfolders: groupfolders)
                Task {
                    for groupfolder in groupfolders {
                        let mountPoint = groupfolder.mountPoint.hasPrefix("/") ? groupfolder.mountPoint : "/" + groupfolder.mountPoint
                        let serverUrlFileName = homeServerUrl + mountPoint
                        if NCManageDatabase.shared.getMetadataFromDirectory(account: account, serverUrl: serverUrlFileName) == nil {
                            let results = await NCNetworking.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", showHiddenFiles: NCKeychain().showHiddenFiles, account: account)
                            if results.error == .success, let file = results.files?.first {
                                let isDirectoryE2EE = self.utilityFileSystem.isDirectoryE2EE(file: file)
                                let metadata = NCManageDatabase.shared.convertFileToMetadata(file, isDirectoryE2EE: isDirectoryE2EE)
                                NCManageDatabase.shared.addMetadata(metadata)
                                NCManageDatabase.shared.addDirectory(e2eEncrypted: isDirectoryE2EE, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, permissions: metadata.permissions, serverUrl: serverUrlFileName, account: metadata.account)
                            }
                        }
                    }
                    self.reloadDataSource()
                }
            } else {
                self.reloadDataSource(withQueryDB: withQueryDB)
            }
        }
    }
}
