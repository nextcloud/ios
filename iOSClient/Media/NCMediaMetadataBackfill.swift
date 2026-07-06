// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import RealmSwift

final class NCMediaMetadataBackfill {
    private let session: NCSession.Session

    init(session: NCSession.Session) {
        self.session = session
    }

    /// Processes one media archive page and adds placeholders for metadata
    /// available on the server but missing from the local database.
    func run(firstDate: Date,
             lastDate: Date,
             mediaPath: String,
             account: String,
             offset: Int,
             token: String? = nil,
             count: Int) async -> (files: [NKFile]?, token: String?) {

        let result = await searchMediaPage(path: mediaPath,
                                           firstDate: firstDate,
                                           lastDate: lastDate,
                                           account: account,
                                           offset: offset,
                                           token: token,
                                           count: count)

        guard session.account == account,
              !Task.isCancelled else {
            return (nil, nil)
        }

        return result
    }
    private func searchMediaPage(path: String,
                                 firstDate: Date,
                                 lastDate: Date,
                                 account: String,
                                 offset: Int,
                                 token: String? = nil,
                                 count: Int) async -> (files: [NKFile]?, token: String?) {
        guard let nkSession = NextcloudKit.shared.nkCommonInstance.nksessions.session(forAccount: account) else {
            return ([], nil)
        }
        let nkComm = NextcloudKit.shared.nkCommonInstance
        let href = "/files/" + nkSession.userId + path

        let elementDate = "d:" + NCGlobal.shared.mediaPropOrder
        let lessDateString = firstDate.formatted(using: "yyyy-MM-dd'T'HH:mm:ssZZZZZ")
        let greaterDateString = lastDate.formatted(using: "yyyy-MM-dd'T'HH:mm:ssZZZZZ")
        let httpBodyString = String(format: NCMediaNetwork().getRequestBodySearchMedia(
            href: href,
            elementDate: elementDate,
            lessDate: lessDateString,
            greaterDate: greaterDateString,
            limit: String(1000000))
        )

        guard let httpBody = httpBodyString.data(using: .utf8) else {
            return (nil, nil)
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
            return (files, token)
        } else {
            return (nil, nil)
        }
    }
}
