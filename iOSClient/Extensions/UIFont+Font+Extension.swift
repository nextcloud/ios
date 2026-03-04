// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import SwiftUI

extension UIFont {
    // regular
    static func body(max: CGFloat = 25) -> UIFont {
        UIFontMetrics(forTextStyle: .body)
            .scaledFont(
                for: UIFont.preferredFont(forTextStyle: .body),
                maximumPointSize: max
            )
    }

    // regular
    static func callout(max: CGFloat = 20) -> UIFont {
        UIFontMetrics(forTextStyle: .callout)
            .scaledFont(
                for: UIFont.preferredFont(forTextStyle: .callout),
                maximumPointSize: max
            )
    }

    // regular
    static func caption1(max: CGFloat = 15) -> UIFont {
        UIFontMetrics(forTextStyle: .caption1)
            .scaledFont(
                for: UIFont.preferredFont(forTextStyle: .caption1),
                maximumPointSize: max
            )
    }

    // regular
    static func caption2(max: CGFloat = 12) -> UIFont {
        UIFontMetrics(forTextStyle: .caption2)
            .scaledFont(
                for: UIFont.preferredFont(forTextStyle: .caption2),
                maximumPointSize: max
            )
    }

    // semibold
    static func headline(max: CGFloat = 25) -> UIFont {
        UIFontMetrics(forTextStyle: .headline)
            .scaledFont(
                for: UIFont.preferredFont(forTextStyle: .headline),
                maximumPointSize: max
            )
    }
}

// SwiftUI version
//
extension Font {
    // regular
    static func body(max: CGFloat = 25) -> Font {
        let font = UIFontMetrics(forTextStyle: .body)
            .scaledFont(for: UIFont.preferredFont(forTextStyle: .body),
                        maximumPointSize: max)
        return Font(font)
    }

    // regular
    static func callout(max: CGFloat = 20) -> Font {
        let font = UIFontMetrics(forTextStyle: .callout)
            .scaledFont(for: UIFont.preferredFont(forTextStyle: .callout),
                        maximumPointSize: max)
        return Font(font)
    }

    // Image - Icon
    static func icon(_ size: CGFloat = 23, weight: Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}
