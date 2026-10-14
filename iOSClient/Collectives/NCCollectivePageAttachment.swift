// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UniformTypeIdentifiers

/// A file attached to a page, stored in the `.attachments.<pageId>` folder next to the page.
struct NCCollectivePageAttachment: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let filesize: Int64
    let mimetype: String
    /// Path relative to the user's root folder, with a leading slash.
    let path: String
    /// The source as referenced in the page's Markdown, e.g. `.attachments.12/My%20image.png`.
    let src: String
    let hasPreview: Bool

    var isImage: Bool {
        mimetype.hasPrefix("image/")
    }

    var contentType: UTType? {
        UTType(mimeType: mimetype) ?? UTType(filenameExtension: (name as NSString).pathExtension)
    }

    var relativePath: String {
        path.hasPrefix("/") ? String(path.dropFirst()) : path
    }
}
