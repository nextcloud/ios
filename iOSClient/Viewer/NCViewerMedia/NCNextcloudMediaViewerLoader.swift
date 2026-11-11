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

/// Runs at most one operation per key at a time. A caller that asks for a key
/// while its operation is still running awaits that same operation instead of
/// starting a second one. The shared operation is cancelled only when every
/// caller waiting on it has been cancelled, or when it is cancelled by key.
actor NCInFlightTaskRegistry<Key: Hashable & Sendable, Value: Sendable> {
    private struct Entry {
        let id: UUID
        let task: Task<Value, Error>
        var consumers: Int
    }

    private var entries: [Key: Entry] = [:]
    /// How many callers joined an operation that was already running.
    private(set) var joinedCount = 0

    func value(for key: Key, operation: @escaping @Sendable () async throws -> Value) async throws -> Value {
        let id: UUID
        let task: Task<Value, Error>

        if var running = entries[key] {
            joinedCount += 1
            running.consumers += 1
            entries[key] = running
            id = running.id
            task = running.task
        } else {
            id = UUID()
            task = Task { try await operation() }
            entries[key] = Entry(id: id, task: task, consumers: 1)
        }

        defer {
            if entries[key]?.id == id {
                entries[key] = nil
            }
        }

        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            Task {
                await self.consumerCancelled(for: key, id: id)
            }
        }
    }

    /// Cancels the operation running for the key, whoever is waiting on it.
    func cancel(for key: Key) {
        entries.removeValue(forKey: key)?.task.cancel()
    }

    /// Cancels every running operation.
    func cancelAll() {
        let running = entries.values
        entries.removeAll()

        running.forEach { $0.task.cancel() }
    }

    /// A waiting caller was cancelled: drop it, and cancel the shared
    /// operation once no other caller is waiting on it.
    private func consumerCancelled(for key: Key, id: UUID) {
        guard var entry = entries[key], entry.id == id else {
            return
        }

        entry.consumers -= 1

        if entry.consumers <= 0 {
            entries[key] = nil
            entry.task.cancel()
        } else {
            entries[key] = entry
        }
    }
}

// MARK: - Media Viewer Loader
final class NCMediaViewerLoader: NCMediaViewerLoading, @unchecked Sendable {
    private let database = NCManageDatabase.shared
    private let utilityFileSystem = NCUtilityFileSystem()
    private let fileManager = FileManager.default
    private let downloadTaskRegistry = NCMediaViewerDownloadTaskRegistry()
    private let inFlightDownloads = NCInFlightTaskRegistry<String, URL>()

    // MARK: - NCMediaViewerLoading
    func metadata(for ocId: String, account: String) async -> tableMetadata? {
        if let metadata = await database.getMetadataFromOcIdAsync(ocId) {
            return metadata
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

        return metadata
    }

    func previewURL(for metadata: tableMetadata, ext: String) async -> URL? {
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
            NCUtility().createImageFileFrom(data: data, metadata: metadata)
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

    func downloadMedia(for metadata: tableMetadata, onDownloadStarted: (@Sendable () async -> Void)? = nil) async throws -> URL {
        if let localURL = await localMediaURL(for: metadata) {
            return localURL
        }

        await onDownloadStarted?()

        // Info and Edit can ask for the same original while it is downloading.
        // Share the running download so its transfer state is not reset and
        // a second download to the same path is never started.
        return try await inFlightDownloads.value(for: metadata.ocId) { [self] in
            try await self.performMediaDownload(for: metadata)
        }
    }

    private func performMediaDownload(for metadata: tableMetadata) async throws -> URL {
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

        if let localURL = await localMediaURL(for: downloadMetadata) {
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
        await inFlightDownloads.cancel(for: ocId)
        await downloadTaskRegistry.cancelTask(for: ocId)
    }

    func cancelLivePhotoMediaDownload(for metadata: tableMetadata) async {
        guard let livePhotoMetadata = database.getMetadataLivePhoto(metadata: metadata) else {
            return
        }

        await downloadTaskRegistry.cancelTask(for: livePhotoMetadata.ocId)
    }

    func cancelAllDownloads() async {
        await inFlightDownloads.cancelAll()
        await downloadTaskRegistry.cancelAllTasks()
    }

    // MARK: - Private Helpers
    private func fullLocalPath(for metadata: tableMetadata) -> String {
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

protocol NCMediaViewerLoading: Sendable {
    func metadata(for ocId: String, account: String) async -> tableMetadata?

    func localMediaURL(for metadata: tableMetadata) async -> URL?

    func previewURL(for metadata: tableMetadata, ext: String) async -> URL?

    func downloadMedia(for metadata: tableMetadata, onDownloadStarted: (@Sendable () async -> Void)?) async throws -> URL

    func localLivePhotoURL(for metadata: tableMetadata) async -> URL?

    func downloadLivePhotoMedia(for metadata: tableMetadata) async -> URL?

    func cancelDownload(for ocId: String) async

    func cancelLivePhotoMediaDownload(for metadata: tableMetadata) async

    func cancelAllDownloads() async
}
