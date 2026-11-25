// SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct NCMediaViewerLoadingPolicy: Sendable {
    static let standard = NCMediaViewerLoadingPolicy(automaticallyDownloadsOriginalImages: true, automaticallyDownloadsLivePhotoResources: true)

    let automaticallyDownloadsOriginalImages: Bool
    let automaticallyDownloadsLivePhotoResources: Bool
    /// Read on every prefetch. When false (for example on a metered network), neighboring pages keep
    /// their previews and only the selected page downloads its original and Live Photo companion.
    let allowsNeighborOriginalDownloads: @Sendable () -> Bool

    init(automaticallyDownloadsOriginalImages: Bool,
         automaticallyDownloadsLivePhotoResources: Bool,
         allowsNeighborOriginalDownloads: @escaping @Sendable () -> Bool = { true }) {
        self.automaticallyDownloadsOriginalImages = automaticallyDownloadsOriginalImages
        self.automaticallyDownloadsLivePhotoResources = automaticallyDownloadsLivePhotoResources
        self.allowsNeighborOriginalDownloads = allowsNeighborOriginalDownloads
    }

    func shouldDownloadOriginalImage(for metadata: NCMediaViewerItem, hasUsablePreview: Bool) -> Bool {
        if Self.originalRequiredExtensions.contains(metadata.fileExtension.lowercased()) {
            return true
        }

        if !hasUsablePreview {
            return true
        }

        if metadata.isLivePhoto,
           automaticallyDownloadsLivePhotoResources {
            return true
        }

        return automaticallyDownloadsOriginalImages
    }

    func shouldDownloadLivePhotoResources(for metadata: NCMediaViewerItem) -> Bool {
        metadata.isLivePhoto && automaticallyDownloadsLivePhotoResources
    }

    private static let originalRequiredExtensions: Set<String> = [
        "gif",
        "svg"
    ]
}
