// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

/// Retrieves and stores missing media previews from the server.
final class NCMediaPreviewBackfillProcessor {

    /// Represents the result of a media preview backfill execution.
    enum PreviewBackfillStatus {
        case skippedNoPreviews(account: String)

        case completed(
            account: String,
            total: Int,
            succeeded: Int,
            failed: Int
        )

        case cancelled(
            account: String,
            total: Int,
            succeeded: Int,
            failed: Int
        )

        /// Returns whether the preview backfill completed successfully or had no work to perform.
        var isSuccessful: Bool {
            switch self {
            case .skippedNoPreviews, .completed:
                return true

            case .cancelled:
                return false
            }
        }

        /// Returns a log message describing the preview backfill result.
        var logMessage: String {
            switch self {
            case .skippedNoPreviews(let account):
                return "Media preview backfill skipped for account \(account): no previews to process"

            case .completed(
                let account,
                let total,
                let succeeded,
                let failed
            ):
                return "Media preview backfill completed for account \(account): total \(total) - succeeded \(succeeded) - failed \(failed)"

            case .cancelled(
                let account,
                let total,
                let succeeded,
                let failed
            ):
                let pending = max(
                    0,
                    total - succeeded - failed
                )

                return "Media preview backfill cancelled for account \(account): total \(total) - succeeded \(succeeded) - failed \(failed) - pending \(pending)"
            }
        }
    }

    /// Processes missing media previews concurrently, skipping previously failed items.
    func runPreviewBackfill(
        account: tableAccount,
        limit: Int,
        update: @escaping (
            _ succeeded: Int,
            _ failed: Int
        ) async -> Void
    ) async -> PreviewBackfillStatus {
        let database = NCManageDatabase.shared
        let utilityFileSystem = NCUtilityFileSystem()
        let maximumConcurrentRequests = min(8, NCBrandOptions.shared.httpMaximumConnectionsPerHost)
        let session = NCSession.Session(account: account.account, urlBase: account.urlBase, user: account.user, userId: account.userId)
        let mediaPredicate = NCImageCache.shared.getMediaPredicate(
            session: session,
            mediaPath: account.mediaPath,
            showOnlyImages: false,
            showOnlyVideos: false)
        guard let metadatasMedia = await database.getMetadatasAsync(predicate: mediaPredicate, sortedByKeyPath: "date", ascending: false) else {
            return .skippedNoPreviews(account: account.account)
        }

        let failedOcIds = await database.getFailedMediaPreviewOcIdsAsync(account: account.account)
        var metadatas: [tableMetadata] = []
        metadatas.reserveCapacity(limit)

        for metadata in metadatasMedia {
            guard !Task.isCancelled else {
                break
            }
            guard !failedOcIds.contains(metadata.ocId) else {
                continue
            }
            let imageExists = utilityFileSystem.fileProviderStorageImageExists(metadata.ocId, etag: metadata.etag, userId: metadata.userId, urlBase: metadata.urlBase)

            guard !imageExists else {
                continue
            }

            metadatas.append(metadata)
            if metadatas.count >= limit {
                break
            }
        }

        guard !metadatas.isEmpty else {
            await database.clearTableAsync(tableMediaPreviewBackfill.self, account: account.account)
            return .skippedNoPreviews(account: account.account)
        }

        let total = metadatas.count

        var succeeded = 0
        var failed = 0

        /// Represents the result of processing a single preview.
        enum PreviewResult {
            case succeeded
            case failed
            case cancelled
        }

        /// Processes a single missing media preview.
        func process(_ metadata: tableMetadata) async -> PreviewResult {
            guard !Task.isCancelled else {
                return .cancelled
            }

            let error = await requestPreview(metadata: metadata)

            guard !Task.isCancelled else {
                return .cancelled
            }

            guard error.errorCode == 0 else {
                await database.addMediaPreviewBackfillFailureAsync(account: metadata.account, ocId: metadata.ocId)
                return .failed
            }

            return .succeeded
        }

        await withTaskGroup(of: PreviewResult.self) { group in
            var iterator = metadatas.makeIterator()

            for _ in 0..<maximumConcurrentRequests {
                guard let metadata = iterator.next() else {
                    break
                }

                group.addTask {
                    await process(metadata)
                }
            }

            while let result = await group.next() {
                switch result {
                case .succeeded:
                    succeeded += 1

                case .failed:
                    failed += 1

                case .cancelled:
                    group.cancelAll()
                    continue
                }

                guard !Task.isCancelled else {
                    group.cancelAll()
                    continue
                }

                guard let metadata = iterator.next() else {
                    continue
                }

                group.addTask {
                    await process(metadata)
                }
            }
        }

        guard !Task.isCancelled else {
            return .cancelled(
                account: account.account,
                total: total,
                succeeded: succeeded,
                failed: failed
            )
        }

        await update(succeeded, failed)

        return .completed(
            account: account.account,
            total: total,
            succeeded: succeeded,
            failed: failed
        )
    }

    /// Downloads and stores a preview for the specified metadata.
    private func requestPreview(metadata: tableMetadata) async -> NKError {
        guard !Task.isCancelled else {
            return NKError(
                errorCode: NSURLErrorCancelled,
                errorDescription: "Cancelled"
            )
        }

        let result = await NextcloudKit.shared.downloadPreviewAsync(
            fileId: metadata.fileId,
            etag: metadata.etag,
            account: metadata.account
        )

        guard !Task.isCancelled else {
            return NKError(
                errorCode: NSURLErrorCancelled,
                errorDescription: "Cancelled"
            )
        }

        guard result.error == .success,
              let data = result.responseData?.data else {
            return result.error
        }

        NCUtility().createImageFileFrom(data: data, metadata: metadata)

        return .success
    }
}
