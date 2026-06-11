// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import ImageIO
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

        if isValidLocalFile(path: localPath, validateAsImage: true) {
            return URL(fileURLWithPath: localPath)
        }

        removeInvalidLocalFileIfNeeded(path: localPath, validateAsImage: true)

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

        guard isValidLocalFile(path: localPath, validateAsImage: true) else {
            removeInvalidLocalFileIfNeeded(path: localPath, validateAsImage: true)
            return nil
        }

        return URL(fileURLWithPath: localPath)
    }

    func localMediaURL(for metadata: tableMetadata) async -> URL? {
        let localPath = fullLocalPath(for: metadata)
        let validateAsImage = metadata.classFile == NKTypeClassFile.image.rawValue

        guard isValidLocalFile(path: localPath, validateAsImage: validateAsImage) else {
            removeInvalidLocalFileIfNeeded(path: localPath, validateAsImage: validateAsImage)
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

        guard isValidLocalFile(path: localPath, validateAsImage: false) else {
            removeInvalidLocalFileIfNeeded(path: localPath, validateAsImage: false)
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

        guard NCNetworking.shared.isOnline,
              let livePhotoMetadata = database.getMetadataLivePhoto(metadata: metadata),
              let downloadMetadata = await database.setMetadataSessionInWaitDownloadAsync(
                ocId: livePhotoMetadata.ocId,
                session: NCNetworking.shared.sessionDownload,
                selector: ""
              ) else {
            return nil
        }

        await mediaDownloadLimiter.acquire()
        let result = await NCNetworking.shared.downloadFile(metadata: downloadMetadata)
        await mediaDownloadLimiter.release()

        guard result.nkError == .success else {
            return nil
        }

        return await localLivePhotoURL(for: metadata)
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

    private func isValidLocalFile(path: String, validateAsImage: Bool) -> Bool {
        guard !path.isEmpty,
              fileManager.fileExists(atPath: path),
              let attributes = try? fileManager.attributesOfItem(atPath: path),
              let fileSize = attributes[.size] as? NSNumber,
              fileSize.int64Value > 0 else {
            return false
        }

        guard validateAsImage else {
            return true
        }

        let url = URL(fileURLWithPath: path)

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0,
              CGImageSourceGetType(source) != nil else {
            return false
        }

        return true
    }

    private func removeInvalidLocalFileIfNeeded(path: String, validateAsImage: Bool) {
        guard !path.isEmpty,
              fileManager.fileExists(atPath: path),
              !isValidLocalFile(path: path, validateAsImage: validateAsImage) else {
            return
        }

        try? fileManager.removeItem(atPath: path)
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
