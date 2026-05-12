// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
import UIKit
@testable import Nextcloud

@Suite("NCDirectEditorAdapter.resolve")
struct NCDirectEditorAdapterResolveTests {

    @Test("returns adapter for each registered editor")
    func knownEditors() {
        #expect(NCDirectEditorAdapter.resolve(from: ["text"])?.apiKey == "text")
        #expect(NCDirectEditorAdapter.resolve(from: ["onlyoffice"])?.apiKey == "onlyoffice")
        #expect(NCDirectEditorAdapter.resolve(from: ["eurooffice"])?.apiKey == "eurooffice")
    }

    @Test("returns nil for unknown or empty list")
    func unknownEditors() {
        #expect(NCDirectEditorAdapter.resolve(from: ["collabora"]) == nil)
        #expect(NCDirectEditorAdapter.resolve(from: []) == nil)
        #expect(NCDirectEditorAdapter.resolve(from: ["unknown"]) == nil)
    }

    @Test("lookup is case-insensitive")
    func caseInsensitive() {
        #expect(NCDirectEditorAdapter.resolve(from: ["ONLYOFFICE"])?.apiKey == "onlyoffice")
        #expect(NCDirectEditorAdapter.resolve(from: ["Eurooffice"])?.apiKey == "eurooffice")
        #expect(NCDirectEditorAdapter.resolve(from: ["TEXT"])?.apiKey == "text")
    }

    @Test("picks first matching editor from the list")
    func picksFirst() {
        let adapter = NCDirectEditorAdapter.resolve(from: ["unknown", "eurooffice", "text"])
        #expect(adapter?.apiKey == "eurooffice")
    }

    @Test("eurooffice uses onlyoffice view controller editor")
    func euroofficeViewControllerEditor() {
        #expect(NCDirectEditorAdapter.resolve(from: ["eurooffice"])?.viewControllerEditor == "onlyoffice")
    }

    @Test("onlyoffice uses onlyoffice view controller editor")
    func onlyofficeViewControllerEditor() {
        #expect(NCDirectEditorAdapter.resolve(from: ["onlyoffice"])?.viewControllerEditor == "onlyoffice")
    }

    @Test("text uses nextcloud text view controller editor")
    func textViewControllerEditor() {
        #expect(NCDirectEditorAdapter.resolve(from: ["text"])?.viewControllerEditor == "nextcloud text")
    }
}

@Suite("NCDirectEditorAdapter.defaultExt")
struct NCDirectEditorAdapterDefaultExtTests {

    @Test("text always returns md regardless of templateId")
    func textAlwaysMd() {
        let adapter = NCDirectEditorAdapter.resolve(from: ["text"])!
        #expect(adapter.defaultExt("document") == "md")
        #expect(adapter.defaultExt("spreadsheet") == "md")
        #expect(adapter.defaultExt("presentation") == "md")
        #expect(adapter.defaultExt("anything") == "md")
    }

    @Test("onlyoffice maps templateId to office extension")
    func onlyofficeTemplateMap() {
        let adapter = NCDirectEditorAdapter.resolve(from: ["onlyoffice"])!
        #expect(adapter.defaultExt("document") == "docx")
        #expect(adapter.defaultExt("spreadsheet") == "xlsx")
        #expect(adapter.defaultExt("presentation") == "pptx")
    }

    @Test("eurooffice maps templateId to office extension")
    func euroofficeTemplateMap() {
        let adapter = NCDirectEditorAdapter.resolve(from: ["eurooffice"])!
        #expect(adapter.defaultExt("document") == "docx")
        #expect(adapter.defaultExt("spreadsheet") == "xlsx")
        #expect(adapter.defaultExt("presentation") == "pptx")
    }

    @Test("unknown templateId falls back to docx for office editors")
    func unknownTemplateIdFallback() {
        let adapter = NCDirectEditorAdapter.resolve(from: ["onlyoffice"])!
        #expect(adapter.defaultExt("unknown") == "docx")
        #expect(adapter.defaultExt("") == "docx")
    }
}

@Suite("NCContextMenuPlus.menuInfo")
struct CreatorMenuInfoTests {

    @Test("docx maps to document")
    func docx() {
        let info = NCContextMenuPlus.menuInfo(for: "docx")
        #expect(info?.titleKey == "_create_new_document_")
        #expect(info?.templateId == "document")
        #expect(info?.icon == "doc.text")
        #expect(info?.sortOrder == 0)
    }

    @Test("xlsx maps to spreadsheet")
    func xlsx() {
        let info = NCContextMenuPlus.menuInfo(for: "xlsx")
        #expect(info?.titleKey == "_create_new_spreadsheet_")
        #expect(info?.templateId == "spreadsheet")
        #expect(info?.icon == "tablecells")
        #expect(info?.sortOrder == 1)
    }

    @Test("pptx maps to presentation")
    func pptx() {
        let info = NCContextMenuPlus.menuInfo(for: "pptx")
        #expect(info?.titleKey == "_create_new_presentation_")
        #expect(info?.templateId == "presentation")
        #expect(info?.icon == "play.rectangle")
        #expect(info?.sortOrder == 2)
    }

    @Test("document sorts before spreadsheet sorts before presentation")
    func sortOrder() {
        let docx = NCContextMenuPlus.menuInfo(for: "docx")!
        let xlsx = NCContextMenuPlus.menuInfo(for: "xlsx")!
        let pptx = NCContextMenuPlus.menuInfo(for: "pptx")!
        #expect(docx.sortOrder < xlsx.sortOrder)
        #expect(xlsx.sortOrder < pptx.sortOrder)
    }

    @Test("unknown extension returns nil")
    func unknownExtension() {
        #expect(NCContextMenuPlus.menuInfo(for: "pdf") == nil)
        #expect(NCContextMenuPlus.menuInfo(for: "md") == nil)
        #expect(NCContextMenuPlus.menuInfo(for: "") == nil)
        #expect(NCContextMenuPlus.menuInfo(for: "doc") == nil)
    }

    @Test("matching is case-insensitive")
    func caseInsensitive() {
        #expect(NCContextMenuPlus.menuInfo(for: "DOCX")?.templateId == "document")
        #expect(NCContextMenuPlus.menuInfo(for: "XLSX")?.templateId == "spreadsheet")
        #expect(NCContextMenuPlus.menuInfo(for: "Pptx")?.templateId == "presentation")
    }
}
