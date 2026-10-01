// SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UniformTypeIdentifiers
import NextcloudKit

enum NCDocumentEditorSupport {
    static func isFileSupportedByRichdocuments(_ metadata: tableMetadata) -> Bool {
        guard let capabilities = NCNetworking.shared.capabilities[metadata.account],
              capabilities.richDocumentsEnabled else {
            return false
        }

        return supportsMimetype(capabilities.richDocumentsMimetypes,
                                contentType: metadata.contentType,
                                fileName: metadata.fileNameView)
    }

    /// Prefer the server MIME type; infer it from the filename only when it is missing or generic.
    static func supportsMimetype(_ supportedTypes: [String], contentType: String, fileName: String) -> Bool {
        let mimeType = normalizedMimetype(contentType)
        let supportedMimetypes = Set(supportedTypes.map(normalizedMimetype))
        if !mimeType.isEmpty, supportedMimetypes.contains(mimeType) {
            return true
        }

        guard mimeType.isEmpty || mimeType == "application/octet-stream" || mimeType == "application/zip" else {
            return false
        }
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        guard let inferredMimetype = UTType(filenameExtension: fileExtension)?.preferredMIMEType else {
            return false
        }

        return supportedMimetypes.contains(normalizedMimetype(inferredMimetype))
    }

    private static func normalizedMimetype(_ value: String) -> String {
        let normalized = value.components(separatedBy: ";")[0]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        // Some metadata sources provide an Apple type identifier instead of a MIME type.
        if !normalized.isEmpty, !normalized.contains("/"),
           let mimeType = UTType(normalized)?.preferredMIMEType {
            return mimeType.lowercased()
        }
        return normalized
    }

    static func directEditingEditorIdentifiers(account: String, contentType: String, fileName: String) -> [String] {
        guard let capabilities = NCNetworking.shared.capabilities[account] else {
            return []
        }

        let identifiers = capabilities.directEditingEditors.compactMap { editor -> String? in
            supportsDirectEditingEditor(editor, contentType: contentType, fileName: fileName)
                ? editor.identifier
                : nil
        }

        return Set(identifiers).sorted()
    }

    static func supportsDirectEditingEditor(_ editor: NKDirectEditingEditor, contentType: String, fileName: String) -> Bool {
        if supportsMimetype(editor.mimetypes + editor.optionalMimetypes, contentType: contentType, fileName: fileName) {
            return true
        }

        let mimeType = normalizedMimetype(contentType)
        // HARDCODE: https://github.com/nextcloud/text/issues/913
        if mimeType == "text/x-markdown", supportsMimetype(
            editor.mimetypes, contentType: "text/markdown", fileName: fileName
        ) {
            return true
        }

        // HTML compatibility belongs to Nextcloud Text, not every advertised Office editor.
        return editor.identifier.caseInsensitiveCompare(NCGlobal.shared.editorText) == .orderedSame
            && mimeType == "text/html"
            && !editor.mimetypes.isEmpty
    }
}
