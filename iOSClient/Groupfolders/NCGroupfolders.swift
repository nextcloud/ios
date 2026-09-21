// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        Task {
            await NCNetworking.shared.networkingTasks.cancel(identifier: "NCGroupfolders")
        }
    }

    // MARK: - DataSource

    override func reloadDataSource() async {
        var metadatas: [tableMetadata] = []

        if self.serverUrl.isEmpty {
            metadatas = await database.getMetadatasFromGroupfoldersAsync(session: session,
                                                                         layoutForView: layoutForView)
        } else {
            metadatas = await self.database.getMetadatasAsyncDataSource(withServerUrl: self.serverUrl,
                                                                        withUserId: self.session.userId,
                                                                        withAccount: self.session.account,
                                                                        withLayout: self.layoutForView)
        }

        self.dataSource = NCCollectionViewDataSource(metadatas: metadatas,
                                                     layoutForView: layoutForView,
                                                     account: session.account)
        await super.reloadDataSource()
    }

    override func getServerData(forced: Bool = false) async {
        defer {
            stopGUIGetServerData()
        }

        // If is already in-flight, do nothing
        if await NCNetworking.shared.networkingTasks.isReading(identifier: "NCGroupfolders") {
            return
        }

        startGUIGetServerData()

        let homeServerUrl = utilityFileSystem.getHomeServer(session: session)
        let showHiddenFiles = NCPreferences().getShowHiddenFiles(account: session.account)

        let resultsGroupfolders = await NextcloudKit.shared.getGroupfoldersAsync(account: session.account) { task in
            Task {
                await NCNetworking.shared.networkingTasks.track(identifier: "NCGroupfolders", task: task)
            }
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
                                                                                  account: session.account) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.session.account,
                                                                                                path: serverUrlFileName,
                                                                                                name: "readFileOrFolder")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }

            guard resultsReadFile.error == .success, let file = resultsReadFile.files?.first else {
                return
            }

            let metadata = await NCManageDatabaseCreateMetadata().convertFileToMetadataAsync(file)
            await self.database.createDirectory(metadata: metadata)

            await self.reloadDataSource()
        }
    }
}
