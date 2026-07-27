// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit

extension NCMedia: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        setTitleDate()

        if !dataSource.compactMetadatas.isEmpty {
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    func scrollViewDidEndDragging(
        _ scrollView: UIScrollView,
        willDecelerate decelerate: Bool
    ) {
        if !decelerate {
            updateImageCacheWindow()
            searchNewMedia()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateImageCacheWindow()
        searchNewMedia()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        updateImageCacheWindow(force: true)
    }
}
