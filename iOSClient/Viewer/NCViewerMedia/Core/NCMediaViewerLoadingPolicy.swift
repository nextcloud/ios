// SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation

struct NCMediaViewerLoadingPolicy: Sendable {
    static let standard = NCMediaViewerLoadingPolicy(
        automaticallyDownloadsOriginalImages: false,
        automaticallyDownloadsLivePhotoResources: false
    )

    let automaticallyDownloadsOriginalImages: Bool
    let automaticallyDownloadsLivePhotoResources: Bool

    func shouldDownloadOriginalImage(
        for metadata: tableMetadata,
        hasUsablePreview: Bool
    ) -> Bool {
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

    func shouldDownloadLivePhotoResources(for metadata: tableMetadata) -> Bool {
        metadata.isLivePhoto && automaticallyDownloadsLivePhotoResources
    }

    private static let originalRequiredExtensions: Set<String> = [
        "gif",
        "svg"
    ]
}
