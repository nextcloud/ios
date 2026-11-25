// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

/// The app-specific calls used by the common media loader.
final class NCMediaViewerAppAdapter: NCMediaViewerServices, @unchecked Sendable {
    private let database = NCManageDatabase.shared
    private let utilityFileSystem = NCUtilityFileSystem()

    // Keep complete app records here for menus, EXIF and existing networking APIs.
    // Only detached copies enter this lock-protected cache; the viewer sees values.
    private let metadataLock = NSLock()
    private var appMetadataByAccount: [String: [String: tableMetadata]] = [:]

    func item(from metadata: tableMetadata) -> NCMediaViewerItem {
        let copy = metadata.detachedCopy()
        metadataLock.withLock {
            appMetadataByAccount[copy.account, default: [:]][copy.ocId] = copy
        }
        return NCMediaViewerItem(metadata: copy)
    }

    func appMetadata(for item: NCMediaViewerItem) -> tableMetadata? {
        metadataLock.withLock {
            appMetadataByAccount[item.account]?[item.ocId]?.detachedCopy()
        }
    }

    func livePhotoMetadata(for item: NCMediaViewerItem) -> NCMediaViewerItem? {
        guard let metadata = appMetadata(for: item),
              let companion = database.getMetadataLivePhoto(metadata: metadata) else { return nil }
        return self.item(from: companion)
    }

    func fileProviderStorageExists(for item: NCMediaViewerItem) -> Bool {
        guard let metadata = appMetadata(for: item) else { return false }
        return utilityFileSystem.fileProviderStorageExists(metadata)
    }

    func videoSubtitleTrack(for item: NCMediaViewerItem) -> Int? {
        database.getVideo(metadata: appMetadata(for: item))?.currentVideoSubTitleIndex
    }

    func videoAudioTrack(for item: NCMediaViewerItem) -> Int? {
        database.getVideo(metadata: appMetadata(for: item))?.currentAudioTrackIndex
    }

    func saveVideoSubtitleTrack(_ index: Int, for item: NCMediaViewerItem) {
        guard let metadata = appMetadata(for: item) else { return }
        database.addVideo(metadata: metadata, currentVideoSubTitleIndex: index)
    }

    func saveVideoAudioTrack(_ index: Int, for item: NCMediaViewerItem) {
        guard let metadata = appMetadata(for: item) else { return }
        database.addVideo(metadata: metadata, currentAudioTrackIndex: index)
    }

    // MARK: - NCMediaViewerLoading
    func metadataForDetails(for metadata: NCMediaViewerItem) async -> NCMediaViewerItem {
        guard let appMetadata = appMetadata(for: metadata) else { return metadata }
        let updatedMetadata = await NCNetworking.shared.updateMetadataPlaceholder(appMetadata)
        return item(from: updatedMetadata)
    }

    @MainActor
    func exif(for metadata: NCMediaViewerItem, completion: @escaping @MainActor @Sendable (NCExifData) -> Void) {
        guard let appMetadata = appMetadata(for: metadata) else {
            completion(NCExifData())
            return
        }
        NCUtility().getExif(metadata: appMetadata) { exif in
            Task { @MainActor in
                completion(exif)
            }
        }
    }

    func metadata(for ocId: String, account: String) async -> NCMediaViewerItem? {
        if let metadata = await database.getMetadataFromOcIdAsync(ocId) {
            return item(from: metadata)
        }

        guard let fileId = NCUtilityFileSystem().extractFileId(from: ocId) else {
            return nil
        }

        let resultsFile = await NextcloudKit.shared.getFileFromFileIdAsync(fileId: fileId, account: account)

        guard resultsFile.error == .success,
              let file = resultsFile.file else {
            return nil
        }

        let metadata = await NCManageDatabaseCreateMetadata().convertFileToMetadataAsync(file)
        await NCManageDatabase.shared.addMetadataAsync(metadata)

        return item(from: metadata)
    }

    func originalPath(for item: NCMediaViewerItem) -> String {
        utilityFileSystem.getDirectoryProviderStorageOcId(item.ocId, fileName: item.fileNameView, userId: item.userId, urlBase: item.urlBase)
    }

    func previewPath(for item: NCMediaViewerItem, ext: String) -> String {
        utilityFileSystem.getDirectoryProviderStorageImageOcId(item.ocId, etag: item.etag, ext: ext, userId: item.userId, urlBase: item.urlBase)
    }

    func storePreview(_ data: Data, for item: NCMediaViewerItem) {
        NCUtility().createImageFileFrom(data: data, ocId: item.ocId, etag: item.etag, userId: item.userId, urlBase: item.urlBase)
    }

    func download(for item: NCMediaViewerItem, isLivePhoto: Bool, taskHandler: @escaping @Sendable (URLSessionTask) -> Void) async throws -> NCMediaViewerItem {
        try Task.checkCancellation()
        if isLivePhoto, !NCNetworking.shared.isOnline { throw URLError(.notConnectedToInternet) }
        guard let metadata = await database.setMetadataSessionInWaitDownloadAsync(
            ocId: item.ocId,
            session: NCNetworking.shared.sessionDownload,
            selector: isLivePhoto ? "" : NCGlobal.shared.selectorDownloadFile
        ) else {
            throw NSError(domain: "Download Media", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to prepare media download."])
        }
        if Task.isCancelled {
            await database.setMetadataSessionAsync(ocId: item.ocId, session: "", sessionTaskIdentifier: 0,
                                                   sessionError: "", selector: "", status: NCGlobal.shared.metadataStatusNormal)
            throw CancellationError()
        }
        let result = await NCNetworking.shared.downloadFile(metadata: metadata, taskHandler: taskHandler)
        guard result.nkError == .success else { throw result.nkError }
        return NCMediaViewerItem(metadata: metadata)
    }

    func releaseOriginalImage(for item: NCMediaViewerItem) async {
        await database.removeViewerOriginalIfNotOfflineAsync(ocId: item.ocId, account: item.account)
    }
}
