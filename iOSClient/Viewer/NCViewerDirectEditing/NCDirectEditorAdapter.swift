// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct NCDirectEditorAdapter {
    /// Editor ID passed to the Direct Editing API.
    let apiKey: String
    /// Value passed to `NCViewerDirectEditing` to control editor-specific webview behaviour.
    let viewControllerEditor: String
    /// Resolves the custom user agent string via NCUtility.
    let userAgent: (NCUtility) -> String

    /// Lookup an adapter for the first matching editor ID in the provided list.
    /// The list should already be lowercased.
    static func resolve(from editors: [String]) -> NCDirectEditorAdapter? {
        editors.lazy.compactMap { registry[$0.lowercased()] }.first
    }

    // MARK: - Registry

    private static let registry: [String: NCDirectEditorAdapter] = [
        NCGlobal.shared.editorText: NCDirectEditorAdapter(
            apiKey: NCGlobal.shared.editorText,
            viewControllerEditor: NCGlobal.shared.editorText,
            userAgent: { $0.getCustomUserAgentNCText() }
        ),
        NCGlobal.shared.editorOnlyOffice: NCDirectEditorAdapter(
            apiKey: NCGlobal.shared.editorOnlyOffice,
            viewControllerEditor: NCGlobal.shared.editorOnlyOffice,
            userAgent: { $0.getCustomUserAgentOnlyOffice() }
        ),
        NCGlobal.shared.editorEuroOffice: NCDirectEditorAdapter(
            apiKey: NCGlobal.shared.editorEuroOffice,
            viewControllerEditor: NCGlobal.shared.editorEuroOffice,
            userAgent: { $0.getCustomUserAgentOnlyOffice() }
        ),
        NCGlobal.shared.editorCollabora: NCDirectEditorAdapter(
            apiKey: NCGlobal.shared.editorCollabora,
            viewControllerEditor: NCGlobal.shared.editorCollabora,
            userAgent: { _ in NCBrandOptions.shared.getUserAgent() }
        ),
        NCGlobal.shared.editorWhiteboard: NCDirectEditorAdapter(
            apiKey: NCGlobal.shared.editorWhiteboard,
            viewControllerEditor: NCGlobal.shared.editorWhiteboard,
            userAgent: { $0.getCustomUserAgentOnlyOffice() }
        )
    ]
}
