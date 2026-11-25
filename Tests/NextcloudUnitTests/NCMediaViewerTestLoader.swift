// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
@testable import Nextcloud

/// Controllable media storage; optional temporary files exercise the common loader without a server.
actor NCMediaViewerTestLoader: NCMediaViewerLoading, NCMediaViewerServices {
    let items: [String: NCMediaViewerItem]
    let storageDirectory: URL?
    private(set) var originals = Set<String>()
    private(set) var liveOriginals = Set<String>()
    private(set) var downloadCounts: [String: Int] = [:]
    private var pausedOcIds: Set<String>
    private var pausedReleaseOcIds: Set<String>
    private var pendingReleases: [String: CheckedContinuation<Void, Never>] = [:]
    private let pausedMetadataOcIds: Set<String>
    private var pendingMetadata: [String: CheckedContinuation<NCMediaViewerItem?, Never>] = [:]
    private var pending: [String: CheckedContinuation<URL, Error>] = [:]

    init(items: [NCMediaViewerItem], pausedOcIds: Set<String> = [], pausedMetadataOcIds: Set<String> = [], pausedReleaseOcIds: Set<String> = [], storageDirectory: URL? = nil) {
        self.storageDirectory = storageDirectory
        self.items = Dictionary(uniqueKeysWithValues: items.map { ($0.ocId, $0) })
        self.pausedOcIds = pausedOcIds
        self.pausedReleaseOcIds = pausedReleaseOcIds
        self.pausedMetadataOcIds = pausedMetadataOcIds
    }

    func metadata(for ocId: String, account: String) async -> NCMediaViewerItem? {
        if pausedMetadataOcIds.contains(ocId) {
            return await withCheckedContinuation { pendingMetadata[ocId] = $0 }
        }
        return items[ocId]
    }
    var pendingMetadataOcIds: Set<String> { Set(pendingMetadata.keys) }
    func resumeMetadata(for ocId: String) {
        pendingMetadata.removeValue(forKey: ocId)?.resume(returning: items[ocId])
    }
    func metadataForDetails(for metadata: NCMediaViewerItem) async -> NCMediaViewerItem { metadata }
    func localMediaURL(for metadata: NCMediaViewerItem) async -> URL? {
        originals.contains(metadata.ocId) ? URL(fileURLWithPath: "/original/\(metadata.ocId).jpg") : nil
    }
    func previewURL(for metadata: NCMediaViewerItem, ext: String) async -> URL? {
        URL(fileURLWithPath: "/preview/\(metadata.ocId).jpg")
    }
    func downloadMedia(for metadata: NCMediaViewerItem, onDownloadStarted: (@Sendable () async -> Void)?) async throws -> URL {
        downloadCounts[metadata.ocId, default: 0] += 1
        await onDownloadStarted?()
        if pausedOcIds.contains(metadata.ocId) {
            return try await withCheckedThrowingContinuation { pending[metadata.ocId] = $0 }
        }
        try Task.checkCancellation()
        originals.insert(metadata.ocId)
        return URL(fileURLWithPath: "/original/\(metadata.ocId).jpg")
    }
    var pendingOcIds: Set<String> { Set(pending.keys) }

    func resumeDownload(for ocId: String) {
        pausedOcIds.remove(ocId)
        originals.insert(ocId)
        pending.removeValue(forKey: ocId)?.resume(returning: URL(fileURLWithPath: "/original/\(ocId).jpg"))
    }
    func cancelDownload(for ocId: String) async {
        pending.removeValue(forKey: ocId)?.resume(throwing: CancellationError())
    }
    func cancelAllDownloads() async {
        let continuations = pending.values
        pending.removeAll()
        for continuation in continuations { continuation.resume(throwing: CancellationError()) }
    }
    var pendingReleaseOcIds: Set<String> { Set(pendingReleases.keys) }
    func resumeRelease(for ocId: String) {
        pendingReleases.removeValue(forKey: ocId)?.resume()
    }
    func releaseOriginalImage(for metadata: NCMediaViewerItem) async {
        if pausedReleaseOcIds.remove(metadata.ocId) != nil {
            await withCheckedContinuation { pendingReleases[metadata.ocId] = $0 }
        }
        originals.remove(metadata.ocId)
        liveOriginals.remove(metadata.ocId)
        if storageDirectory != nil { try? FileManager.default.removeItem(atPath: originalPath(for: metadata)) }
    }
    func localLivePhotoURL(for metadata: NCMediaViewerItem) async -> URL? {
        liveOriginals.contains(metadata.ocId) ? URL(fileURLWithPath: "/original/\(metadata.ocId).mov") : nil
    }
    func downloadLivePhotoMedia(for metadata: NCMediaViewerItem) async -> URL? {
        guard !Task.isCancelled else { return nil }
        liveOriginals.insert(metadata.ocId)
        return await localLivePhotoURL(for: metadata)
    }
    func cancelLivePhotoMediaDownload(for metadata: NCMediaViewerItem) async { }
    nonisolated func originalPath(for item: NCMediaViewerItem) -> String {
        (storageDirectory ?? URL(fileURLWithPath: "/original")).appendingPathComponent(item.ocId).path
    }
    nonisolated func previewPath(for item: NCMediaViewerItem, ext: String) -> String {
        originalPath(for: item) + ".preview"
    }
    nonisolated func storePreview(_ data: Data, for item: NCMediaViewerItem) { }
    nonisolated func livePhotoMetadata(for item: NCMediaViewerItem) -> NCMediaViewerItem? {
        items[item.livePhotoFile]
    }
    func download(for item: NCMediaViewerItem, isLivePhoto: Bool, taskHandler: @escaping @Sendable (URLSessionTask) -> Void) async throws -> NCMediaViewerItem {
        _ = try await downloadMedia(for: item, onDownloadStarted: nil)
        guard let storageDirectory else { throw URLError(.unsupportedURL) }
        try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        try Data([1]).write(to: URL(fileURLWithPath: originalPath(for: item)))
        return item
    }
    nonisolated func fileProviderStorageExists(for metadata: NCMediaViewerItem) -> Bool { false }
    nonisolated func videoSubtitleTrack(for metadata: NCMediaViewerItem) -> Int? { nil }
    nonisolated func videoAudioTrack(for metadata: NCMediaViewerItem) -> Int? { nil }
    nonisolated func saveVideoSubtitleTrack(_ index: Int, for metadata: NCMediaViewerItem) { }
    nonisolated func saveVideoAudioTrack(_ index: Int, for metadata: NCMediaViewerItem) { }
    @MainActor
    func exif(for metadata: NCMediaViewerItem, completion: @escaping @MainActor @Sendable (ExifData) -> Void) { completion(ExifData()) }
}
