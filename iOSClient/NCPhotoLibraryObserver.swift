// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Photos
import NextcloudKit

/// Keeps this process registered as a live `PHPhotoLibraryChangeObserver` for
/// the app's entire lifetime, including background execution.
///
/// Without an active observer, `PHAssetCollection`/`PHFetchResult` queries made
/// from a background execution context (a `BGAppRefreshTask`/`BGProcessingTask`
/// handler) can be served a stale, frozen snapshot of the photo library rather
/// than its current state. Confirmed via a field test: an unfiltered baseline
/// count of the Camera Roll collection stayed frozen at 2 assets across more
/// than an hour of background-only execution, then jumped to the true count of
/// 53 the instant the app was foregrounded again — silently hiding 51
/// already-captured photos from every background-triggered auto-upload
/// discovery pass in between (see NCAutoUpload.getCameraRollAssets's diagnostic
/// logging). Registering an observer is the standard way to keep a PhotoKit
/// consumer's view of the library current; this doesn't need to act on the
/// change notifications themselves, only to exist for the app's whole lifetime.
final class NCPhotoLibraryObserver: NSObject, PHPhotoLibraryChangeObserver {
    static let shared = NCPhotoLibraryObserver()

    private override init() {
        super.init()
    }

    func start() {
        PHPhotoLibrary.shared().register(self)
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        // No action needed — this observer exists only to keep PhotoKit's view
        // of the library live for this process. Logged (verbose only: it fires
        // several times per photo) so a field test can directly confirm this
        // runs during background execution, rather than only inferring it from
        // discovery counts.
        nkLog(debug: "Photo library change observed", minimumLogLevel: .verbose)
    }
}
