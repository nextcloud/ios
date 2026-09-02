// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

struct NCVideoURLResolver {
    private let utilityFileSystem = NCUtilityFileSystem()

    func getVideoURL(
        metadata: tableMetadata
    ) async -> (url: URL?, autoplay: Bool, error: NKError) {
        if !metadata.url.isEmpty {
            if metadata.url.hasPrefix("/") {
                return (
                    url: URL(fileURLWithPath: metadata.url),
                    autoplay: true,
                    error: .success
                )
            } else {
                return (
                    url: URL(string: metadata.url),
                    autoplay: true,
                    error: .success
                )
            }
        }

        if utilityFileSystem.fileProviderStorageExists(metadata) {
            let localPath = utilityFileSystem.getDirectoryProviderStorageOcId(
                metadata.ocId,
                fileName: metadata.fileNameView,
                userId: metadata.userId,
                urlBase: metadata.urlBase
            )

            return (
                url: URL(fileURLWithPath: localPath),
                autoplay: true,
                error: .success
            )
        }

        return await getDirectDownloadURL(metadata: metadata)
    }

    private func getDirectDownloadURL(
        metadata: tableMetadata
    ) async -> (url: URL?, autoplay: Bool, error: NKError) {
        await withCheckedContinuation { continuation in
            NextcloudKit.shared.getDirectDownload(
                fileId: metadata.fileId,
                account: metadata.account
            ) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                        account: metadata.account,
                        path: metadata.fileId,
                        name: "getDirectDownload"
                    )

                    await NCNetworking.shared.networkingTasks.track(
                        identifier: identifier,
                        task: task
                    )
                }
            } completion: { _, urlString, _, error in
                guard error == .success,
                      let urlString,
                      let url = URL(string: urlString) else {
                    continuation.resume(
                        returning: (
                            url: nil,
                            autoplay: false,
                            error: error
                        )
                    )
                    return
                }

                continuation.resume(
                    returning: (
                        url: url,
                        autoplay: true,
                        error: error
                    )
                )
            }
        }
    }
}
