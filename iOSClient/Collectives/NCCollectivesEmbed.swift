// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UniformTypeIdentifiers

/// A file shown inside a page: an attachment, another file in the user's folder or an external image.
struct NCCollectivesEmbed: Hashable, Identifiable, Sendable {
    let alt: String
    let source: String
    let attachment: NCCollectivePageAttachment?
    /// Path relative to the user's root folder for files on the server.
    let relativePath: String?
    let remoteURL: URL?

    var id: String { source }

    var name: String {
        if let attachment { return attachment.name }
        if let relativePath { return (relativePath as NSString).lastPathComponent }
        return remoteURL?.lastPathComponent ?? alt
    }

    var contentType: UTType? {
        attachment?.contentType ?? UTType(filenameExtension: (name as NSString).pathExtension)
    }

    var isImage: Bool {
        contentType?.conforms(to: .image) ?? false
    }

    /// The alt text, unless Text just repeated the file name.
    var caption: String? {
        let caption = alt.trimmingCharacters(in: .whitespaces)
        guard !caption.isEmpty, caption != name, caption != (name as NSString).deletingPathExtension else { return nil }
        return caption
    }

    init(alt: String, source: String, page: NCCollectivePage, attachments: [NCCollectivePageAttachment]) {
        self.alt = alt
        self.source = source
        let decodedSource = source.removingPercentEncoding ?? source
        self.attachment = attachments.first { $0.src == source || $0.src.removingPercentEncoding == decodedSource }
        if let attachment {
            relativePath = attachment.relativePath
            remoteURL = nil
        } else if let url = URL(string: source), url.scheme == "https" || url.scheme == "http" {
            relativePath = nil
            remoteURL = url
        } else {
            relativePath = page.relativePath(forSource: source)
            remoteURL = nil
        }
    }

    init(attachment: NCCollectivePageAttachment) {
        alt = attachment.name
        source = attachment.src
        self.attachment = attachment
        relativePath = attachment.relativePath
        remoteURL = nil
    }
}
