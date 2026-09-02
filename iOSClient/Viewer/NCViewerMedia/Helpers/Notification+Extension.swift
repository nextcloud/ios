// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

extension Notification.Name {
    // Global media viewer playback stop notification.
    // Use only for viewer-wide teardown or destructive state changes.
    // Do not use it for normal video-to-video navigation because it dismisses
    // all active audio/video playback controllers.
    static let ncMediaViewerStopPlayback = Notification.Name("ncMediaViewerStopPlayback")
}
