// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

final class NCMediaMetadataBackfillProcessor {
    enum BackfillStatus {
        case skippedAlreadyCompleted(account: String)
        case completed(account: String, processed: Int, inserted: Int, updated: Int)
        case failed(account: String, processed: Int, inserted: Int, updated: Int, errorCode: Int, errorDescription: String)
        case cancelled(account: String, processed: Int, inserted: Int, updated: Int)

        var isSuccessful: Bool {
            switch self {
            case .skippedAlreadyCompleted, .completed:
                return true
            case .failed, .cancelled:
                return false
            }
        }

        var logMessage: String {
            switch self {
            case .skippedAlreadyCompleted(let account):
                return "Media metadata backfill skipped for account \(account): cycle already completed"

            case .completed(let account, let processed, let inserted, let updated):
                return "Media metadata backfill completed for account \(account): processed \(processed) - inserted \(inserted) - updated \(updated)"

            case .failed(let account, let processed, let inserted, let updated, let errorCode, let errorDescription):
                return "Media metadata backfill failed for account \(account): processed \(processed) - inserted \(inserted) - updated \(updated) - error \(errorCode) \(errorDescription)"

            case .cancelled(let account, let processed, let inserted, let updated):
                return "Media metadata backfill cancelled for account \(account): processed \(processed) - inserted \(inserted) - updated \(updated)"
            }
        }
    }

    /// Progressively scans the media archive and creates missing metadata placeholders.
    func runBackfill(
        account: tableAccount,
        limit: Int,
        update: @escaping (_ offset: Int, _ inserted: Int, _ updated: Int) async -> Void
    ) async -> BackfillStatus {
        let database = NCManageDatabase.shared
        let state = await database.getMediaMetadataBackfillAsync(account: account.account)

        guard state?.lastCompletedCycleDate == nil else {
            return .skippedAlreadyCompleted(account: account.account)
        }

        var offset = state?.offset ?? 0
        var token: String?
        var processed = 0
        var inserted = 0
        var updated = 0

        while !Task.isCancelled {
            let result = await runSearch(
                mediaPath: account.mediaPath,
                account: account.account,
                offset: offset,
                token: token,
                count: limit
            )

            guard !Task.isCancelled else {
                return .cancelled(account: account.account, processed: processed, inserted: inserted, updated: updated)
            }

            guard let files = result.files else {
                let errorCode = result.error?.errorCode ?? 0
                let errorDescription = result.error?.errorDescription ?? ""

                return .failed(
                    account: account.account,
                    processed: processed,
                    inserted: inserted,
                    updated: updated,
                    errorCode: errorCode,
                    errorDescription: errorDescription
                )
            }

            guard !files.isEmpty else {
                await database.completeMediaMetadataBackfillAsync(account: account.account)
                return .completed(account: account.account, processed: processed, inserted: inserted, updated: updated)
            }

            let ocIds = files.compactMap(\.ocId)
            let metadatas = await database.getMetadatasFromOcIdsAsync(ocIds)

            let resultPlaceholders = await database.syncPlaceholderMetadatasAsync(
                files: files,
                metadatas: metadatas
            )

            processed += files.count
            inserted += resultPlaceholders.inserted
            updated += resultPlaceholders.updated
            offset += files.count

            await update(offset, resultPlaceholders.inserted, resultPlaceholders.updated)

            guard !Task.isCancelled else {
                return .cancelled(account: account.account, processed: processed, inserted: inserted, updated: updated)
            }

            await database.updateMediaMetadataBackfillAsync(
                account: account.account,
                offset: offset
            )

            guard files.count == limit else {
                await database.completeMediaMetadataBackfillAsync(account: account.account)
                return .completed(account: account.account, processed: processed, inserted: inserted, updated: updated)
            }

            token = result.token
        }

        return .cancelled(account: account.account, processed: processed, inserted: inserted, updated: updated)
    }

    /// Processes one media archive page and adds placeholders for metadata
    /// available on the server but missing from the local database.
    private func runSearch(mediaPath: String,
                           account: String,
                           offset: Int,
                           token: String? = nil,
                           count: Int) async -> (files: [NKFile]?, token: String?, paginate: Bool, error: NKError?) {
        let result = await fetchMediaPage(path: mediaPath,
                                          account: account,
                                          offset: offset,
                                          token: token,
                                          count: count)

        guard !Task.isCancelled else {
            return (nil, nil, false, NKError(errorCode: NCGlobal.shared.errorTaskCancelled, errorDescription: "Task cancelled for account: \(account)"))
        }

        return result
    }

    private func fetchMediaPage(path: String,
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
