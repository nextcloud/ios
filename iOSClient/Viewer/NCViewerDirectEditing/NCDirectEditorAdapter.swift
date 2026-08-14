// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit

struct NCDirectEditorAdapter {
    /// Editor ID passed to the Direct Editing API.
    let apiKey: String
    /// Value passed to `NCViewerDirectEditing` to control editor-specific webview behaviour.
    let viewControllerEditor: String
    /// Resolves the editor-specific custom user agent.
    let userAgent: () -> String

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
            userAgent: nextcloudTextUserAgent
        ),
        NCGlobal.shared.editorOnlyOffice: NCDirectEditorAdapter(
            apiKey: NCGlobal.shared.editorOnlyOffice,
            viewControllerEditor: NCGlobal.shared.editorOnlyOffice,
            userAgent: mobileWebEditorUserAgent
        ),
        NCGlobal.shared.editorEuroOffice: NCDirectEditorAdapter(
            apiKey: NCGlobal.shared.editorEuroOffice,
            viewControllerEditor: NCGlobal.shared.editorEuroOffice,
            userAgent: mobileWebEditorUserAgent
        ),
        NCGlobal.shared.editorCollabora: NCDirectEditorAdapter(
            apiKey: NCGlobal.shared.editorCollabora,
            viewControllerEditor: NCGlobal.shared.editorCollabora,
            userAgent: { NCBrandOptions.shared.getUserAgent() }
        ),
        NCGlobal.shared.editorWhiteboard: NCDirectEditorAdapter(
            apiKey: NCGlobal.shared.editorWhiteboard,
            viewControllerEditor: NCGlobal.shared.editorWhiteboard,
            userAgent: mobileWebEditorUserAgent
        )
    ]

    private static func nextcloudTextUserAgent() -> String {
        let baseUserAgent = NCBrandOptions.shared.getUserAgent()
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            return baseUserAgent
        }

        // NOTE: Hardcoded (May 2022)
        // Tested for iPhone SE (1st), iOS 12 iPhone Pro Max, iOS 15.4
        // 605.1.15 = WebKit build version
        // 15E148 = frozen iOS build number according to: https://chromestatus.com/feature/4558585463832576
        return baseUserAgent + " AppleWebKit/605.1.15 Mobile/15E148"
    }

    private static func mobileWebEditorUserAgent() -> String {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        if UIDevice.current.userInterfaceIdiom == .pad {
            return "Mozilla/5.0 (iPad) Nextcloud-iOS/\(appVersion)"
        }
        return "Mozilla/5.0 (iPhone) Mobile Nextcloud-iOS/\(appVersion)"
    }
}
