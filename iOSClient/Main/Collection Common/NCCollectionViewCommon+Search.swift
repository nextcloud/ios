// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

extension NCCollectionViewCommon {
    func search() async {
        guard !networkSearchInProgress,
              !session.account.isEmpty,
              let term = literalSearch,
              !term.isEmpty else {
            return
        }
        let capabilities = await NKCapabilities.shared.getCapabilities(for: session.account)

        self.networkSearchInProgress = true
        // STOP PREEMPTIVE SYNC METADATA
        self.stopSyncMetadata()
        // Clear datasotce
        self.dataSource.removeAll()
        await self.reloadDataSource()

        if capabilities.serverVersionMajor >= global.nextcloudVersion20 {
            await unifiedSearch(term: term)
        } else {
            await searchLiteral(term: term)
        }
    }

    // MARK: - search Literal

    private func searchLiteral(term: String) async {
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
                self.searchTask = task
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

        self.collectionView.reloadData()
        self.networkSearchInProgress = false
    }

    // MARK: - Unifield Search

    private func unifiedSearch(term: String) async {

        // ---> In This folder
        let metadatas = await NCManageDatabase.shared.getMetadatasAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView CONTAINS[c] %@", session.account, self.serverUrl, term)) ?? []
        for metadatas in metadatas {
            metadatas.section = NSLocalizedString("_in_this_folder_", comment: "")
        }
        self.dataSource = NCCollectionViewDataSource(metadatas: metadatas,
                                                     layoutForView: self.layoutForView,
                                                     isSections: true,
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
                self.searchTask = task
                self.collectionView.reloadData()
            }
        }

        if results.error != .success {
            await showErrorBanner(controller: self.controller, text: results.error.errorDescription, errorCode: results.error.errorCode)
        }

        guard results.error == .success,
              let providers = results.providers else {
            networkSearchInProgress = false
            return
        }

        // ---> Get metadatas for providers
        for provider in providers {
            let results = await NextcloudKit.shared.unifiedSearch(providerId: provider.id,
                                                                  term: term,
                                                                  limit: 3,
                                                                  cursor: 0,
                                                                  timeout: 90,
                                                                  account: session.account) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.session.account,
                                                                                                name: "unifiedSearch")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                    self.searchTask = task
                    self.collectionView.reloadData()
                }
            }

            if results.error != .success {
                await showErrorBanner(
                    controller: self.controller,
                    text: results.error.errorDescription,
                    errorCode: results.error.errorCode
                )
            }

            if let searchResult = results.searchResult,
               let metadatas = await getSearchResultMetadatas(session: session,
                                                              provider: provider,
                                                              searchResult: searchResult) {
                self.dataSource.addSection(metadatas: metadatas, searchResult: searchResult)
                self.collectionView.reloadData()
            }
        }

        self.networkSearchInProgress = false
    }

    func unifiedSearchMore(metadataForSection: NCMetadataForSection?) async {
        guard let metadataForSection = metadataForSection,
              let lastSearchResult = metadataForSection.lastSearchResult,
              let cursor = lastSearchResult.cursor,
              let term = literalSearch else { return }

        metadataForSection.unifiedSearchInProgress = true
        self.collectionView.reloadData()

        let results = await NextcloudKit.shared.unifiedSearch(providerId: lastSearchResult.id,
                                                              term: term,
                                                              limit: 10,
                                                              cursor: cursor,
                                                              timeout: 60,
                                                              account: session.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.session.account,
                                                                                            name: "unifiedSearch")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                self.searchTask = task
                self.collectionView.reloadData()
            }
        }

        if results.error != .success {
            await showErrorBanner(controller: self.controller, text: results.error.errorDescription, errorCode: results.error.errorCode)
        }

        /*
        if let searchResult = results.searchResult,
           let metadatas = await getSearchResultMetadatas(session: session,
                                                          provider: provider,
                                                          searchResult: searchResult) {
            self.dataSource.appendMetadatasToSection(metadatas, metadataForSection: metadataForSection, lastSearchResult: searchResult)
            self.collectionView.reloadData()
        }
        */

        metadataForSection.unifiedSearchInProgress = false
    }

    // MARK: - Helper

    private func getSearchResultMetadatas(session: NCSession.Session,
                                          provider: NKSearchProvider,
                                          searchResult: NKSearchResult,
    ) async -> [tableMetadata]? {
        var metadatas: [tableMetadata] = []

        switch provider.id {
        case "files":
            for entry in searchResult.entries {
                if let filePath = entry.filePath {
                    if let metadata = await loadMetadata(session: session, provider: provider, filePath: filePath) {
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
                        if let metadata = await loadMetadata(session: session, provider: provider, filePath: dir + filename) {
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
                              provider: NKSearchProvider,
                              filePath: String) async -> tableMetadata? {
        let urlPath = session.urlBase + "/remote.php/dav/files/" + session.user + filePath
        let results = await NCNetworking.shared.readFileAsync(serverUrlFileName: urlPath, account: session.account)
        guard let metadata = results.metadata else {
            return nil
        }
        metadata.section = provider.name

        NCManageDatabase.shared.addMetadata(metadata)
        return metadata
    }
}
