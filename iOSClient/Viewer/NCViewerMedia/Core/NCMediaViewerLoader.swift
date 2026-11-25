// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import ImageIO
import NextcloudKit

// MARK: - Viewer Loading Contract

protocol NCMediaViewerLoading: Sendable {
    func metadata(for ocId: String, account: String) async -> NCMediaViewerItem?

    /// Hydrates server placeholders before an explicit request for image details.
    func metadataForDetails(for metadata: NCMediaViewerItem) async -> NCMediaViewerItem

    /// Reads existing metadata and local EXIF without downloading the original.
    @MainActor
    func exif(for metadata: NCMediaViewerItem, completion: @escaping @MainActor @Sendable (NCExifData) -> Void)

    func localMediaURL(for metadata: NCMediaViewerItem) async -> URL?

    func previewURL(for metadata: NCMediaViewerItem, ext: String) async -> URL?

    func downloadMedia(for metadata: NCMediaViewerItem, onDownloadStarted: (@Sendable () async -> Void)?) async throws -> URL

    func localLivePhotoURL(for metadata: NCMediaViewerItem) async -> URL?

    func downloadLivePhotoMedia(for metadata: NCMediaViewerItem) async -> URL?

    func cancelDownload(for ocId: String) async

    func cancelLivePhotoMediaDownload(for metadata: NCMediaViewerItem) async

    func cancelAllDownloads() async

    /// Removes image and Live Photo originals, preserving previews and offline files/folders.
    func releaseOriginalImage(for metadata: NCMediaViewerItem) async

    func fileProviderStorageExists(for metadata: NCMediaViewerItem) -> Bool

    func videoSubtitleTrack(for metadata: NCMediaViewerItem) -> Int?
    func videoAudioTrack(for metadata: NCMediaViewerItem) -> Int?
    func saveVideoSubtitleTrack(_ index: Int, for metadata: NCMediaViewerItem)
    func saveVideoAudioTrack(_ index: Int, for metadata: NCMediaViewerItem)
}

// MARK: - Host App Services

/// Operations supplied by the host app; the loader owns the shared media pipeline.
protocol NCMediaViewerServices: Sendable {
    func metadata(for ocId: String, account: String) async -> NCMediaViewerItem?
    func metadataForDetails(for metadata: NCMediaViewerItem) async -> NCMediaViewerItem
    @MainActor
    func exif(for metadata: NCMediaViewerItem, completion: @escaping @MainActor @Sendable (NCExifData) -> Void)
    func livePhotoMetadata(for item: NCMediaViewerItem) -> NCMediaViewerItem?
    func originalPath(for item: NCMediaViewerItem) -> String
    func previewPath(for item: NCMediaViewerItem, ext: String) -> String
    func storePreview(_ data: Data, for item: NCMediaViewerItem)
    func download(for item: NCMediaViewerItem, isLivePhoto: Bool, taskHandler: @escaping @Sendable (URLSessionTask) -> Void) async throws -> NCMediaViewerItem
    func releaseOriginalImage(for item: NCMediaViewerItem) async
    func fileProviderStorageExists(for item: NCMediaViewerItem) -> Bool
    func videoSubtitleTrack(for item: NCMediaViewerItem) -> Int?
    func videoAudioTrack(for item: NCMediaViewerItem) -> Int?
    func saveVideoSubtitleTrack(_ index: Int, for item: NCMediaViewerItem)
    func saveVideoAudioTrack(_ index: Int, for item: NCMediaViewerItem)
}

// MARK: - Media Loader

/// Shared loading, validation and cancellation, independent of the host database.
final class NCMediaViewerLoader: NCMediaViewerLoading, Sendable {
    let services: any NCMediaViewerServices
    private let fileManager = FileManager.default
    private let downloadTaskRegistry = NCMediaViewerDownloadTaskRegistry()

    init(services: any NCMediaViewerServices) {
        self.services = services
    }

    func metadata(for ocId: String, account: String) async -> NCMediaViewerItem? {
        await services.metadata(for: ocId, account: account)
    }

    func metadataForDetails(for metadata: NCMediaViewerItem) async -> NCMediaViewerItem {
        await services.metadataForDetails(for: metadata)
    }

    @MainActor
    func exif(for metadata: NCMediaViewerItem, completion: @escaping @MainActor @Sendable (NCExifData) -> Void) {
        services.exif(for: metadata, completion: completion)
    }

    func fileProviderStorageExists(for item: NCMediaViewerItem) -> Bool {
        services.fileProviderStorageExists(for: item)
    }

    func videoSubtitleTrack(for item: NCMediaViewerItem) -> Int? { services.videoSubtitleTrack(for: item) }
    func videoAudioTrack(for item: NCMediaViewerItem) -> Int? { services.videoAudioTrack(for: item) }
    func saveVideoSubtitleTrack(_ index: Int, for item: NCMediaViewerItem) { services.saveVideoSubtitleTrack(index, for: item) }
    func saveVideoAudioTrack(_ index: Int, for item: NCMediaViewerItem) { services.saveVideoAudioTrack(index, for: item) }

    func previewURL(for metadata: NCMediaViewerItem, ext: String) async -> URL? {
        let localPath = services.previewPath(for: metadata, ext: ext)

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
            services.storePreview(data, for: metadata)
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
        try await downloadOriginal(for: metadata, isLivePhoto: false, onDownloadStarted: onDownloadStarted)
    }

    private func downloadOriginal(for metadata: NCMediaViewerItem, isLivePhoto: Bool, onDownloadStarted: (@Sendable () async -> Void)? = nil) async throws -> URL {
        if let localURL = await localMediaURL(for: metadata) { return localURL }
        try Task.checkCancellation()
        await downloadTaskRegistry.beginDownload(for: metadata.ocId)
        await onDownloadStarted?()
        try await NCTransferCoordinator.shared.acquire(priority: isLivePhoto ? .visible : .userInitiated)
        defer { Task { await NCTransferCoordinator.shared.release() } }
        try Task.checkCancellation()
        do {
            let downloaded = try await services.download(for: metadata, isLivePhoto: isLivePhoto) { [downloadTaskRegistry] task in
                Task { await downloadTaskRegistry.setTask(task, for: metadata.ocId) }
            }
            await downloadTaskRegistry.removeTask(for: metadata.ocId)
            if let url = await localMediaURL(for: downloaded) { return url }
            throw NSError(domain: "Download Media", code: 2)
        } catch {
            await downloadTaskRegistry.removeTask(for: metadata.ocId)
            throw error
        }
    }

    func localLivePhotoURL(for metadata: NCMediaViewerItem) async -> URL? {
        guard metadata.isLivePhoto, let companion = services.livePhotoMetadata(for: metadata) else { return nil }
        return await localMediaURL(for: companion)
    }

    func downloadLivePhotoMedia(for metadata: NCMediaViewerItem) async -> URL? {
        guard metadata.isLivePhoto, let companion = services.livePhotoMetadata(for: metadata) else { return nil }
        return try? await downloadOriginal(for: companion, isLivePhoto: true)
    }

    func cancelDownload(for ocId: String) async {
        await downloadTaskRegistry.cancelTask(for: ocId)
    }

    func cancelLivePhotoMediaDownload(for metadata: NCMediaViewerItem) async {
        guard let companion = services.livePhotoMetadata(for: metadata) else { return }
        await downloadTaskRegistry.cancelTask(for: companion.ocId)
    }

    func cancelAllDownloads() async {
        await downloadTaskRegistry.cancelAllTasks()
    }

    func releaseOriginalImage(for metadata: NCMediaViewerItem) async {
        await services.releaseOriginalImage(for: metadata)
        if let companion = services.livePhotoMetadata(for: metadata) {
            await services.releaseOriginalImage(for: companion)
        }
    }

    private func fullLocalPath(for metadata: NCMediaViewerItem) -> String {
        services.originalPath(for: metadata)
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

// MARK: - Download Cancellation

private actor NCMediaViewerDownloadTaskRegistry {
    private var tasks: [String: URLSessionTask] = [:]
    private var isCancelled = false
    private var cancelledOcIds = Set<String>()

    func beginDownload(for ocId: String) {
        cancelledOcIds.remove(ocId)
    }

    func setTask(_ task: URLSessionTask, for ocId: String) {
        guard !isCancelled, !cancelledOcIds.contains(ocId) else {
            task.cancel()
            return
        }

        tasks[ocId] = task
    }

    func removeTask(for ocId: String) {
        tasks.removeValue(forKey: ocId)
    }

    func cancelTask(for ocId: String) {
        cancelledOcIds.insert(ocId)
        tasks.removeValue(forKey: ocId)?.cancel()
    }

    func cancelAllTasks() {
        isCancelled = true

        let currentTasks = tasks.values
        tasks.removeAll()

        currentTasks.forEach { $0.cancel() }
    }
}
