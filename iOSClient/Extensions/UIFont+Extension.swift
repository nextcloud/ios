// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit

extension UIFont {
    static func callout(max: CGFloat = 20) -> UIFont {
        UIFontMetrics(forTextStyle: .callout)
            .scaledFont(
                for: UIFont.preferredFont(forTextStyle: .callout),
                maximumPointSize: max
            )
    }

    static func caption1(max: CGFloat = 15) -> UIFont {
        UIFontMetrics(forTextStyle: .caption1)
            .scaledFont(
                for: UIFont.preferredFont(forTextStyle: .caption1),
                maximumPointSize: max
            )
    }

    static func caption2(max: CGFloat = 12) -> UIFont {
        UIFontMetrics(forTextStyle: .caption2)
            .scaledFont(
                for: UIFont.preferredFont(forTextStyle: .caption2),
                maximumPointSize: max
            )
    }

    static func headline(max: CGFloat = 25) -> UIFont {
        UIFontMetrics(forTextStyle: .headline)
            .scaledFont(
                for: UIFont.preferredFont(forTextStyle: .headline),
                maximumPointSize: max
            )
    }
}
