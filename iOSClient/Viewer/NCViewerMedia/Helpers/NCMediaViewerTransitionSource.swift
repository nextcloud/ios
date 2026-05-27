// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

// MARK: - Viewer Transition Source
struct NCMediaViewerTransitionSource {
    let image: UIImage

    let sourceFrame: CGRect

    let cornerRadius: CGFloat

    init(image: UIImage, sourceFrame: CGRect, cornerRadius: CGFloat = 0) {
        self.image = image
        self.sourceFrame = sourceFrame
        self.cornerRadius = cornerRadius
    }
}
