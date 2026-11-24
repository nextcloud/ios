// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

protocol NCMediaViewerLoading: Sendable {
    func metadata(for ocId: String, account: String) async -> NCMediaViewerItem?

    /// Hydrates server placeholders before an explicit request for image details.
    func metadataForDetails(for metadata: NCMediaViewerItem) async -> NCMediaViewerItem

    /// Reads existing metadata and local EXIF without downloading the original.
    @MainActor
    func exif(for metadata: NCMediaViewerItem, completion: @escaping @MainActor @Sendable (ExifData) -> Void)

    func localMediaURL(for metadata: NCMediaViewerItem) async -> URL?

    func previewURL(for metadata: NCMediaViewerItem, ext: String) async -> URL?

    func downloadMedia(for metadata: NCMediaViewerItem, onDownloadStarted: (@Sendable () async -> Void)?) async throws -> URL

    func localLivePhotoURL(for metadata: NCMediaViewerItem) async -> URL?

    func downloadLivePhotoMedia(for metadata: NCMediaViewerItem) async -> URL?

    func cancelDownload(for ocId: String) async

    func cancelLivePhotoMediaDownload(for metadata: NCMediaViewerItem) async

    func cancelAllDownloads() async

    func fileProviderStorageExists(for metadata: NCMediaViewerItem) -> Bool

    func videoSubtitleTrack(for metadata: NCMediaViewerItem) -> Int?
    func videoAudioTrack(for metadata: NCMediaViewerItem) -> Int?
    func saveVideoSubtitleTrack(_ index: Int, for metadata: NCMediaViewerItem)
    func saveVideoAudioTrack(_ index: Int, for metadata: NCMediaViewerItem)
}
