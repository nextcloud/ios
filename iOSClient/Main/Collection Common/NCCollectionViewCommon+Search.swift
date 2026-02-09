// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

extension NCCollectionViewCommon {
    func networkSearch() async {
        guard !networkSearchInProgress,
              !session.account.isEmpty,
              let term = literalSearch,
              !term.isEmpty else {
            return
        }
        let capabilities = await NKCapabilities.shared.getCapabilities(for: session.account)

        self.networkSearchInProgress = true
        self.dataSource.removeAll()
        await self.reloadDataSource()

        if capabilities.serverVersionMajor >= global.nextcloudVersion20 {

            // ---> In This folder
            let metadatas = await NCManageDatabase.shared.getMetadatasAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView CONTAINS[c] %@", session.account, self.serverUrl, term)) ?? []
            for metadatas in metadatas {
                metadatas.name = "inthisfolder"
            }
            let provider = NKSearchProvider(id: "inthisfolder", name: "inthisfolder", order: 0)

            self.dataSource = NCCollectionViewDataSource(metadatas: metadatas,
                                                         layoutForView: self.layoutForView,
                                                         providers: [provider],
                                                         searchResults: [],
                                                         account: session.account)
            self.collectionView.reloadData()

            // ---> Get providers
            let results = await NextcloudKit.shared.unifiedSearchProviders(account: session.account) { _ in
                // example filter
                // ["calendar", "files", "fulltextsearch"].contains(provider.id)
                return true
            } taskHandler: { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.session.account,
                                                                                                name: "unifiedSearchProviders")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                    self.searchDataSourceTask = task
                }
            }

            guard results.error == .success else {
                await showErrorBanner(controller: self.controller, text: results.error.errorDescription, errorCode: results.error.errorCode)
                networkSearchInProgress = false
                return
            }

            // ---> Get metadatas for providers
            if let providers = results.providers {
                for provider in providers {
                    let results = await NextcloudKit.shared.unifiedSearch(providerId: provider.id,
                                                                          term: term,
                                                                          limit: 10,
                                                                          cursor: 0,
                                                                          timeout: 90,
                                                                          account: session.account) { task in
                        Task {
                            let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.session.account,
                                                                                                        name: "unifiedSearch")
                            await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                            self.searchDataSourceTask = task
                        }
                    }

                    guard results.error == .success,
                          let searchResult = results.searchResult else {
                        await showErrorBanner(controller: self.controller, text: results.error.errorDescription, errorCode: results.error.errorCode)
                        self.networkSearchInProgress = false
                        return
                    }
                    if let metadatas = await getSearchResultMetadatas(session: session,
                                                                      providerId: provider.id,
                                                                      searchResult: searchResult) {
                        self.dataSource.addSection(metadatas: metadatas, searchResult: searchResult)
                        self.collectionView.reloadData()
                    }
                }
            }

            self.networkSearchInProgress = false

        } else {
            let showHiddenFiles = NCPreferences().getShowHiddenFiles(account: session.account)
            let urlBase = NCSession.shared.getSession(account: session.account).urlBase

            let results = await NextcloudKit.shared.searchLiteralAsync(serverUrl: urlBase,
                                                                       depth: "infinity",
                                                                       literal: term,
                                                                       showHiddenFiles: showHiddenFiles,
                                                                       account: self.session.account) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.session.account,
                                                                                                path: urlBase,
                                                                                                name: "searchLiteral")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                    self.searchDataSourceTask = task
                }
            }

            if results.error == .success,
               let files = results.files {
                let (_, metadatas) = await NCManageDatabaseCreateMetadata().convertFilesToMetadatasAsync(files)
                NCManageDatabase.shared.addMetadatas(metadatas)
                self.dataSource = NCCollectionViewDataSource(metadatas: metadatas,
                                                             layoutForView: self.layoutForView,
                                                             account: self.session.account)
            } else {
                await showErrorBanner(controller: self.controller,
                                      text: results.error.errorDescription,
                                      errorCode: results.error.errorCode)
            }
            self.networkSearchInProgress = false
        }
    }

    func unifiedSearchMore(metadataForSection: NCMetadataForSection?) async {
        guard let metadataForSection = metadataForSection,
              let lastSearchResult = metadataForSection.lastSearchResult,
              let cursor = lastSearchResult.cursor,
              let term = literalSearch else { return }

        metadataForSection.unifiedSearchInProgress = true
        await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
            delegate.transferReloadData(serverUrl: nil)
        }

        /*
        let results = await self.networking.unifiedSearchFilesProvider(providerId: lastSearchResult.id,
                                                                       term: term,
                                                                       limit: 20,
                                                                       cursor: cursor,
                                                                       account: session.account) { task in
            Task {
                self.searchDataSourceTask = task
                await self.reloadDataSource()
            }
        }

        if results.error != .success {
            Task {
                await showErrorBanner(controller: self.controller, text: results.error.errorDescription, errorCode: results.error.errorCode)
            }
        }

        guard results.error == .success,
              let searchResult = results.searchResult,
              let metadatas = results.metadatas else {
            return
        }

        metadataForSection.unifiedSearchInProgress = false
        self.dataSource.appendMetadatasToSection(metadatas, metadataForSection: metadataForSection, lastSearchResult: searchResult)

        await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
            delegate.transferReloadData(serverUrl: nil)
        }
        */
    }

    private func getSearchResultMetadatas(session: NCSession.Session,
                                          providerId: String,
                                          searchResult: NKSearchResult,
    ) async -> [tableMetadata]? {
        var metadatas: [tableMetadata] = []

        switch providerId {
        case "files":
            for entry in searchResult.entries {
                if let filePath = entry.filePath {
                    if let metadata = await loadMetadata(session: session, filePath: filePath) {
                        metadatas.append(metadata)
                    }
                } else {
                    print(#function, "[ERROR]: File search entry has no path: \(entry)")
                }
            }

            return(metadatas)

            case "fulltextsearch":
                for entry in searchResult.entries {
                    let url = URLComponents(string: entry.resourceURL)
                    guard let dir = url?.queryItems?["dir"]?.value, let filename = url?.queryItems?["scrollto"]?.value else {
                        return(nil)
                    }
                    if let metadata = await NCManageDatabase.shared.getMetadataAsync(
                        predicate: NSPredicate(format: "account == %@ && path == %@ && fileName == %@", session.account, "/remote.php/dav/files/" + session.user + dir, filename)) {
                        metadatas.append(metadata)
                    } else {
                        if let metadata = await loadMetadata(session: session, filePath: dir + filename) {
                            metadatas.append(metadata)
                        }
                    }

                }
                return(metadatas)
            default:
                for entry in searchResult.entries {
                    let metadata = await NCManageDatabaseCreateMetadata().createMetadataAsync(
                        fileName: entry.title,
                        ocId: NSUUID().uuidString,
                        serverUrl: session.urlBase,
                        url: entry.resourceURL,
                        isUrl: true,
                        name: searchResult.id,
                        subline: entry.subline,
                        iconUrl: entry.thumbnailURL,
                        session: session,
                        sceneIdentifier: nil)
                    metadatas.append(metadata)
                }
                return(metadatas)
            }
        }

    private func loadMetadata(session: NCSession.Session,
                              filePath: String) async -> tableMetadata? {
        let urlPath = session.urlBase + "/remote.php/dav/files/" + session.user + filePath
        let results = await NCNetworking.shared.readFileAsync(serverUrlFileName: urlPath, account: session.account)
        guard let metadata = results.metadata else {
            return nil
        }

        NCManageDatabase.shared.addMetadata(metadata)
        return metadata
    }
}
