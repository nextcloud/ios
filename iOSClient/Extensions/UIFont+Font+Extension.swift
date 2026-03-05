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
    @inline(__always)
    private static func scaled(textStyle: UIFont.TextStyle, max: CGFloat) -> Font {
        let font = UIFontMetrics(forTextStyle: textStyle)
            .scaledFont(
                for: UIFont.preferredFont(forTextStyle: textStyle),
                maximumPointSize: max
            )
        return Font(font)
    }

    // FONT Regular
    //
    static func largeTitle(max: CGFloat = 40) -> Font {
        scaled(textStyle: .largeTitle, max: max)
    }

    static func title1(max: CGFloat = 34) -> Font {
        scaled(textStyle: .title1, max: max)
    }

    static func title2(max: CGFloat = 30) -> Font {
        scaled(textStyle: .title2, max: max)
    }

    static func title3(max: CGFloat = 28) -> Font {
        scaled(textStyle: .title3, max: max)
    }

    static func body(max: CGFloat = 25) -> Font {
        scaled(textStyle: .body, max: max)
    }

    static func callout(max: CGFloat = 20) -> Font {
        scaled(textStyle: .callout, max: max)
    }

    static func footnote(max: CGFloat = 16) -> Font {
        scaled(textStyle: .footnote, max: max)
    }

    static func caption1(max: CGFloat = 15) -> Font {
        scaled(textStyle: .caption1, max: max)
    }

    static func caption2(max: CGFloat = 12) -> Font {
        scaled(textStyle: .caption2, max: max)
    }

    // FONT Semibold
    //
    static func headline(max: CGFloat = 25) -> Font {
        scaled(textStyle: .headline, max: max)
    }

    static func subheadline(max: CGFloat = 18) -> Font {
        scaled(textStyle: .subheadline, max: max)
    }

    // Image - Icon
    //
    static func icon(_ size: CGFloat = 26, weight: Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}
