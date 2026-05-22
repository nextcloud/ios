// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit
import NextcloudKit

// MARK: - Viewer Background Style

/// Defines the background style used by viewer containers and media pages.
enum NCViewerBackgroundStyle {
    /// Uses the current system appearance.
    case system

    /// Always uses black, useful for video and cinema-style media viewers.
    case black

    /// Always uses white, useful for document-like viewers.
    case white

    /// Uses a custom UIKit color.
    case custom(UIColor)
}

// MARK: - UIColor Viewer Background

extension UIColor {
    /// Returns the background color for a viewer background style.
    ///
    /// - Parameter style: Viewer background style.
    /// - Returns: Resolved UIKit background color.
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
    /// Returns the background color for a viewer background style.
    ///
    /// - Parameter style: Viewer background style.
    /// - Returns: Resolved SwiftUI background color.
    static func ncViewerBackground(_ style: NCViewerBackgroundStyle = .system) -> Color {
        Color(uiColor: .ncViewerBackground(style))
    }
}

// MARK: - Color Viewer Progress Tint

extension Color {
    /// Returns a readable progress tint color for a viewer background style.
    ///
    /// - Parameter style: Viewer background style.
    /// - Returns: SwiftUI tint color suitable for loading indicators.
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

/// Returns the preferred viewer background style for a metadata item.
///
/// - Parameter metadata: Optional detached metadata.
/// - Returns: Background style preferred for the media type.
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
