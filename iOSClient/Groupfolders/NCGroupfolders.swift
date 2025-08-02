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
import RealmSwift

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

        Task {
            await reloadDataSource()
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
        var metadatas: [tableMetadata] = []

        if self.serverUrl.isEmpty {
            metadatas = await database.getMetadatasFromGroupfoldersAsync(session: session,
                                                                         layoutForView: layoutForView)
        } else {
            metadatas = await database.getMetadatasAsync(predicate: defaultPredicate,
                                                         withLayout: layoutForView,
                                                         withAccount: session.account)
        }

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

        let homeServerUrl = utilityFileSystem.getHomeServer(session: session)
        let showHiddenFiles = NCKeychain().getShowHiddenFiles(account: session.account)

        let resultsGroupfolders = await NextcloudKit.shared.getGroupfoldersAsync(account: session.account) { task in
            self.dataSourceTask = task
            if self.dataSource.isEmpty() {
                self.collectionView.reloadData()
            }
        }

        guard resultsGroupfolders.error == .success, let groupfolders = resultsGroupfolders.results else {
            return
        }

        await self.database.addGroupfoldersAsync(account: session.account, groupfolders: groupfolders)

        for groupfolder in groupfolders {
            let mountPoint = groupfolder.mountPoint.hasPrefix("/") ? groupfolder.mountPoint : "/" + groupfolder.mountPoint
            let serverUrlFileName = homeServerUrl + mountPoint
            let resultsReadFile = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: serverUrlFileName,
                                                                                  depth: "0", showHiddenFiles: showHiddenFiles,
                                                                                  account: session.account)

            guard resultsReadFile.error == .success, let file = resultsReadFile.files?.first else {
                return
            }

            let metadata = await self.database.convertFileToMetadataAsync(file)

            await self.database.addMetadataAsync(metadata)
            await self.database.addDirectoryAsync(serverUrl: serverUrlFileName,
                                                  ocId: metadata.ocId,
                                                  fileId: metadata.fileId,
                                                  permissions: metadata.permissions,
                                                  favorite: metadata.favorite,
                                                  account: metadata.account)
            await self.reloadDataSource()
        }
    }
}
