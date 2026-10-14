// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

/// Shared lower-panel geometry. Colors belong to NCMediaViewerAppearance;
/// fold detection and upper/lower frames belong to NCMediaAdaptiveLayoutView.
/// These rules keep Previous/Next and the thumbnail lane aligned across media.
@MainActor
enum NCMediaAdaptiveControlsLayout {
    static let spacing: CGFloat = 5
    /// Shared height for Close/Info/More and Previous/Next across all adaptive media.
    static let actionsHeight: CGFloat = 60
    /// Extra clearance above the Home indicator, in addition to the outer 5-point margin.
    static let thumbnailBottomInset: CGFloat = 25

    /// Matches the top action buttons, leaving a gap above the navigation row.
    /// The row shrinks in very small regions rather than exceeding available space.
    static func navigationHeight(availableHeight: CGFloat) -> CGFloat {
        min(max(0, availableHeight - spacing), actionsHeight)
    }

    /// Excludes outer margins, actions, thumbnails and the two inter-section gaps.
    static func middleHeight(panelHeight: CGFloat) -> CGFloat {
        max(0, panelHeight - actionsHeight - NCMediaViewerThumbnail.preferredHeight - spacing * 4 - thumbnailBottomInset)
    }

    /// Footer has outer vertical margins and a gap between navigation and thumbnails.
    static func footerHeight(navigationHeight: CGFloat) -> CGFloat {
        navigationHeight + NCMediaViewerThumbnail.preferredHeight + spacing * 3 + thumbnailBottomInset
    }
}
