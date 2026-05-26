// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

// MARK: - Media Viewer Loader
final class NCMediaViewerLoader: NCMediaViewerLoading, @unchecked Sendable {
    private let database = NCManageDatabase.shared
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
        let localPath = utilityFileSystem.getDirectoryProviderStorageImageOcId(
            metadata.ocId,
            etag: metadata.etag,
            ext: NCGlobal.shared.previewExt1024,
            userId: metadata.userId,
            urlBase: metadata.urlBase
        )

        if isValidLocalFile(path: localPath) {
            return URL(fileURLWithPath: localPath)
        }

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
            return nil
        }

        return URL(fileURLWithPath: localPath)
    }

    func localMediaURL(for metadata: tableMetadata, index: Int) async -> URL? {
        let localPath = fullLocalPath(for: metadata)

        guard isValidLocalFile(path: localPath) else {
            return nil
        }

        return URL(fileURLWithPath: localPath)
    }

    func downloadMedia(for metadata: tableMetadata, index: Int) async throws -> URL {
        if let localURL = await localMediaURL(for: metadata, index: index) {
            return localURL
        }

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
            return localURL
        }

        nkLog(tag: NCGlobal.shared.logTagViewer, emoji: .debug, message: "FULL unavailable after download \(index)", consoleOnly: true)

        throw NSError(domain: "Download Media", code: 2)
    }

    func localLivePhotoURL(for metadata: tableMetadata, index: Int) async -> URL? {
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
    func downloadLivePhotoMedia(for metadata: tableMetadata, index: Int) async -> URL? {
        guard metadata.isLivePhoto else {
            return nil
        }

        if let localURL = await localLivePhotoURL(for: metadata, index: index) {
            return localURL
        }

        guard NCNetworking.shared.isOnline else {
            return nil
        }

        guard let livePhotoMetadata = database.getMetadataLivePhoto(metadata: metadata) else {
            return nil
        }

        guard !utilityFileSystem.fileProviderStorageExists(livePhotoMetadata) else {
            return await localLivePhotoURL(for: metadata, index: index)
        }

        guard let downloadMetadata = await database.setMetadataSessionInWaitDownloadAsync(
            ocId: livePhotoMetadata.ocId,
            session: NCNetworking.shared.sessionDownload,
            selector: ""
        ) else {
            return nil
        }

        let result = await NCNetworking.shared.downloadFile(metadata: downloadMetadata)

        if result.afError != nil || result.nkError != .success {
            return nil
        }

        if let localURL = await localLivePhotoURL(for: metadata, index: index) {
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

    func localMediaURL(for metadata: tableMetadata, index: Int) async -> URL?

    func previewURL(for metadata: tableMetadata, index: Int) async -> URL?

    func downloadMedia(for metadata: tableMetadata, index: Int) async throws -> URL

    func localLivePhotoURL(for metadata: tableMetadata, index: Int) async -> URL?

    func downloadLivePhotoMedia(for metadata: tableMetadata, index: Int) async -> URL?
}
