// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

extension NCNetworking {
    func searchFiles(literal: String,
                     account: String,
                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (ocIds: [String]?, error: NKError) {
        let showHiddenFiles = NCPreferences().getShowHiddenFiles(account: account)
        let serverUrl = NCSession.shared.getSession(account: account).urlBase

        let results = await NextcloudKit.shared.searchLiteralAsync(serverUrl: serverUrl,
                                                                   depth: "infinity",
                                                                   literal: literal,
                                                                   showHiddenFiles: showHiddenFiles,
                                                                   account: account) { task in
            taskHandler(task)
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                            path: serverUrl,
                                                                                            name: "searchLiteral")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        if results.error == .success, let files = results.files {
            let (_, metadatas) = await NCManageDatabaseCreateMetadata().convertFilesToMetadatasAsync(files)
            NCManageDatabase.shared.addMetadatas(metadatas)
            let ocIds = metadatas.map { $0.ocId }
            return(ocIds, .success)
        } else {
            return(nil, results.error)
        }
    }

    func unifiedSearchProviders(account: String,
                                taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
    ) async -> (providers: [NKSearchProvider]?, error: NKError) {
        let results = await NextcloudKit.shared.unifiedSearchProviders(account: account) { _ in
            // example filter
            // ["calendar", "files", "fulltextsearch"].contains(provider.id)
            return true
        } taskHandler: { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                            name: "unifiedSearch")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
            taskHandler(task)
        }
        return results
    }

    func unifiedSearch(providerId: String,
                       term: String,
                       limit: Int,
                       cursor: Int,
                       account: String,
                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
    ) async -> (searchResult: NKSearchResult?, metadatas: [tableMetadata]?, error: NKError) {
        let session = NCSession.shared.getSession(account: account)
        let results = await NextcloudKit.shared.unifiedSearch(providerId: providerId,
                                                              term: term,
                                                              limit: limit,
                                                              cursor: cursor,
                                                              timeout: 90,
                                                              account: account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                            name: "searchProvider")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
            taskHandler(task)
        }

        guard let searchResult = results.searchResult else {
            return(nil, nil, results.error)
        }
        let metadatas = await getSearchResultMetadatas(session: session, providerId: providerId, searchResult: searchResult)

        return(searchResult, metadatas, results.error)
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
                    if let metadata = await self.loadMetadata(session: session, filePath: filePath) {
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
                        if let metadata = await self.loadMetadata(session: session, filePath: dir + filename) {
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

    func cancelUnifiedSearchFiles() {
        for request in requestsUnifiedSearch {
            request.cancel()
        }
        requestsUnifiedSearch.removeAll()
    }

    private func loadMetadata(session: NCSession.Session,
                              filePath: String) async -> tableMetadata? {
        let urlPath = session.urlBase + "/remote.php/dav/files/" + session.user + filePath
        let results = await self.readFileAsync(serverUrlFileName: urlPath, account: session.account)
        guard let metadata = results.metadata else {
            return nil
        }

        NCManageDatabase.shared.addMetadata(metadata)
        return metadata
    }
}
