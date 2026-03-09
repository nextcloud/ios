// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftUI

// MARK: - SwiftUI Font Helpers
//
// This extension provides a convenience font for icon rendering in SwiftUI.
//
// SF Symbols behave like typographic glyphs rather than images. The correct
// way to size them is through font metrics instead of resizing the image.
//
// Using `.system(size:)` preserves:
// - correct symbol proportions
// - optical alignment
// - weight variants
//
// Example:
//
//     Image(systemName: "gear")
//         .font(.icon())
//
// This ensures the symbol behaves like text glyphs inside the layout.
//
extension Font {

    // Returns a system font intended for rendering SF Symbol icons.
    //
    // Parameters:
    // - size: Desired icon size in points.
    // - weight: Font weight applied to the symbol.
    //
    // Returns:
    // A SwiftUI Font configured for symbol rendering.
    static func icon(_ size: CGFloat = 26, weight: Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}
