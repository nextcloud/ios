// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import Alamofire

extension NCCollectionViewCommon {
    @MainActor
    func search() async {
        guard !networkSearchInProgress,
              !session.account.isEmpty,
              let text = searchResultText,
              !text.isEmpty else {
            return
        }
        let capabilities = await NKCapabilities.shared.getCapabilities(for: session.account)

        // Force layoutList
        let layoutForView = database.getLayoutForView(account: session.account, key: layoutKey, serverUrl: serverUrl)
        layoutForViewLayoutStore = layoutForView.layout
        layoutForView.layout = self.global.layoutList
        changeLayout(layoutForView: layoutForView)

        // STOP PREEMPTIVE SYNC METADATA
        await self.stopSyncMetadata()
        // Clear datasotce
        dataSource.removeAll()
        collectionView.reloadData()
        // Start spinner
        setSearchBarLoading(true)
        networkSearchInProgress = true

        if capabilities.serverVersionMajor >= global.nextcloudVersion20 {
            await unifiedSearch(text: text)
        } else {
            await searchLiteral(text: text)
        }
    }

    // MARK: - search Literal

    private func searchLiteral(text: String) async {
        defer {
            networkSearchInProgress = false
            setSearchBarLoading(false)
        }

        let showHiddenFiles = NCPreferences().getShowHiddenFiles(account: session.account)
        let urlBase = NCSession.shared.getSession(account: session.account).urlBase

        let results = await NextcloudKit.shared.searchLiteralAsync(
            serverUrl: urlBase,
            depth: "infinity",
            literal: text,
            showHiddenFiles: showHiddenFiles,
            account: self.session.account
        ) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                    account: self.session.account,
                    path: urlBase,
                    name: "searchLiteral"
                )
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                self.searchTask = task
            }
        }

        if results.error == .success,
           let files = results.files {
            let (_, metadatas) = await NCManageDatabaseCreateMetadata().convertFilesToMetadatasAsync(files)
            NCManageDatabase.shared.addMetadatas(metadatas)
            self.dataSource = NCCollectionViewDataSource(
                metadatas: metadatas,
                layoutForView: self.layoutForView,
                account: self.session.account
            )
        } else {
            await showErrorBanner(controller: self.controller,
                                  text: results.error.errorDescription,
                                  errorCode: results.error.errorCode)
        }

        self.collectionView.reloadData()
    }

    // MARK: - Unifield Search

    private func unifiedSearch(text: String) async {
        defer {
            networkSearchInProgress = false
            setSearchBarLoading(false)
            Task {
                if !isSearchingMode {
                    self.dataSource.removeAll()
                    await self.reloadDataSource()
                }
            }
        }

        // Store the search
        self.searchResultStore = text

        // ---> In This folder
        let metadatas = await NCManageDatabase.shared.getMetadatasAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView CONTAINS[c] %@", session.account, self.serverUrl, text)) ?? []
        for metadatas in metadatas {
            metadatas.section = NSLocalizedString("_in_this_folder_", comment: "")
        }

        self.dataSource = NCCollectionViewDataSource(
            metadatas: metadatas,
            layoutForView: layoutForView,
            isSections: true,
            searchResults: [],
            account: session.account
        )
        self.collectionView.reloadData()

        // ---> Get providers
        let results = await NextcloudKit.shared.unifiedSearchProviders(account: session.account, handle: searchOperationHandle) { _ in
            // example filter
            // ["calendar", "files", "fulltextsearch"].contains(provider.id)
            return true
        }

        if results.error != .success {
            await showErrorBanner(controller: self.controller,
                                  text: results.error.errorDescription,
                                  errorCode: results.error.errorCode,
                                  afError: results.error.error as? AFError)
        }

        guard isSearchingMode,
              results.error == .success,
              var providers = results.providers else {
            return
        }

        // Added providers in DataSource
        self.dataSource.setProviders(providers)
        // "files" first position
        if let index = providers.firstIndex(where: { $0.id == NCGlobal.shared.appName }) {
            let files = providers.remove(at: index)
            providers.insert(files, at: 0)
        }

        // ---> Get metadatas for providers
        for provider in providers {
            let results = await NextcloudKit.shared.unifiedSearch(
                providerId: provider.id,
                term: text,
                limit: 5,
                cursor: 0,
                timeout: 90,
                account: session.account,
                handle: searchOperationHandle
            )

            if results.error != .success {
                await showErrorBanner(controller: self.controller,
                                      text: results.error.errorDescription,
                                      errorCode: results.error.errorCode,
                                      afError: results.error.error as? AFError)
            }

            guard isSearchingMode,
                  self.searchResultText == text,
                  results.error == .success,
                  let searchResult = results.searchResult else {
                return
            }

            if let metadatas = await getSearchResultMetadatas(
                session: session,
                provider: provider,
                searchResult: searchResult
            ) {
                self.dataSource.addSection(metadatas: metadatas, searchResult: searchResult)
                self.collectionView.reloadData()
            }
        }
    }

    func unifiedSearchMore(metadataForSection: NCMetadataForSection?) async {
        defer {
            metadataForSection?.unifiedSearchInProgress = false
            Task {
                if !isSearchingMode {
                    await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                        delegate.transferReloadDataSource(serverUrl: self.serverUrl, requestData: true, status: nil)
                    }
                }
            }
        }

        guard let metadataForSection = metadataForSection,
              let lastSearchResult = metadataForSection.lastSearchResult,
              let cursor = lastSearchResult.cursor,
              let searchResultStore else {
            return
        }

        metadataForSection.unifiedSearchInProgress = true
        self.collectionView.reloadData()

        let results = await NextcloudKit.shared.unifiedSearch(
            providerId: lastSearchResult.id,
            term: searchResultStore,
            limit: 5,
            cursor: cursor,
            timeout: 60,
            account: session.account,
            handle: searchOperationHandle
        )

        if results.error != .success {
            await showErrorBanner(controller: self.controller,
                                  text: results.error.errorDescription,
                                  errorCode: results.error.errorCode,
                                  afError: results.error.error as? AFError)
        }

        guard isSearchingMode,
              results.error == .success,
              let searchResult = results.searchResult,
                let provider = self.dataSource.getProvider(id: searchResult.id) else {
            return
        }

        if let metadatas = await getSearchResultMetadatas(
            session: session,
            provider: provider,
            searchResult: searchResult
        ) {
            self.dataSource.appendMetadatasToSection(metadatas, metadataForSection: metadataForSection, lastSearchResult: searchResult)
            self.collectionView.reloadData()
        }
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
                if let fileId = utilityFileSystem.extractFileIdFromFPath(from: entry.resourceURL),
                   let metadata = database.getMetadataFromFileId(fileId) {
                    metadata.section = provider.name
                    metadatas.append(metadata)
                } else {
                    if let filePath = entry.filePath {
                        if let metadata = await loadMetadata(session: session,
                                                             provider: provider,
                                                             filePath: filePath) {
                            metadatas.append(metadata)
                        }
                    } else {
                        print(#function, "[ERROR]: File search entry has no path: \(entry)")
                    }
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
                    if let metadata = await loadMetadata(session: session,
                                                         provider: provider,
                                                         filePath: dir + filename) {
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
                    sceneIdentifier: nil
                )
                metadata.hasPreview = false
                metadata.section = provider.name
                metadatas.append(metadata)
            }
            return(metadatas)

        }
    }

    private func loadMetadata(session: NCSession.Session,
                              provider: NKSearchProvider,
                              filePath: String) async -> tableMetadata? {
        let urlPath = session.urlBase + "/remote.php/dav/files/" + session.user + filePath
        let results = await NCNetworking.shared.readFileAsync(serverUrlFileName: urlPath,
                                                              account: session.account
        )
        guard let metadata = results.metadata else {
            return nil
        }
        metadata.section = provider.name

        NCManageDatabase.shared.addMetadata(metadata)
        return metadata
    }
}

