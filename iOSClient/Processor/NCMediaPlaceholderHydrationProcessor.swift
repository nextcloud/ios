// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

final class NCMediaPlaceholderHydrationProcessor {
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
