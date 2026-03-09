// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import SwiftUI

extension UIFont {
    @inline(__always)
    private static func scaled(textStyle: UIFont.TextStyle, max: CGFloat) -> UIFont {
        UIFontMetrics(forTextStyle: textStyle)
            .scaledFont(
                for: UIFont.preferredFont(forTextStyle: textStyle),
                maximumPointSize: max
            )
    }

    // FONT Regular
    //
    static func body(max: CGFloat = 25) -> UIFont {
        scaled(textStyle: .body, max: max)
    }

    static func callout(max: CGFloat = 20) -> UIFont {
        scaled(textStyle: .callout, max: max)
    }

    static func footnote(max: CGFloat = 16) -> UIFont {
        scaled(textStyle: .footnote, max: max)
    }

    static func caption1(max: CGFloat = 15) -> UIFont {
        scaled(textStyle: .caption1, max: max)
    }

    static func caption2(max: CGFloat = 12) -> UIFont {
        scaled(textStyle: .caption2, max: max)
    }

    // FONT Semibold
    //
    static func headline(max: CGFloat = 25) -> UIFont {
        scaled(textStyle: .headline, max: max)
    }

    static func subheadline(max: CGFloat = 18) -> UIFont {
        scaled(textStyle: .subheadline, max: max)
    }
}

// SwiftUI version
//
extension Font {
    // Image - Icon
    //
    static func icon(_ size: CGFloat = 26, weight: Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}
