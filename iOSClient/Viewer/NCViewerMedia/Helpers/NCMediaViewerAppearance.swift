// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit
import NextcloudKit

// Appearance entry point for shared viewer backgrounds and adaptive control colors.
// Change the policy here rather than adding layout-specific colors in consuming views.
// See README.md, "Changing colors and appearance", for the consumer map and checks.

// MARK: - Viewer Background Style
/// A background choice, separate from layout geometry and the visibility of navigation.
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
    /// Loading indicators stay visible on black; other backgrounds use the app accent.
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
/// Default viewer background. `.system` follows the inherited light/dark appearance.
func ncViewerBackgroundStyle(for metadata: tableMetadata?) -> NCViewerBackgroundStyle {
    .system
}

// MARK: - Viewer Chrome-Aware Background Resolution
/// Shared by normal and folded content: hiding chrome makes the background black.
/// Folding only hides the traditional navigation bar; it does not change this policy
/// or `isChromeHidden`. The adaptive panel inherits this policy by default.
func ncViewerBackgroundStyle(for metadata: tableMetadata?, isChromeHidden: Bool) -> NCViewerBackgroundStyle {
    if isChromeHidden {
        return .black
    }

    return ncViewerBackgroundStyle(for: metadata)
}

// MARK: - Adaptive Panel Background
/// Background of the lower paged-media panel only. The upper content and normal
/// layout do not use this entry. Keep `contentStyle` to follow the standard viewer;
/// return `.custom(.systemOrange)`, `.black` or `.white` to customize this panel.
/// Fullscreen AVPlayer/VLC retain their existing playback background.
func ncViewerAdaptivePanelBackgroundStyle(contentStyle: NCViewerBackgroundStyle) -> NCViewerBackgroundStyle {
    contentStyle
}

// MARK: - Adaptive Control Appearance
/// Applied by the common adaptive lower panel so its SwiftUI and UIKit controls
/// contrast with the resolved background. System/custom backgrounds inherit appearance;
/// callers choosing a custom color must ensure it contrasts with the inherited palette.
func ncViewerAdaptiveControlsColorScheme(for style: NCViewerBackgroundStyle, inherited: ColorScheme) -> ColorScheme {
    switch style {
    case .black:
        return .dark
    case .white:
        return .light
    case .system, .custom:
        return inherited
    }
}

extension UIColor {
    // Adaptive controls only: edit these entries for island/button fills, labels and borders.
    // Keep system colors dynamic: resolving them here would freeze light/dark appearance.
    static var ncViewerAdaptiveControlBackground: UIColor { .secondarySystemBackground }
    static var ncViewerAdaptiveControlForeground: UIColor { .label }
    static var ncViewerAdaptiveControlBorder: UIColor { .separator }
}

extension Color {
    // SwiftUI forwards to the UIKit palette: do not define a second set of colors here.
    static var ncViewerAdaptiveControlBackground: Color { Color(uiColor: .ncViewerAdaptiveControlBackground) }
    static var ncViewerAdaptiveControlForeground: Color { Color(uiColor: .ncViewerAdaptiveControlForeground) }
    static var ncViewerAdaptiveControlBorder: Color { Color(uiColor: .ncViewerAdaptiveControlBorder) }
}

private struct NCMediaViewerFoldedLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Geometry/interaction state for folded content, not an appearance override.
    var mediaViewerIsFoldedLayout: Bool {
        get { self[NCMediaViewerFoldedLayoutKey.self] }
        set { self[NCMediaViewerFoldedLayoutKey.self] = newValue }
    }
}
