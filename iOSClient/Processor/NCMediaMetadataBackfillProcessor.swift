// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import os

/// Incrementally scans the remote media archive and creates missing local metadata placeholders.
///
/// The oldest date processed in a bounded result batch is persisted so later executions can resume.
/// Once the archive has been fully processed, subsequent executions are skipped.
final class NCMediaMetadataBackfillProcessor {
    private let pagesPerBatch = 4

    /// Represents the result of a media metadata backfill execution.
    enum BackfillStatus {
        case skippedAlreadyCompleted(account: String)
        case batchCompleted(account: String, processed: Int, inserted: Int, updated: Int, cursorDate: Date)
        case completed(account: String, processed: Int, inserted: Int, updated: Int)
        case failed(account: String, processed: Int, inserted: Int, updated: Int, errorCode: Int, errorDescription: String)
        case cancelled(account: String, processed: Int, inserted: Int, updated: Int)

        /// Returns whether the backfill completed successfully or was already completed.
        var isSuccessful: Bool {
            switch self {
            case .skippedAlreadyCompleted, .batchCompleted, .completed:
                return true
            case .failed, .cancelled:
                return false
            }
        }

        /// Returns a log message describing the backfill result.
        var logMessage: String {
            switch self {
            case .skippedAlreadyCompleted(let account):
                return "Media metadata backfill skipped for account \(account): cycle already completed"

            case .batchCompleted(let account, let processed, let inserted, let updated, let cursorDate):
                return "Media metadata backfill batch completed for account \(account): processed \(processed) - inserted \(inserted) - updated \(updated) - cursor date \(cursorDate)"

            case .completed(let account, let processed, let inserted, let updated):
                return "Media metadata backfill completed for account \(account): processed \(processed) - inserted \(inserted) - updated \(updated)"

            case .failed(let account, let processed, let inserted, let updated, let errorCode, let errorDescription):
                return "Media metadata backfill failed for account \(account): processed \(processed) - inserted \(inserted) - updated \(updated) - error \(errorCode) \(errorDescription)"

            case .cancelled(let account, let processed, let inserted, let updated):
                return "Media metadata backfill cancelled for account \(account): processed \(processed) - inserted \(inserted) - updated \(updated)"
            }
        }
    }

    /// Processes one bounded batch of the remote media archive and creates missing metadata placeholders.
    ///
    /// Each completed page checkpoints its oldest date after placeholder synchronization.
    /// An interrupted page is safely retried because placeholder synchronization is idempotent.
    /// A full batch persists its oldest date so the next execution can continue from that boundary.
    /// A completed cycle starts again after the configured interval.
    func runBackfill(
        account: tableAccount,
        limit: Int,
        update: @escaping (_ offset: Int, _ inserted: Int, _ updated: Int) async -> Void
    ) async -> BackfillStatus {
        let database = NCManageDatabase.shared
        let state = await database.getMediaMetadataBackfillAsync(account: account.account)
        let cycleInterval: TimeInterval = 7 * 24 * 60 * 60 // week
        let previousCursorDate = state?.cursorDate
        let firstDate = previousCursorDate ?? .distantFuture
        let previouslyProcessed = previousCursorDate == nil ? 0 : state?.offset ?? 0
        var pageOffset = 0
        var token: String?
        var processed = 0
        var inserted = 0
        var updated = 0
        var oldestProcessedDate: Date?

        guard limit > 0 else {
            return .failed(
                account: account.account,
                processed: 0,
                inserted: 0,
                updated: 0,
                errorCode: NCGlobal.shared.errorPreconditionFailed,
                errorDescription: "Invalid media metadata backfill page size: \(limit)"
            )
        }

        let searchResultLimit = limit * pagesPerBatch

        if state?.offset == 0,
           state?.cursorDate == nil,
           let lastCompletedCycleDate = state?.lastCompletedCycleDate,
           Date().timeIntervalSince(lastCompletedCycleDate) < cycleInterval {
            return .skippedAlreadyCompleted(account: account.account)
        }

        for _ in 0..<pagesPerBatch {
            guard !Task.isCancelled else {
                return .cancelled(account: account.account, processed: processed, inserted: inserted, updated: updated)
            }

            let result = await runSearch(
                mediaPath: account.mediaPath,
                account: account.account,
                firstDate: firstDate,
                offset: pageOffset,
                token: token,
                count: limit,
                searchResultLimit: searchResultLimit
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

            // Keep hidden files in the raw page count and cursor calculation because
            // Nextcloud applies pagination before NextcloudKit filters them locally.
            let visibleFiles = files.filter { !isHiddenFile($0) }
            let ocIds = visibleFiles.map(\.ocId)
            let metadatas = await database.getMetadatasFromOcIdsAsync(ocIds)

            let resultPlaceholders = await database.syncPlaceholderMetadatasAsync(
                files: visibleFiles,
                metadatas: metadatas
            )

            processed += files.count
            inserted += resultPlaceholders.inserted
            updated += resultPlaceholders.updated
            pageOffset += files.count

            if let pageOldestDate = files.map(\.date).min() {
                oldestProcessedDate = min(oldestProcessedDate ?? pageOldestDate, pageOldestDate)
            }

            if let checkpointDate = oldestProcessedDate,
               previousCursorDate.map({ checkpointDate < $0 }) ?? true {
                await database.updateMediaMetadataBackfillAsync(
                    account: account.account,
                    offset: previouslyProcessed + processed,
                    cursorDate: checkpointDate
                )
            }

            await update(previouslyProcessed + processed,
                         resultPlaceholders.inserted,
                         resultPlaceholders.updated)

            guard !Task.isCancelled else {
                return .cancelled(account: account.account, processed: processed, inserted: inserted, updated: updated)
            }

            if pageOffset >= searchResultLimit {
                break
            }

            if pageOffset < searchResultLimit,
               (!result.paginate || files.count < limit) {
                await database.completeMediaMetadataBackfillAsync(account: account.account)
                return .completed(account: account.account, processed: processed, inserted: inserted, updated: updated)
            }

            token = result.token
        }

        guard let cursorDate = oldestProcessedDate else {
            await database.completeMediaMetadataBackfillAsync(account: account.account)
            return .completed(account: account.account, processed: processed, inserted: inserted, updated: updated)
        }

        if let previousCursorDate,
           cursorDate >= previousCursorDate {
            return .failed(
                account: account.account,
                processed: processed,
                inserted: inserted,
                updated: updated,
                errorCode: NCGlobal.shared.errorPreconditionFailed,
                errorDescription: "Media metadata backfill cursor did not advance beyond \(previousCursorDate)"
            )
        }

        await database.updateMediaMetadataBackfillAsync(
            account: account.account,
            offset: previouslyProcessed + processed,
            cursorDate: cursorDate
        )

        return .batchCompleted(
            account: account.account,
            processed: processed,
            inserted: inserted,
            updated: updated,
            cursorDate: cursorDate
        )
    }

    /// Mirrors NextcloudKit's hidden-path filtering without changing the raw paginated result count.
    private func isHiddenFile(_ file: NKFile) -> Bool {
        let pathComponents = (file.path as NSString).pathComponents + [file.fileName]
        return pathComponents.contains { $0.hasPrefix(".") }
    }

    /// Executes a single paginated media search and handles task cancellation.
    private func runSearch(mediaPath: String,
                           account: String,
                           firstDate: Date,
                           offset: Int,
                           token: String? = nil,
                           count: Int,
                           searchResultLimit: Int) async -> (files: [NKFile]?, token: String?, paginate: Bool, error: NKError?) {
        let result = await fetchMediaPage(path: mediaPath,
                                          account: account,
                                          firstDate: firstDate,
                                          offset: offset,
                                          token: token,
                                          count: count,
                                          searchResultLimit: searchResultLimit)

        guard !Task.isCancelled else {
            return (nil, nil, false, NKError(errorCode: NCGlobal.shared.errorTaskCancelled, errorDescription: "Task cancelled for account: \(account)"))
        }

        return result
    }

    /// Fetches a page of media files from the server using offset and token pagination.
    private func fetchMediaPage(path: String,
                                account: String,
                                firstDate: Date,
                                offset: Int,
                                token: String? = nil,
                                count: Int,
                                searchResultLimit: Int) async -> (files: [NKFile]?, token: String?, paginate: Bool, error: NKError) {
        guard let nkSession = NextcloudKit.shared.nkCommonInstance.nksessions.session(forAccount: account) else {
            return (nil, nil, false, NKError(errorCode: NCGlobal.shared.errorNCSessionNotFound, errorDescription: "Session not found for account: \(account)"))
        }
        let nkComm = NextcloudKit.shared.nkCommonInstance
        let href = "/files/" + nkSession.userId + path

        let elementDate = "d:" + NCGlobal.shared.mediaPropOrder
        let lessDateString = firstDate.formatted(using: "yyyy-MM-dd'T'HH:mm:ssZZZZZ")
        let greaterDateString = Date.distantPast.formatted(using: "yyyy-MM-dd'T'HH:mm:ssZZZZZ")
        let httpBodyString = String(format: NCMediaNetwork().getRequestBodySearchMedia(
            href: href,
            elementDate: elementDate,
            lessDate: lessDateString,
            greaterDate: greaterDateString,
            limit: String(searchResultLimit))
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

        let requestState = OSAllocatedUnfairLock(
            initialState: (task: Optional<URLSessionTask>.none, isCancelled: false)
        )
        let results = await withTaskCancellationHandler {
            await NextcloudKit.shared.searchAsync(
                serverUrl: nkSession.urlBase,
                httpBody: httpBody,
                showHiddenFiles: true,
                includeHiddenFiles: [],
                account: account,
                options: options
            ) { task in
                let shouldCancel = requestState.withLock { state in
                    if state.isCancelled {
                        return true
                    }

                    state.task = task
                    return false
                }

                if shouldCancel {
                    task.cancel()
                }
            }
        } onCancel: {
            let task = requestState.withLock { state in
                state.isCancelled = true
                return state.task
            }
            task?.cancel()
        }

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
