// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

extension NCNetworking {
    internal func synchronization(account: String, serverUrl: String, userId: String, urlBase: String, metadatasInDownload: [tableMetadata]?) async {
        let showHiddenFiles = NCPreferences().getShowHiddenFiles(account: account)
        let options = NKRequestOptions(timeout: 300, taskDescription: NCGlobal.shared.taskDescriptionSynchronization, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        nkLog(tag: self.global.logTagSync, emoji: .start, message: "Start read infinite folder: \(serverUrl)")

        let results = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: serverUrl, depth: "infinity", showHiddenFiles: showHiddenFiles, account: account, options: options) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                            path: serverUrl,
                                                                                            name: "readFileOrFolder")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        if results.error == .success, let files = results.files {
            nkLog(tag: self.global.logTagSync, emoji: .success, message: "Read infinite folder: \(serverUrl)")

            for file in files {
                if file.directory {
                    let metadata = await NCManageDatabase.shared.convertFileToMetadataAsync(file)
                    await NCManageDatabase.shared.createDirectory(metadata: metadata)
                } else {
                    if await isFileDifferent(ocId: file.ocId, fileName: file.fileName, etag: file.etag, metadatasInDownload: metadatasInDownload, userId: userId, urlBase: urlBase) {
                        let metadata = await NCManageDatabase.shared.convertFileToMetadataAsync(file)
                        metadata.session = self.sessionDownloadBackground
                        metadata.sessionSelector = NCGlobal.shared.selectorSynchronizationOffline
                        metadata.sessionTaskIdentifier = 0
                        metadata.sessionError = ""
                        metadata.status = NCGlobal.shared.metadataStatusWaitDownload
                        metadata.sessionDate = Date()

                        await NCManageDatabase.shared.addMetadataAsync(metadata)

                        nkLog(tag: self.global.logTagSync, emoji: .start, message: "File download: \(file.serverUrl)/\(file.fileName)")
                    }
                }
            }
        } else {
            nkLog(tag: self.global.logTagSync, emoji: .error, message: "Read infinite folder: \(serverUrl), error: \(results.error.errorCode)")
        }

        nkLog(tag: self.global.logTagSync, emoji: .stop, message: "Stop read infinite folder: \(serverUrl)")
    }

    internal func isFileDifferent(ocId: String,
                                  fileName: String,
                                  etag: String,
                                  metadatasInDownload: [tableMetadata]?,
                                  userId: String,
                                  urlBase: String) async -> Bool {
        let match = metadatasInDownload?.contains { $0.ocId == ocId } ?? false
        if match {
            return false
        }

        guard let localFile = await NCManageDatabase.shared.getTableLocalFileAsync(predicate: NSPredicate(format: "ocId == %@", ocId)) else {
            return true
        }
        let fileNamePath = self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId, fileName: fileName, userId: userId, urlBase: urlBase)
        let size = await self.utilityFileSystem.fileSizeAsync(atPath: fileNamePath)
        let isDifferent = (localFile.etag != etag) || size == 0

        return isDifferent
    }
}
