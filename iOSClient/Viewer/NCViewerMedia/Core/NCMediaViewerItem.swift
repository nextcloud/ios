// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A value snapshot of the fields used by the media viewer, independent of persistence.
struct NCMediaViewerItem: Sendable, Equatable {
    var account: String = ""
    var ocId: String = ""
    var fileId: String = ""
    var etag: String = ""
    var fileName: String = ""
    var fileNameView: String = ""
    var classFile: String = ""
    var url: String = ""
    var urlBase: String = ""
    var userId: String = ""
    var serverUrl: String = ""
    var livePhotoFile: String = ""
    var date = Date()
    var size: Int64 = 0
    var width: Int = 0
    var height: Int = 0
    var latitude: Double = 0
    var longitude: Double = 0

    var isLivePhoto: Bool { !livePhotoFile.isEmpty }
    var fileExtension: String { (fileNameView as NSString).pathExtension }
}
