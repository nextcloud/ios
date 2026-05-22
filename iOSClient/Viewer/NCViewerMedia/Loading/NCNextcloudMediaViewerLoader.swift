// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

// MARK: - Media Viewer Loader
final class NCMediaViewerLoader: NCMediaViewerLoading, @unchecked Sendable {
    private let database = NCManageDatabase.shared
    private let global = NCGlobal.shared
    private let utilityFileSystem = NCUtilityFileSystem()
    private let fileManager = FileManager.default

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

    func previewURL(for metadata: tableMetadata, index: Int) async -> URL? {
        let localPath = previewLocalPath(for: metadata)

        if isValidLocalFile(path: localPath) {
            nkLog(tag: NCGlobal.shared.logTagViewer, emoji: .debug, message: "PREVIEW local \(index)", consoleOnly: true)
            return URL(fileURLWithPath: localPath)
        }

        nkLog(tag: NCGlobal.shared.logTagViewer, emoji: .debug, message: "PREVIEW request \(index)", consoleOnly: true)

        let result = await NextcloudKit.shared.downloadPreviewAsync(
            fileId: metadata.fileId,
            etag: metadata.etag,
            account: metadata.account
        )

        if result.error == .success,
           let data = result.responseData?.data {
            NCUtility().createImageFileFrom(
                data: data,
                metadata: metadata
            )
        }

        guard isValidLocalFile(path: localPath) else {
            nkLog(tag: NCGlobal.shared.logTagViewer, emoji: .debug, message: "PREVIEW failed \(index)", consoleOnly: true)
            return nil
        }

        nkLog(tag: NCGlobal.shared.logTagViewer, emoji: .debug, message: "PREVIEW ready \(index)", consoleOnly: true)

        return URL(fileURLWithPath: localPath)
    }

    func localMediaURL(for metadata: tableMetadata, index: Int) async -> URL? {
        let localPath = fullLocalPath(for: metadata)

        guard isValidLocalFile(path: localPath) else {
            return nil
        }

        nkLog(tag: NCGlobal.shared.logTagViewer, emoji: .debug, message: "FULL local \(index)", consoleOnly: true)

        return URL(fileURLWithPath: localPath)
    }

    func downloadMedia(for metadata: tableMetadata, index: Int) async throws -> URL {
        if let localURL = await localMediaURL(for: metadata, index: index) {
            nkLog(tag: NCGlobal.shared.logTagViewer, emoji: .debug, message: "FULL resolve \(index)", consoleOnly: true)
            return localURL
        }

        nkLog(tag: NCGlobal.shared.logTagViewer, emoji: .debug, message: "FULL network request \(index)", consoleOnly: true)

        guard let metadata = await self.database.setMetadataSessionInWaitDownloadAsync(
            ocId: metadata.ocId,
            session: NCNetworking.shared.sessionDownload,
            selector: NCGlobal.shared.selectorDownloadFile) else {
                nkLog(tag: NCGlobal.shared.logTagViewer, emoji: .debug, message: "FULL error \(index)", consoleOnly: true)
                throw NSError(domain: "Download Media", code: 1, userInfo: [NSLocalizedDescriptionKey: "FULL error \(index)"])
        }

        let result = await NCNetworking.shared.downloadFile(metadata: metadata)

        if let afError = result.afError {
            nkLog(tag: NCGlobal.shared.logTagViewer, emoji: .debug, message: "FULL error \(index)", consoleOnly: true)
            throw afError
        }

        if result.nkError != .success {
            nkLog(tag: NCGlobal.shared.logTagViewer, emoji: .debug, message: "FULL error \(index)", consoleOnly: true)
            throw result.nkError
        }

        if let localURL = await localMediaURL(for: metadata, index: index) {
            nkLog(tag: NCGlobal.shared.logTagViewer, emoji: .debug, message: "FULL ready \(index)", consoleOnly: true)
            return localURL
        }

        nkLog(tag: NCGlobal.shared.logTagViewer, emoji: .debug, message: "FULL unavailable after download \(index)", consoleOnly: true)

        throw NCMediaViewerLoaderError.localFileUnavailable
    }

    func localLivePhotoURL(for metadata: tableMetadata, index: Int) async -> URL? {
        guard metadata.isLivePhoto else {
            return nil
        }

        guard let livePhotoMetadata = database.getMetadataLivePhoto(metadata: metadata) else {
            nkLog(tag: NCGlobal.shared.logTagViewer, emoji: .debug, message: "LIVE metadata missing \(index)", consoleOnly: true)
            return nil
        }

        let localPath = fullLocalPath(for: livePhotoMetadata)

        guard isValidLocalFile(path: localPath) else {
            return nil
        }

        nkLog(tag: NCGlobal.shared.logTagViewer, emoji: .debug, message: "LIVE local \(index)", consoleOnly: true)

        return URL(fileURLWithPath: localPath)
    }

    // Live Photo fallback is optional; the image viewer can continue without it.
    func downloadLivePhotoMedia(for metadata: tableMetadata, index: Int) async -> URL? {
        guard metadata.isLivePhoto else {
            return nil
        }

        if let localURL = await localLivePhotoURL(for: metadata, index: index) {
            nkLog(tag: NCGlobal.shared.logTagViewer, emoji: .debug, message: "LIVE resolve \(index)", consoleOnly: true)
            return localURL
        }

        guard NCNetworking.shared.isOnline else {
            nkLog(tag: NCGlobal.shared.logTagViewer, emoji: .debug, message: "LIVE offline \(index)", consoleOnly: true)
            return nil
        }

        guard let livePhotoMetadata = database.getMetadataLivePhoto(metadata: metadata) else {
            nkLog(tag: NCGlobal.shared.logTagViewer, emoji: .debug, message: "LIVE metadata missing \(index)", consoleOnly: true)
            return nil
        }

        guard !utilityFileSystem.fileProviderStorageExists(livePhotoMetadata) else {
            return await localLivePhotoURL(for: metadata, index: index)
        }

        nkLog(tag: NCGlobal.shared.logTagViewer, emoji: .debug, message: "LIVE network request \(index)", consoleOnly: true)

        guard let downloadMetadata = await database.setMetadataSessionInWaitDownloadAsync(
            ocId: livePhotoMetadata.ocId,
            session: NCNetworking.shared.sessionDownload,
            selector: ""
        ) else {
            nkLog(tag: NCGlobal.shared.logTagViewer, emoji: .debug, message: "LIVE session error \(index)", consoleOnly: true)
            return nil
        }

        let result = await NCNetworking.shared.downloadFile(metadata: downloadMetadata)

        if result.afError != nil || result.nkError != .success {
            nkLog(tag: NCGlobal.shared.logTagViewer, emoji: .debug, message: "LIVE error \(index)", consoleOnly: true)
            return nil
        }

        if let localURL = await localLivePhotoURL(for: metadata, index: index) {
            nkLog(tag: NCGlobal.shared.logTagViewer, emoji: .debug, message: "LIVE ready \(index)", consoleOnly: true)
            return localURL
        }

        nkLog(tag: NCGlobal.shared.logTagViewer, emoji: .debug, message: "LIVE unavailable after download \(index)", consoleOnly: true)

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

    private func previewLocalPath(for metadata: tableMetadata) -> String {
        utilityFileSystem.getDirectoryProviderStorageImageOcId(
            metadata.ocId,
            etag: metadata.etag,
            ext: global.previewExt1024,
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

enum NCMediaViewerLoaderError: LocalizedError {
    case localFileUnavailable

    var errorDescription: String? {
        switch self {
        case .localFileUnavailable:
            return "The local file is not available."
        }
    }
}

protocol NCMediaViewerLoading: Sendable {
    func metadata(for ocId: String, account: String, mediaSearch: Bool) async -> tableMetadata?

    func localMediaURL(for metadata: tableMetadata, index: Int) async -> URL?

    func previewURL(for metadata: tableMetadata, index: Int) async -> URL?

    func downloadMedia(for metadata: tableMetadata, index: Int) async throws -> URL

    func localLivePhotoURL(for metadata: tableMetadata, index: Int) async -> URL?

    func downloadLivePhotoMedia(for metadata: tableMetadata, index: Int) async -> URL?
}
