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

        let backfill = NCMediaMetadataBackfill(account: account.account)

        while !Task.isCancelled {
            let result = await backfill.run(
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
}

