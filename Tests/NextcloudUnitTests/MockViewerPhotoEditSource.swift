// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Matt Van Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
@testable import Nextcloud

/// A viewer stand-in for photo editing tests. The download stays pending
/// until the test calls `finishDownload(error:)`, and the shown photo can be
/// changed while it waits. `present(_:)` records each editor it would open.
@MainActor
final class MockViewerPhotoEditSource: NCViewerPhotoEditSource {
    var shownOcId: String?
    var isOnScreen = true
    private(set) var downloadRequests: [String] = []
    private(set) var presentedOcIds: [String] = []
    private var pendingDownloads: [CheckedContinuation<Void, Error>] = []

    init(shownOcId: String?) {
        self.shownOcId = shownOcId
    }

    var hasPendingDownload: Bool {
        !pendingDownloads.isEmpty
    }

    func downloadOriginalForEditing(_ metadata: tableMetadata) async throws {
        downloadRequests.append(metadata.ocId)
        try await withCheckedThrowingContinuation { continuation in
            pendingDownloads.append(continuation)
        }
    }

    func finishDownload(error: Error? = nil) {
        let continuations = pendingDownloads
        pendingDownloads.removeAll()
        for continuation in continuations {
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume()
            }
        }
    }

    /// Records that the editor was opened for this photo.
    func present(_ metadata: tableMetadata) {
        presentedOcIds.append(metadata.ocId)
    }

    func isShowingMedia(ocId: String) -> Bool {
        isOnScreen && shownOcId == ocId
    }
}
