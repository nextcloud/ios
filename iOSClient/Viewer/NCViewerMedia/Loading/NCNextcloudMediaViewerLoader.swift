// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

// MARK: - Media Download Limiter
private actor NCMediaDownloadLimiter {
    private var runningDownloads = 0
    private var waitingContinuations: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        guard runningDownloads >= NCBrandOptions.shared.httpMaximumConnectionsPerHostInDownload else {
            runningDownloads += 1
            return
        }

        await withCheckedContinuation { continuation in
            waitingContinuations.append(continuation)
        }
    }

    func release() {
        guard !waitingContinuations.isEmpty else {
            runningDownloads = max(0, runningDownloads - 1)
            return
        }

        let continuation = waitingContinuations.removeFirst()
        continuation.resume()
    }
}

// MARK: - Media Viewer Loader
final class NCMediaViewerLoader: NCMediaViewerLoading, @unchecked Sendable {
    private let database = NCManageDatabase.shared
    private let utilityFileSystem = NCUtilityFileSystem()
    private let fileManager = FileManager.default
    private let mediaDownloadLimiter = NCMediaDownloadLimiter()

    // MARK: - NCMediaViewerLoading
    func metadata(for ocId: String, account: String, mediaSearch: Bool) async -> tableMetadata? {
        if let metadata = await database.getMetadataFromOcIdAsync(ocId) {
            return metadata
        }

        guard let fileId = NCUtilityFileSystem().extractFileId(from: ocId) else {
            return nil
        }

        let resultsFile = await NextcloudKit.shared.getFileFromFileIdAsync(
            fileId: fileId,
            account: account
        )

        guard resultsFile.error == .success,
              let file = resultsFile.file else {
            return nil
        }

        let metadata = await NCManageDatabaseCreateMetadata().convertFileToMetadataAsync(file, mediaSearch: mediaSearch)
        await NCManageDatabase.shared.addMetadataAsync(metadata)

        return metadata
    }

    func previewURL(for metadata: tableMetadata, ext: String) async -> URL? {
        let localPath = utilityFileSystem.getDirectoryProviderStorageImageOcId(
            metadata.ocId,
            etag: metadata.etag,
            ext: ext,
            userId: metadata.userId,
            urlBase: metadata.urlBase
        )

        if isValidLocalFile(path: localPath) {
            return URL(fileURLWithPath: localPath)
        }

        await mediaDownloadLimiter.acquire()

        let result = await NextcloudKit.shared.downloadPreviewAsync(
            fileId: metadata.fileId,
            etag: metadata.etag,
            account: metadata.account
        )

        await mediaDownloadLimiter.release()

        if result.error == .success,
           let data = result.responseData?.data {
            NCUtility().createImageFileFrom(
                data: data,
                metadata: metadata
            )
        }

        guard isValidLocalFile(path: localPath) else {
            return nil
        }

        return URL(fileURLWithPath: localPath)
    }

    func localMediaURL(for metadata: tableMetadata) async -> URL? {
        let localPath = fullLocalPath(for: metadata)

        guard isValidLocalFile(path: localPath) else {
            return nil
        }

        return URL(fileURLWithPath: localPath)
    }

    func downloadMedia(for metadata: tableMetadata) async throws -> URL {
        if let localURL = await localMediaURL(for: metadata) {
            return localURL
        }

        guard let metadata = await self.database.setMetadataSessionInWaitDownloadAsync(
            ocId: metadata.ocId,
            session: NCNetworking.shared.sessionDownload,
            selector: NCGlobal.shared.selectorDownloadFile) else {
                throw NSError(domain: "Download Media", code: 1, userInfo: [NSLocalizedDescriptionKey: "FULL error"])
        }

        await mediaDownloadLimiter.acquire()

        let result = await NCNetworking.shared.downloadFile(metadata: metadata)

        await mediaDownloadLimiter.release()

        if result.nkError != .success {
            throw result.nkError
        }

        if let localURL = await localMediaURL(for: metadata) {
            return localURL
        }

        throw NSError(domain: "Download Media", code: 2)
    }

    func localLivePhotoURL(for metadata: tableMetadata) async -> URL? {
        guard metadata.isLivePhoto else {
            return nil
        }

        guard let livePhotoMetadata = database.getMetadataLivePhoto(metadata: metadata) else {
            return nil
        }

        let localPath = fullLocalPath(for: livePhotoMetadata)

        guard isValidLocalFile(path: localPath) else {
            return nil
        }

        return URL(fileURLWithPath: localPath)
    }

    // Live Photo fallback is optional; the image viewer can continue without it.
    func downloadLivePhotoMedia(for metadata: tableMetadata) async -> URL? {
        guard metadata.isLivePhoto else {
            return nil
        }

        if let localURL = await localLivePhotoURL(for: metadata) {
            return localURL
        }

        guard NCNetworking.shared.isOnline else {
            return nil
        }

        guard let livePhotoMetadata = database.getMetadataLivePhoto(metadata: metadata) else {
            return nil
        }

        guard !utilityFileSystem.fileProviderStorageExists(livePhotoMetadata) else {
            return await localLivePhotoURL(for: metadata)
        }

        guard let downloadMetadata = await database.setMetadataSessionInWaitDownloadAsync(
            ocId: livePhotoMetadata.ocId,
            session: NCNetworking.shared.sessionDownload,
            selector: ""
        ) else {
            return nil
        }

        await mediaDownloadLimiter.acquire()

        let result = await NCNetworking.shared.downloadFile(metadata: downloadMetadata)

        await mediaDownloadLimiter.release()

        if result.nkError != .success {
            return nil
        }

        if let localURL = await localLivePhotoURL(for: metadata) {
            return localURL
        }

        return nil
    }

    // MARK: - Private Helpers
    private func fullLocalPath(for metadata: tableMetadata) -> String {
        utilityFileSystem.getDirectoryProviderStorageOcId(
            metadata.ocId,
            fileName: metadata.fileNameView,
            userId: metadata.userId,
            urlBase: metadata.urlBase
        )
    }

    private func isValidLocalFile(path: String) -> Bool {
        guard !path.isEmpty else {
            return false
        }

        guard fileManager.fileExists(atPath: path) else {
            return false
        }

        guard let attributes = try? fileManager.attributesOfItem(atPath: path),
              let fileSize = attributes[.size] as? Int64,
              fileSize > 0 else {
            return false
        }

        return true
    }
}

protocol NCMediaViewerLoading: Sendable {
    func metadata(for ocId: String, account: String, mediaSearch: Bool) async -> tableMetadata?

    func localMediaURL(for metadata: tableMetadata) async -> URL?

    func previewURL(for metadata: tableMetadata, ext: String) async -> URL?

    func downloadMedia(for metadata: tableMetadata) async throws -> URL

    func localLivePhotoURL(for metadata: tableMetadata) async -> URL?

    func downloadLivePhotoMedia(for metadata: tableMetadata) async -> URL?
}
