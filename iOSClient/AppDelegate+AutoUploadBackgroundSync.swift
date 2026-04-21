// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import BackgroundTasks

extension AppDelegate {
    // Executes the background synchronization flow for Auto Upload.
    //
    // The function:
    // - discovers new Auto Upload items,
    // - fetches pending metadata,
    // - creates missing folders when required,
    // - checks remote existence,
    // - expands seeds into concrete metadata items,
    // - queues uploads sequentially.
    //
    // The flow cooperates with Swift task cancellation triggered by BGTask expiration.
    func autoUploadBackgroundSync() async {
        guard !Task.isCancelled else { return }

        // Discover new items for Auto Upload.
        let numAutoUpload = await NCAutoUpload.shared.initAutoUpload()
        nkLog(tag: self.global.logTagBgSync, emoji: .start, message: "Auto upload found \(numAutoUpload) new items")

        guard !Task.isCancelled else { return }

        // Fetch pending metadata.
        let metadatas = await NCManageDatabase.shared.getMetadataProcess()
        guard !metadatas.isEmpty, !Task.isCancelled else {
            return
        }

        // Create all pending Auto Upload folders (fail-fast).
        let pendingCreateFolders = metadatas.lazy.filter {
            $0.status == self.global.metadataStatusWaitCreateFolder &&
            $0.sessionSelector == self.global.selectorUploadAutoUpload
        }

        // Resolve capabilities once per account.
        let accounts = Array(Set(pendingCreateFolders.map { $0.account }))
        var capabilitiesByAccount: [String: NKCapabilities.Capabilities] = [:]

        for account in accounts {
            guard !Task.isCancelled else { return }

            let capabilities = await NKCapabilities.shared.getCapabilities(for: account)
            capabilitiesByAccount[account] = capabilities
        }

        for metadata in pendingCreateFolders {
            guard !Task.isCancelled else { return }

            // If server supports auto MKCOL (Nextcloud >= 33), skip manual folder creation.
            if let capabilities = capabilitiesByAccount[metadata.account] {
                let autoMkcol = capabilities.serverVersionMajor >= NCGlobal.shared.nextcloudVersion33
                if autoMkcol {
                    continue
                }
            }

            let err = await NCNetworking.shared.createFolderForAutoUpload(
                serverUrlFileName: metadata.serverUrlFileName,
                account: metadata.account
            )

            if err != .success {
                nkLog(
                    tag: self.global.logTagBgSync,
                    emoji: .error,
                    message: "Create folder '\(metadata.serverUrlFileName)' failed: \(err.errorCode) – aborting sync"
                )
                return
            }
        }

        // Compute available capacity.
        let downloading = metadatas.lazy.filter { $0.status == self.global.metadataStatusDownloading }.count
        let uploading = metadatas.lazy.filter { $0.status == self.global.metadataStatusUploading }.count
        let availableProcess = max(0, NCBrandOptions.shared.numMaximumProcess - (downloading + uploading))

        // Select Auto Upload candidates.
        let metadatasToUpload = Array(
            metadatas.lazy.filter {
                $0.status == self.global.metadataStatusWaitUpload &&
                $0.sessionSelector == self.global.selectorUploadAutoUpload &&
                $0.chunk == 0
            }
            .prefix(availableProcess)
        )

        let cameraRoll = NCCameraRoll()

        for metadata in metadatasToUpload {
            guard !Task.isCancelled else { return }

            // Check whether the file already exists remotely.
            let existsResult = await NCNetworking.shared.fileExists(
                serverUrlFileName: metadata.serverUrlFileName,
                account: metadata.account
            )

            if existsResult == .success {
                await NCManageDatabase.shared.deleteMetadataAsync(id: metadata.ocId)
                continue
            } else if existsResult.errorCode != 404 {
                continue
            }

            // Expand the seed into concrete metadata entries (for example, Live Photo pairs).
            let extractedMetadatas = await cameraRoll.extractCameraRoll(from: metadata)

            guard !Task.isCancelled else { return }

            for extractedMetadata in extractedMetadatas {
                guard !Task.isCancelled else { return }

                let err = await NCNetworking.shared.uploadFileInBackground(
                    metadata: extractedMetadata.detachedCopy()
                )

                if err == .success {
                    nkLog(
                        tag: self.global.logTagBgSync,
                        message: "In queued upload \(extractedMetadata.fileName) -> \(extractedMetadata.serverUrl)"
                    )
                } else {
                    nkLog(
                        tag: self.global.logTagBgSync,
                        emoji: .error,
                        message: "Upload failed \(extractedMetadata.fileName) -> \(extractedMetadata.serverUrl) [\(err.errorDescription)]"
                    )
                }
            }
        }
    }
}
