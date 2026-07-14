// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

final class NCMediaMetadataBackgroundProcessor {
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

    enum PlaceholderHydrationStatus {
        case skippedNoPlaceholders(account: String)
        case completed(account: String, total: Int, succeeded: Int, failed: Int)
        case cancelled(account: String, total: Int, succeeded: Int, failed: Int)

        var isSuccessful: Bool {
            switch self {
            case .skippedNoPlaceholders, .completed:
                return true
            case .cancelled:
                return false
            }
        }

        var logMessage: String {
            switch self {
            case .skippedNoPlaceholders(let account):
                return "Media metadata placeholder hydration skipped for account \(account): no placeholders found"

            case .completed(let account, let total, let succeeded, let failed):
                let pending = max(0, total - succeeded - failed)
                return "Media metadata placeholder hydration completed for account \(account): total \(total) - succeeded \(succeeded) - failed \(failed) - pending \(pending)"

            case .cancelled(let account, let total, let succeeded, let failed):
                let pending = max(0, total - succeeded - failed)
                return "Media metadata placeholder hydration cancelled for account \(account): total \(total) - succeeded \(succeeded) - failed \(failed) - pending \(pending)"
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

    /// Completes media metadata placeholders by retrieving and storing their full properties.
    func runPlaceholderHydration(
        account: tableAccount,
        limit: Int,
        update: @escaping (_ succeeded: Int) async -> Void
    ) async -> PlaceholderHydrationStatus {
        let database = NCManageDatabase.shared
        let maximumConcurrentRequests = min(8, NCBrandOptions.shared.httpMaximumConnectionsPerHost)

        var succeeded = 0
        var failed = 0

        guard let metadatas = await database.getMetadatasAsync(
            predicate: NSPredicate(
                format: "account == %@ AND placeholder == true",
                account.account
            ),
            sortedByKeyPath: "date",
            ascending: false,
            limit: limit
        ), !metadatas.isEmpty else {
            return .skippedNoPlaceholders(account: account.account)
        }

        let total = metadatas.count

        func hydrate(_ metadata: tableMetadata) async -> Bool {
            guard !Task.isCancelled else {
                return false
            }

            let result = await NextcloudKit.shared.readFileOrFolderAsync(
                serverUrlFileName: metadata.serverUrlFileName,
                depth: "0",
                account: metadata.account
            )

            guard !Task.isCancelled else {
                return false
            }

            switch result.error.errorCode {
            case 0:
                if let file = result.files?.first {
                    let metadata = await NCManageDatabaseCreateMetadata().convertFileToMetadataAsync(file)
                    await database.addMetadataAsync(metadata)
                }
                return true

            case 404:
                await database.deleteMetadataAsync(ocId: metadata.ocId)
                return true

            default:
                return false
            }
        }

        await withTaskGroup(of: Bool.self) { group in
            var iterator = metadatas.makeIterator()

            for _ in 0..<maximumConcurrentRequests {
                guard let metadata = iterator.next() else {
                    break
                }

                group.addTask {
                    await hydrate(metadata)
                }
            }

            while let completed = await group.next() {
                if completed {
                    succeeded += 1
                } else {
                    failed += 1
                }

                guard !Task.isCancelled else {
                    group.cancelAll()
                    continue
                }

                guard let metadata = iterator.next() else {
                    continue
                }

                group.addTask {
                    await hydrate(metadata)
                }
            }
        }

        guard !Task.isCancelled else {
            return .cancelled(account: account.account, total: total, succeeded: succeeded, failed: failed)
        }

        await update(succeeded)

        return .completed(account: account.account, total: total, succeeded: succeeded, failed: failed)
    }
}
