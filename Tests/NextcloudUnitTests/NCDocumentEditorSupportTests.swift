// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import Testing
@testable import Nextcloud

@Suite("Document editor MIME type recognition")
struct NCDocumentEditorSupportTests {
    private let word = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    private let spreadsheet = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

    @Test("Server MIME types work even without a filename extension")
    func extensionlessDocument() {
        #expect(NCDocumentEditorSupport.supportsMimetype([word], contentType: word, fileName: "Document"))
    }

    @Test("MIME type comparison ignores case, whitespace and parameters")
    func normalizedServerType() {
        #expect(NCDocumentEditorSupport.supportsMimetype(
            ["application/pdf"], contentType: " APPLICATION/PDF; charset=binary ", fileName: "document.pdf"
        ))
    }

    @Test("Apple PDF type identifiers match the server MIME type")
    func appleTypeIdentifier() {
        #expect(NCDocumentEditorSupport.supportsMimetype(
            ["application/pdf"], contentType: "com.adobe.pdf", fileName: "Document"
        ))
    }

    @Test("Office extensions identify files with missing or generic MIME types",
           arguments: ["", "application/octet-stream", "application/zip"])
    func genericOfficeType(contentType: String) {
        #expect(NCDocumentEditorSupport.supportsMimetype([word], contentType: contentType, fileName: "Document.DOCX"))
        #expect(NCDocumentEditorSupport.supportsMimetype([spreadsheet], contentType: contentType, fileName: "Sheet.xlsx"))
    }

    @Test("An explicitly supported generic MIME type is retained",
           arguments: ["application/octet-stream", "application/zip"])
    func supportedGenericType(contentType: String) {
        #expect(NCDocumentEditorSupport.supportsMimetype(
            [contentType], contentType: contentType, fileName: "document.docx"
        ))
    }

    @Test("A specific server MIME type takes precedence over the filename")
    func authoritativeServerType() {
        #expect(!NCDocumentEditorSupport.supportsMimetype([word], contentType: "text/plain", fileName: "document.docx"))
    }

    @Test("Unsupported and empty MIME types do not match substrings")
    func unsupportedType() {
        #expect(!NCDocumentEditorSupport.supportsMimetype([word], contentType: "document", fileName: "file.unknown"))
        #expect(!NCDocumentEditorSupport.supportsMimetype([word], contentType: "", fileName: "file.unknown"))
        #expect(!NCDocumentEditorSupport.supportsMimetype([], contentType: word, fileName: "document.docx"))
    }

    @Test("HTML compatibility does not advertise Office editors without HTML support")
    func officeHTMLRequiresSupport() throws {
        for identifier in ["richdocuments", "onlyoffice", "eurooffice"] {
            let editor = try makeEditor(identifier: identifier, mimetypes: [word])
            #expect(!NCDocumentEditorSupport.supportsDirectEditingEditor(
                editor, contentType: "text/html", fileName: "page.html"
            ))
        }
    }

    @Test("An Office editor can explicitly advertise optional HTML support")
    func optionalHTMLSupport() throws {
        let editor = try makeEditor(identifier: "richdocuments", mimetypes: [word], optionalMimetypes: ["text/html"])
        #expect(NCDocumentEditorSupport.supportsDirectEditingEditor(
            editor, contentType: "text/html", fileName: "page.html"
        ))
    }

    @Test("Nextcloud Text retains HTML and Markdown compatibility")
    func textCompatibility() throws {
        let editor = try makeEditor(identifier: "text", mimetypes: ["text/plain", "text/markdown"])
        #expect(NCDocumentEditorSupport.supportsDirectEditingEditor(
            editor, contentType: "text/html", fileName: "page.html"
        ))
        #expect(NCDocumentEditorSupport.supportsDirectEditingEditor(
            editor, contentType: "text/x-markdown", fileName: "notes.md"
        ))
    }

    @Test("Editors advertising Markdown retain the existing MIME alias")
    func advertisedMarkdownAlias() throws {
        let editor = try makeEditor(identifier: "richdocuments", mimetypes: ["text/markdown"])
        #expect(NCDocumentEditorSupport.supportsDirectEditingEditor(
            editor, contentType: "text/x-markdown", fileName: "notes.md"
        ))
    }

    @Test("Optional Office types and generic MIME inference select the editor")
    func optionalOfficeSupport() throws {
        let editor = try makeEditor(identifier: "richdocuments", mimetypes: [], optionalMimetypes: [spreadsheet])
        #expect(NCDocumentEditorSupport.supportsDirectEditingEditor(
            editor, contentType: "application/octet-stream", fileName: "sheet.xlsx"
        ))
    }

    private func makeEditor(identifier: String, mimetypes: [String], optionalMimetypes: [String] = []) throws -> NKDirectEditingEditor {
        let data = try JSONSerialization.data(withJSONObject: [
            "id": identifier,
            "name": identifier,
            "mimetypes": mimetypes,
            "optionalMimetypes": optionalMimetypes,
            "secure": true
        ])
        return try JSONDecoder().decode(NKDirectEditingEditor.self, from: data)
    }

}
