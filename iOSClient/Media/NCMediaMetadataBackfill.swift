// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import RealmSwift

final class NCMediaMetadataBackfill {
    private let account: String

    init(account: String) {
        self.account = account
    }

    /// Processes one media archive page and adds placeholders for metadata
    /// available on the server but missing from the local database.
    func run(mediaPath: String,
             account: String,
             offset: Int,
             token: String? = nil,
             count: Int) async -> (files: [NKFile]?, token: String?, paginate: Bool, error: NKError?) {

        let result = await searchMediaPage(path: mediaPath,
                                           account: account,
                                           offset: offset,
                                           token: token,
                                           count: count)

        guard !Task.isCancelled else {
            return (nil, nil, false, NKError(errorCode: NCGlobal.shared.errorTaskCancelled, errorDescription: "Task cancelled for account: \(account)"))
        }

        return result
    }

    private func searchMediaPage(path: String,
                                 account: String,
                                 offset: Int,
                                 token: String? = nil,
                                 count: Int) async -> (files: [NKFile]?, token: String?, paginate: Bool, error: NKError) {
        guard let nkSession = NextcloudKit.shared.nkCommonInstance.nksessions.session(forAccount: account) else {
            return (nil, nil, false, NKError(errorCode: NCGlobal.shared.errorNCSessionNotFound, errorDescription: "Session not found for account: \(account)"))
        }
        let nkComm = NextcloudKit.shared.nkCommonInstance
        let href = "/files/" + nkSession.userId + path

        let elementDate = "d:" + NCGlobal.shared.mediaPropOrder
        let lessDateString = Date.distantFuture.formatted(using: "yyyy-MM-dd'T'HH:mm:ssZZZZZ")
        let greaterDateString = Date.distantPast.formatted(using: "yyyy-MM-dd'T'HH:mm:ssZZZZZ")
        let httpBodyString = String(format: NCMediaNetwork().getRequestBodySearchMedia(
            href: href,
            elementDate: elementDate,
            lessDate: lessDateString,
            greaterDate: greaterDateString,
            limit: String(1000000))
        )

        guard let httpBody = httpBodyString.data(using: .utf8) else {
            return (nil, nil, false, NKError(errorCode: NCGlobal.shared.errorPreconditionFailed, errorDescription: "Body error for account: \(account)"))
        }

        let options = NKRequestOptions(timeout: 240,
                                       taskDescription: NCGlobal.shared.taskDescriptionRetrievesProperties,
                                       paginate: true,
                                       paginateToken: token,
                                       paginateOffset: offset,
                                       paginateCount: count)

        let results = await NextcloudKit.shared.searchAsync(serverUrl: nkSession.urlBase, httpBody: httpBody, showHiddenFiles: false, includeHiddenFiles: [], account: account, options: options)
        if results.error == .success, let files = results.files {
            let allHeaderFields = results.responseData?.response?.allHeaderFields
            var token: String?
            if let result = nkComm.findHeader("x-nc-paginate-token", allHeaderFields: allHeaderFields) {
                token = result
            }
            var paginate: Bool = false
            if let result = nkComm.findHeader("x-nc-paginate", allHeaderFields: allHeaderFields) {
                paginate = Bool(result) ?? false
            }
            return (files, token, paginate, results.error)
        } else {
            return (nil, nil, false, results.error)
        }
    }
}
