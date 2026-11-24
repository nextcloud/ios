// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import ImageIO
import NextcloudKit

private actor NCMediaViewerDownloadTaskRegistry {
    private var tasks: [String: URLSessionTask] = [:]
    private var isCancelled = false

    func setTask(_ task: URLSessionTask, for ocId: String) {
        guard !isCancelled else {
            task.cancel()
            return
        }

        tasks[ocId] = task
    }

    func removeTask(for ocId: String) {
        tasks.removeValue(forKey: ocId)
    }

    func cancelTask(for ocId: String) {
        tasks.removeValue(forKey: ocId)?.cancel()
    }

    func cancelAllTasks() {
        isCancelled = true

        let currentTasks = tasks.values
        tasks.removeAll()

        currentTasks.forEach { $0.cancel() }
    }
}

// MARK: - Media Viewer Loader
final class NCMediaViewerLoader: NCMediaViewerLoading, @unchecked Sendable {
    private let database = NCManageDatabase.shared
    private let utilityFileSystem = NCUtilityFileSystem()
    private let fileManager = FileManager.default
    private let downloadTaskRegistry = NCMediaViewerDownloadTaskRegistry()

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

    private func livePhotoMetadata(for item: NCMediaViewerItem) -> tableMetadata? {
        guard let metadata = appMetadata(for: item) else { return nil }
        return database.getMetadataLivePhoto(metadata: metadata)
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
    func exif(for metadata: NCMediaViewerItem, completion: @escaping @MainActor @Sendable (ExifData) -> Void) {
        guard let appMetadata = appMetadata(for: metadata) else {
            completion(ExifData())
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

    func previewURL(for metadata: NCMediaViewerItem, ext: String) async -> URL? {
        let localPath = utilityFileSystem.getDirectoryProviderStorageImageOcId(metadata.ocId, etag: metadata.etag, ext: ext, userId: metadata.userId, urlBase: metadata.urlBase)

        if isValidLocalFile(path: localPath, validateAsImage: true) {
            return URL(fileURLWithPath: localPath)
        }

        removeInvalidLocalFileIfNeeded(path: localPath, validateAsImage: true)

        do {
            try await NCTransferCoordinator.shared.acquire(priority: .visible)
        } catch {
            return nil
        }

        let result = await NextcloudKit.shared.downloadPreviewAsync(fileId: metadata.fileId, etag: metadata.etag, account: metadata.account)

        await NCTransferCoordinator.shared.release()

        if result.error == .success,
           let data = result.responseData?.data {
            NCUtility().createImageFileFrom(data: data, ocId: metadata.ocId, etag: metadata.etag, userId: metadata.userId, urlBase: metadata.urlBase)
        }

        guard isValidLocalFile(path: localPath, validateAsImage: true) else {
            removeInvalidLocalFileIfNeeded(path: localPath, validateAsImage: true)
            return nil
        }

        return URL(fileURLWithPath: localPath)
    }

    func localMediaURL(for metadata: NCMediaViewerItem) async -> URL? {
        let localPath = fullLocalPath(for: metadata)
        let validateAsImage = metadata.classFile == NKTypeClassFile.image.rawValue

        guard isValidLocalFile(path: localPath, validateAsImage: validateAsImage) else {
            removeInvalidLocalFileIfNeeded(path: localPath, validateAsImage: validateAsImage)
            return nil
        }

        return URL(fileURLWithPath: localPath)
    }

    func downloadMedia(for metadata: NCMediaViewerItem, onDownloadStarted: (@Sendable () async -> Void)? = nil) async throws -> URL {
        if let localURL = await localMediaURL(for: metadata) {
            return localURL
        }

        await onDownloadStarted?()

        guard let downloadMetadata = await database.setMetadataSessionInWaitDownloadAsync(
            ocId: metadata.ocId,
            session: NCNetworking.shared.sessionDownload,
            selector: NCGlobal.shared.selectorDownloadFile
        ) else {
            throw NSError(domain: "Download Media", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to prepare media download."])
        }

        try await NCTransferCoordinator.shared.acquire(priority: .userInitiated)
        defer {
            Task {
                await NCTransferCoordinator.shared.release()
            }
        }

        let result = await NCNetworking.shared.downloadFile(
            metadata: downloadMetadata,
            taskHandler: { [downloadTaskRegistry] task in
                Task {
                    await downloadTaskRegistry.setTask(task, for: downloadMetadata.ocId)
                }
            }
        )

        await downloadTaskRegistry.removeTask(for: downloadMetadata.ocId)

        guard result.nkError == .success else {
            throw result.nkError
        }

        if let localURL = await localMediaURL(for: NCMediaViewerItem(metadata: downloadMetadata)) {
            return localURL
        }

        throw NSError(domain: "Download Media", code: 2)
    }

    func localLivePhotoURL(for metadata: NCMediaViewerItem) async -> URL? {
        guard metadata.isLivePhoto else {
            return nil
        }

        guard let livePhotoMetadata = livePhotoMetadata(for: metadata) else {
            return nil
        }

        let localPath = fullLocalPath(for: NCMediaViewerItem(metadata: livePhotoMetadata))

        guard isValidLocalFile(path: localPath, validateAsImage: false) else {
            removeInvalidLocalFileIfNeeded(path: localPath, validateAsImage: false)
            return nil
        }

        return URL(fileURLWithPath: localPath)
    }

    func downloadLivePhotoMedia(for metadata: NCMediaViewerItem) async -> URL? {
        guard metadata.isLivePhoto else {
            return nil
        }

        if let localURL = await localLivePhotoURL(for: metadata) {
            return localURL
        }

        guard NCNetworking.shared.isOnline,
              let livePhotoMetadata = livePhotoMetadata(for: metadata),
              let downloadMetadata = await database.setMetadataSessionInWaitDownloadAsync(
                ocId: livePhotoMetadata.ocId,
                session: NCNetworking.shared.sessionDownload,
                selector: ""
              ) else {
            return nil
        }

        do {
            try await NCTransferCoordinator.shared.acquire(priority: .visible)
        } catch {
            return nil
        }

        defer {
            Task {
                await NCTransferCoordinator.shared.release()
            }
        }

        let result = await NCNetworking.shared.downloadFile(
            metadata: downloadMetadata,
            taskHandler: { [downloadTaskRegistry] task in
                Task {
                    await downloadTaskRegistry.setTask(task, for: downloadMetadata.ocId)
                }
            }
        )

        await downloadTaskRegistry.removeTask(for: downloadMetadata.ocId)

        guard result.nkError == .success else {
            return nil
        }

        return await localLivePhotoURL(for: metadata)
    }

    func cancelDownload(for ocId: String) async {
        await downloadTaskRegistry.cancelTask(for: ocId)
    }

    func cancelLivePhotoMediaDownload(for metadata: NCMediaViewerItem) async {
        guard let livePhotoMetadata = livePhotoMetadata(for: metadata) else {
            return
        }

        await downloadTaskRegistry.cancelTask(for: livePhotoMetadata.ocId)
    }

    func cancelAllDownloads() async {
        await downloadTaskRegistry.cancelAllTasks()
    }

    // MARK: - Private Helpers
    private func fullLocalPath(for metadata: NCMediaViewerItem) -> String {
        utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileName: metadata.fileNameView, userId: metadata.userId, urlBase: metadata.urlBase)
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
