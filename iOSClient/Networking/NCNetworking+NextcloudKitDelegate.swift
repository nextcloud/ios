// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import Alamofire

extension NCNetworking {

#if !EXTENSION
    func networkReachabilityObserver(_ typeReachability: NKTypeReachability) {
        if typeReachability == NKTypeReachability.reachableCellular || typeReachability == NKTypeReachability.reachableEthernetOrWiFi {
            lastReachability = true
        } else {
            if lastReachability {
                Task {
                    await showBannerActiveScenes(
                        title: NSLocalizedString("_info_", comment: ""),
                        subtitle: NSLocalizedString("_network_not_available_", comment: ""),
                        textColor: .white,
                        image: "wifi.exclamationmark.circle",
                        imageAnimation: .bounce,
                        imageColor: .white,
                        backgroundColor: UIColor.lightGray.withAlphaComponent(0.75)
                    )
                }
            }
            lastReachability = false
        }
        networkReachability = typeReachability
        NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterNetworkReachability, userInfo: nil)
    }
#endif

    // MARK: - Download NextcloudKitDelegate

    func downloadComplete(fileName: String,
                          serverUrl: String,
                          etag: String?,
                          date: Date?,
                          dateLastModified: Date?,
                          length: Int64,
                          task: URLSessionTask,
                          error: NKError) {
        Task {
            await progressQuantizer.clear(serverUrlFileName: serverUrl + "/" + fileName)

#if EXTENSION_FILE_PROVIDER_EXTENSION
            await FileProviderData.shared.downloadComplete(fileName: fileName,
                                                           serverUrl: serverUrl,
                                                           etag: etag,
                                                           date: date,
                                                           dateLastModified: dateLastModified,
                                                           length: length,
                                                           task: task,
                                                           error: error)
#else
            guard let metadata = await NCManageDatabase.shared.getMetadataAsync(predicate: NSPredicate(format: "serverUrl == %@ AND fileName == %@", serverUrl, fileName)) else {
                return
            }
            if error == .success {
                await downloadSuccess(withMetadata: metadata, etag: etag)
            } else {
                await downloadError(withMetadata: metadata, error: error)
            }
#endif
        }
    }

    func downloadingFinish(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        var metadata: tableMetadata?
        if let httpResponse = (downloadTask.response as? HTTPURLResponse) {
            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300,
               let url = downloadTask.currentRequest?.url,
               var serverUrl = url.deletingLastPathComponent().absoluteString.removingPercentEncoding {
                let fileName = url.lastPathComponent
                if serverUrl.hasSuffix("/") { serverUrl = String(serverUrl.dropLast()) }
                metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "serverUrl == %@ AND fileName == %@", serverUrl, fileName))
                if let metadata {
                    let destinationFilePath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileName: metadata.fileName, userId: metadata.userId, urlBase: metadata.urlBase)
                    do {
                        if FileManager.default.fileExists(atPath: destinationFilePath) {
                            try FileManager.default.removeItem(atPath: destinationFilePath)
                        }
                        try FileManager.default.copyItem(at: location, to: NSURL.fileURL(withPath: destinationFilePath))
                    } catch {
                        print(error)
                    }
                }
            }
        }
    }

    func downloadProgress(_ progress: Float,
                          totalBytes: Int64,
                          totalBytesExpected: Int64,
                          fileName: String,
                          serverUrl: String,
                          session: URLSession,
                          task: URLSessionTask) {
        Task {
            guard await progressQuantizer.shouldEmit(serverUrlFileName: serverUrl + "/" + fileName, fraction: Double(progress)) else {
                return
            }

            await self.transferDispatcher.notifyAllDelegates { delegate in
                delegate.transferProgressDidUpdate(progress: progress,
                                                   totalBytes: totalBytes,
                                                   totalBytesExpected: totalBytesExpected,
                                                   fileName: fileName,
                                                   serverUrl: serverUrl)
            }
        }
    }

    // MARK: - Upload NextcloudKitDelegate

    func uploadComplete(fileName: String,
                        serverUrl: String,
                        ocId: String?,
                        etag: String?,
                        date: Date?,
                        size: Int64,
                        task: URLSessionTask,
                        error: NKError) {
        Task {
            await progressQuantizer.clear(serverUrlFileName: serverUrl + "/" + fileName)

#if EXTENSION_FILE_PROVIDER_EXTENSION
                await FileProviderData.shared.uploadComplete(fileName: fileName,
                                                             serverUrl: serverUrl,
                                                             ocId: ocId,
                                                             etag: etag,
                                                             date: date,
                                                             size: size,
                                                             task: task,
                                                             error: error)

#else
            guard let metadata = await NCManageDatabase.shared.getMetadataAsync(predicate: NSPredicate(format: "serverUrl == %@ AND fileName == %@ AND sessionTaskIdentifier == %d", serverUrl, fileName, task.taskIdentifier)) else {
                await NCManageDatabase.shared.deleteMetadataAsync(predicate: NSPredicate(format: "fileName == %@ AND serverUrl == %@", fileName, serverUrl))
                return
            }

            if error == .success {
                if let ocId {
                    if isInBackground() {
                        await self.uploadSuccess(withMetadata: metadata,
                                                 ocId: ocId,
                                                 etag: etag,
                                                 date: date)
                    } else {
#if !EXTENSION
                        await NCManageDatabase.shared.deleteMetadataAsync(ocId: metadata.ocId)
                        await NCNetworking.shared.metadataTranfersSuccess.append(metadata: metadata,
                                                                                 ocId: ocId,
                                                                                 date: date,
                                                                                 etag: etag)
#endif
                    }
                } else {
                    await NCManageDatabase.shared.deleteMetadataAsync(predicate: NSPredicate(format: "fileName == %@ AND serverUrl == %@", fileName, serverUrl))
                }
            } else {
                await uploadError(withMetadata: metadata, error: error)
            }
#endif
        }
    }

    func uploadProgress(_ progress: Float,
                        totalBytes: Int64,
                        totalBytesExpected: Int64,
                        fileName: String,
                        serverUrl: String,
                        session: URLSession,
                        task: URLSessionTask) {
        Task {
            guard await progressQuantizer.shouldEmit(serverUrlFileName: serverUrl + "/" + fileName, fraction: Double(progress)) else {
                return
            }

            await self.transferDispatcher.notifyAllDelegates { delegate in
                delegate.transferProgressDidUpdate(progress: progress,
                                                   totalBytes: totalBytes,
                                                   totalBytesExpected: totalBytesExpected,
                                                   fileName: fileName,
                                                   serverUrl: serverUrl)
            }
        }
    }
}
