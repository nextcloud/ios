// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

final class NCMediaPreviewBackfillProcessor {
    enum PreviewBackfillStatus {
        case skippedNoMetadatas(account: String)
        case completed(
            account: String,
            total: Int,
            succeeded: Int,
            failed: Int,
            skipped: Int
        )
        case cancelled(
            account: String,
            total: Int,
            succeeded: Int,
            failed: Int,
            skipped: Int
        )

        var isSuccessful: Bool {
            switch self {
            case .skippedNoMetadatas, .completed:
                return true

            case .cancelled:
                return false
            }
        }

        var logMessage: String {
            switch self {
            case .skippedNoMetadatas(let account):
                return "Media preview backfill skipped for account \(account): no metadata found"

            case .completed(
                let account,
                let total,
                let succeeded,
                let failed,
                let skipped
            ):
                let pending = max(
                    0,
                    total - succeeded - failed - skipped
                )

                return "Media preview backfill completed for account \(account): total \(total) - succeeded \(succeeded) - failed \(failed) - skipped \(skipped) - pending \(pending)"

            case .cancelled(
                let account,
                let total,
                let succeeded,
                let failed,
                let skipped
            ):
                let pending = max(
                    0,
                    total - succeeded - failed - skipped
                )

                return "Media preview backfill cancelled for account \(account): total \(total) - succeeded \(succeeded) - failed \(failed) - skipped \(skipped) - pending \(pending)"
            }
        }
    }

    /// Retrieves missing media previews while skipping previews that previously failed.
    func runPreviewBackfill(
        account: tableAccount,
        metadatas: [tableMetadata],
        update: @escaping (
            _ succeeded: Int,
            _ failed: Int,
            _ skipped: Int
        ) async -> Void
    ) async -> PreviewBackfillStatus {
        let database = NCManageDatabase.shared
        let maximumConcurrentRequests = min(
            8,
            NCBrandOptions.shared.httpMaximumConnectionsPerHost
        )

        guard !metadatas.isEmpty else {
            return .skippedNoMetadatas(
                account: account.account
            )
        }

        let total = metadatas.count

        var succeeded = 0
        var failed = 0
        var skipped = 0

        enum PreviewResult {
            case succeeded
            case failed
            case skipped
            case cancelled
        }

        func process(
            _ metadata: tableMetadata
        ) async -> PreviewResult {
            guard !Task.isCancelled else {
                return .cancelled
            }

            let alreadyFailed = await database
                .isMediaPreviewBackfillFailedAsync(
                    account: metadata.account,
                    ocId: metadata.ocId
                )

            guard !alreadyFailed else {
                return .skipped
            }

            guard !Task.isCancelled else {
                return .cancelled
            }

            let error = await requestPreview(metadata: metadata)

            guard !Task.isCancelled else {
                return .cancelled
            }

            guard error.errorCode == 0 else {
                await database.addMediaPreviewBackfillFailureAsync(
                    account: metadata.account,
                    ocId: metadata.ocId,
                    errorCode: error.errorCode
                )

                return .failed
            }

            return .succeeded
        }

        await withTaskGroup(
            of: PreviewResult.self
        ) { group in
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

                case .skipped:
                    skipped += 1

                case .cancelled:
                    break
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
                failed: failed,
                skipped: skipped
            )
        }

        await update(
            succeeded,
            failed,
            skipped
        )

        return .completed(
            account: account.account,
            total: total,
            succeeded: succeeded,
            failed: failed,
            skipped: skipped
        )
    }

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

        let image = NCUtility().createImageFileFrom(data: data,metadata: metadata, ext: NCGlobal.shared.previewExt1024)

        guard image != nil else {
            return NKError(
                errorCode: NCGlobal.shared.errorInternalError,
                errorDescription: "Unable to create preview image"
            )
        }

        return .success
    }
}
