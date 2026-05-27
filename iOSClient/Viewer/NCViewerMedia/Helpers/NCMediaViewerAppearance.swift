// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit
import NextcloudKit

// MARK: - Viewer Background Style
enum NCViewerBackgroundStyle {
    case system
    case black
    case white
    case custom(UIColor)
}

// MARK: - UIColor Viewer Background
extension UIColor {
    static func ncViewerBackground(_ style: NCViewerBackgroundStyle = .system) -> UIColor {
        switch style {
        case .system:
            return .systemBackground
        case .black:
            return .black
        case .white:
            return .white
        case .custom(let color):
            return color
        }
    }
}

// MARK: - Color Viewer Background
extension Color {
    static func ncViewerBackground(_ style: NCViewerBackgroundStyle = .system) -> Color {
        Color(uiColor: .ncViewerBackground(style))
    }
}

// MARK: - Color Viewer Progress Tint
extension Color {
    static func ncViewerProgressTint(_ style: NCViewerBackgroundStyle = .system) -> Color {
        switch style {
        case .black:
            return .white

        case .system,
             .white,
             .custom:
            return .accentColor
        }
    }
}

// MARK: - Viewer Background Resolution
func ncViewerBackgroundStyle(for metadata: tableMetadata?) -> NCViewerBackgroundStyle {
    guard let metadata else {
        return .system
    }

    switch metadata.classFile {
    case NKTypeClassFile.image.rawValue:
        return .system
    case NKTypeClassFile.video.rawValue:
        return .black
    case NKTypeClassFile.audio.rawValue:
        return .system
    default:
        return .system
    }
}
