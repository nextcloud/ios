// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

class NCShares: NCCollectionViewCommon {
    @MainActor private var fileIds: Set<String> = []

    private var backgroundTask: Task<Void, Never>?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        titleCurrentFolder = NSLocalizedString("_list_shares_", comment: "")
        layoutKey = NCGlobal.shared.layoutViewShares
        enableSearchBar = false
        headerRichWorkspaceDisable = true
        emptyImageName = "person.fill.badge.plus"
        emptyTitle = "_list_shares_no_files_"
        emptyDescription = "_tutorial_list_shares_view_"
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

        stopSyncMetadata()
        Task {
            await NCNetworking.shared.networkingTasks.cancel(identifier: "NCShares")
            backgroundTask?.cancel()
        }
    }

    // MARK: - DataSource

    override func reloadDataSource() async {
        if fileIds.isEmpty {
            let shares = await self.database.getTableSharesAsync(account: self.session.account)
            fileIds = Set(shares.compactMap { String($0.fileSource) })
        }
        let metadatas = await database.getMetadatasAsync(predicate: NSPredicate(format: "fileId IN %@", fileIds),
                                                         withLayout: layoutForView,
                                                         withAccount: session.account)

        self.dataSource = NCCollectionViewDataSource(metadatas: metadatas,
                                                     layoutForView: layoutForView,
                                                     account: session.account)

        await super.reloadDataSource()

        cachingAsync(metadatas: metadatas)
    }

    override func getServerData(forced: Bool = false) async {
        // If is already in-flight, do nothing
        if await NCNetworking.shared.networkingTasks.isReading(identifier: "NCShares") {
            return
        }

        startGUIGetServerData()

        let resultsReadShares = await NextcloudKit.shared.readSharesAsync(parameters: NKShareParameter(), account: session.account) { task in
            Task {
                await NCNetworking.shared.networkingTasks.track(identifier: "NCShares", task: task)
            }
            if self.dataSource.isEmpty() {
                self.collectionView.reloadData()
            }
        }

        guard resultsReadShares.error == .success else {
            self.stopGUIGetServerData()
            await self.reloadDataSource()
            return
        }

        await self.database.deleteTableShareAsync(account: session.account)

        if let shares = resultsReadShares.shares, !shares.isEmpty {
            let home = self.utilityFileSystem.getHomeServer(session: self.session)
            await self.database.addShareAsync(account: session.account, home: home, shares: shares)
        }

        self.backgroundTask = Task.detached(priority: .utility) { [weak self] in
            guard let self = self
            else {
                return
            }
            _ = await MainActor.run {
                self.fileIds.removeAll()
            }
            let sharess = await self.database.getTableSharesAsync(account: self.session.account)

            for share in sharess {
                let fileId = "\(share.fileSource)"
                let predicate = await NSPredicate(format: "account == %@ AND fileId == %@", session.account, fileId)
                if await self.database.metadataExistsAsync(predicate: predicate) {
                    _ = await MainActor.run {
                        self.fileIds.insert(fileId)
                    }
                } else {
                    let serverUrlFileName = NCUtilityFileSystem().createServerUrl(serverUrl: share.serverUrl, fileName: share.fileName)
                    let resultReadShare = await NCNetworking.shared.readFileAsync(serverUrlFileName: serverUrlFileName, account: session.account)
                    if resultReadShare.error == .success, let metadata = resultReadShare.metadata {
                        let fileId = metadata.fileId
                        self.database.addMetadata(metadata)
                        _ = await MainActor.run {
                            self.fileIds.insert(fileId)
                        }
                    }
                }
                if Task.isCancelled {
                    return
                }
            }

            Task {
                await self.stopGUIGetServerData()
                await self.reloadDataSource()
                await self.startSyncMetadata(metadatas: self.dataSource.getMetadatas())
            }
        }
    }
}
