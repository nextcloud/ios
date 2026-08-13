// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct NCDirectEditorAdapter {
    /// Editor ID passed to the textOpenFile API.
    let apiKey: String
    /// Value set on NCViewerNextcloudText.editor — controls user agent and JS behaviour.
    let viewControllerEditor: String
    /// Resolves the custom user agent string via NCUtility.
    let userAgent: (NCUtility) -> String
    /// Returns the fallback file extension for a given templateId when the template API returns no templates.
    let defaultExt: (_ templateId: String) -> String

    /// Lookup an adapter for the first matching editor ID in the provided list.
    /// The list should already be lowercased.
    static func resolve(from editors: [String]) -> NCDirectEditorAdapter? {
        editors.lazy.compactMap { registry[$0.lowercased()] }.first
    }

    // MARK: - Registry

    private static func officeDefaultExt(_ templateId: String) -> String {
        switch templateId {
        case "spreadsheet": return "xlsx"
        case "presentation": return "pptx"
        default: return "docx"
        }
    }

    private static let registry: [String: NCDirectEditorAdapter] = [
        NCGlobal.shared.editorText: NCDirectEditorAdapter(
            apiKey: NCGlobal.shared.editorText,
            viewControllerEditor: NCGlobal.shared.editorText,
            userAgent: { $0.getCustomUserAgentNCText() },
            defaultExt: { _ in "md" }
        ),
        NCGlobal.shared.editorOnlyOffice: NCDirectEditorAdapter(
            apiKey: NCGlobal.shared.editorOnlyOffice,
            viewControllerEditor: NCGlobal.shared.editorOnlyOffice,
            userAgent: { $0.getCustomUserAgentOnlyOffice() },
            defaultExt: officeDefaultExt
        ),
        NCGlobal.shared.editorEuroOffice: NCDirectEditorAdapter(
            apiKey: NCGlobal.shared.editorEuroOffice,
            viewControllerEditor: NCGlobal.shared.editorEuroOffice,
            userAgent: { $0.getCustomUserAgentOnlyOffice() },
            defaultExt: officeDefaultExt
        ),
        NCGlobal.shared.editorWhiteboard: NCDirectEditorAdapter(
            apiKey: NCGlobal.shared.editorWhiteboard,
            viewControllerEditor: NCGlobal.shared.editorWhiteboard,
            userAgent: { $0.getCustomUserAgentOnlyOffice() },
            defaultExt: { _ in "whiteboard" }
        )
    ]
}
