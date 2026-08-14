// SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import UniformTypeIdentifiers

enum NCDocumentEditorSupport {
    static func isFileSupportedByRichdocuments(_ metadata: tableMetadata) -> Bool {
        let fileExtension = (metadata.fileNameView as NSString).pathExtension
        guard let capabilities = NCNetworking.shared.capabilities[metadata.account],
              capabilities.richDocumentsEnabled,
              !fileExtension.isEmpty,
              let mimeType = UTType(
                tag: fileExtension.uppercased(),
                tagClass: .filenameExtension,
                conformingTo: nil
              )?.identifier else {
            return false
        }

        if !metadata.contentType.isEmpty,
           capabilities.richDocumentsMimetypes.contains(where: { $0.contains(metadata.contentType) }) {
            return true
        }

        let mimeTypeComponents = mimeType.components(separatedBy: ".")
        guard !capabilities.richDocumentsMimetypes.isEmpty,
              mimeTypeComponents.count > 2 else {
            return false
        }

        let inferredMimeType = mimeTypeComponents.suffix(2).joined(separator: ".")
        return capabilities.richDocumentsMimetypes.contains { $0.contains(inferredMimeType) }
    }

    static func directEditingEditorIdentifiers(account: String, contentType: String) -> [String] {
        guard let capabilities = NCNetworking.shared.capabilities[account] else {
            return []
        }

        let identifiers = capabilities.directEditingEditors.compactMap { editor -> String? in
            let supportsMimetype = editor.mimetypes.contains(contentType)
            let supportsOptionalMimetype = editor.optionalMimetypes.contains(contentType)
            // HARDCODE: https://github.com/nextcloud/text/issues/913
            let supportsMarkdownAlias = contentType == "text/x-markdown" && editor.mimetypes.contains("text/markdown")
            let supportsHTML = contentType == "text/html" && !editor.mimetypes.isEmpty

            return supportsMimetype || supportsOptionalMimetype || supportsMarkdownAlias || supportsHTML
                ? editor.identifier
                : nil
        }

        return Set(identifiers).sorted()
    }
}
