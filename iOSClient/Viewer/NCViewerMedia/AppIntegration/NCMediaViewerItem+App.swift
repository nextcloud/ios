// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Conversion belongs to the Nextcloud app, not to the viewer data model.
extension NCMediaViewerItem {
    init(metadata: tableMetadata) {
        account = metadata.account
        ocId = metadata.ocId
        fileId = metadata.fileId
        etag = metadata.etag
        fileName = metadata.fileName
        fileNameView = metadata.fileNameView
        classFile = metadata.classFile
        url = metadata.url
        urlBase = metadata.urlBase
        userId = metadata.userId
        serverUrl = metadata.serverUrl
        livePhotoFile = metadata.livePhotoFile
        date = metadata.date as Date
        size = metadata.size
        width = metadata.width
        height = metadata.height
        latitude = metadata.latitude
        longitude = metadata.longitude
    }
}
