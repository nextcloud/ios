// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import SwiftUI

// MARK: - UIFont Dynamic Type Helpers
//
// This extension provides convenience helpers for creating Dynamic Type fonts
// with an upper bound on their maximum size.
//
// The system normally scales fonts according to the user's preferred
// content size category (Dynamic Type). In some interfaces, especially in
// dense layouts or toolbars, allowing unrestricted scaling can cause the UI
// to break or overflow.
//
// These helpers wrap `UIFontMetrics` to:
// - Preserve Dynamic Type scaling.
// - Respect the semantic text style.
// - Apply a maximum point size cap to keep layouts stable.
//
// The scaling behavior is driven by `UIFontMetrics(forTextStyle:)` which
// applies the correct scaling curve for each text style.
//
// Example:
//
//     label.font = .body()
//
// The font will scale with the user's accessibility settings, but will never
// exceed the specified maximum size.
//
// If the user selects a very large accessibility size, the font will stop
// growing once the maximum point size is reached.
//
// This pattern is commonly used in interfaces where typography must remain
// readable but visually constrained (navigation bars, compact settings,
// form rows, etc.).
//
extension UIFont {

    // Returns a Dynamic Type scaled font with an upper size limit.
    //
    // Parameters:
    // - textStyle: The semantic text style used for scaling metrics.
    // - max: The maximum point size allowed after scaling.
    //
    // Returns:
    // A UIFont scaled for the current Dynamic Type size category,
    // capped at the provided maximum point size.
    @inline(__always)
    private static func scaled(textStyle: UIFont.TextStyle, max: CGFloat) -> UIFont {
        UIFontMetrics(forTextStyle: textStyle)
            .scaledFont(
                for: UIFont.preferredFont(forTextStyle: textStyle),
                maximumPointSize: max
            )
    }

    // MARK: - Regular Text Styles

    // Dynamic Type scaled body font with a maximum size cap.
    static func body(max: CGFloat = 25) -> UIFont {
        scaled(textStyle: .body, max: max)
    }

    // Dynamic Type scaled callout font with a maximum size cap.
    static func callout(max: CGFloat = 20) -> UIFont {
        scaled(textStyle: .callout, max: max)
    }

    // Dynamic Type scaled footnote font with a maximum size cap.
    static func footnote(max: CGFloat = 16) -> UIFont {
        scaled(textStyle: .footnote, max: max)
    }

    // Dynamic Type scaled caption1 font with a maximum size cap.
    static func caption1(max: CGFloat = 15) -> UIFont {
        scaled(textStyle: .caption1, max: max)
    }

    // Dynamic Type scaled caption2 font with a maximum size cap.
    static func caption2(max: CGFloat = 12) -> UIFont {
        scaled(textStyle: .caption2, max: max)
    }

    // MARK: - Semibold Text Styles

    // Dynamic Type scaled headline font with a maximum size cap.
    static func headline(max: CGFloat = 25) -> UIFont {
        scaled(textStyle: .headline, max: max)
    }

    // Dynamic Type scaled subheadline font with a maximum size cap.
    static func subheadline(max: CGFloat = 18) -> UIFont {
        scaled(textStyle: .subheadline, max: max)
    }
}
