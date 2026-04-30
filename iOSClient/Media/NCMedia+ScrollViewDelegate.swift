// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit

extension NCMedia: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
//        setTitleDate()
//
//        if !dataSource.compactMetadatas.isEmpty {
//            setNeedsStatusBarAppearanceUpdate()
//        }
        if !dataSource.compactMetadatas.isEmpty {
            isTop = scrollView.contentOffset.y <= -(insetsTop + view.safeAreaInsets.top - 25)
//            setTitleDate()
            if lastContentOffsetY == 0 || lastContentOffsetY / 2 <= scrollView.contentOffset.y || lastContentOffsetY / 2 >= scrollView.contentOffset.y {
                setTitleDate()
                lastContentOffsetY = scrollView.contentOffset.y
            }
            setNeedsStatusBarAppearanceUpdate()
        }
//        setElements()
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

    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        let y = view.safeAreaInsets.top
        scrollView.contentOffset.y = -(insetsTop + y)
    }
}
