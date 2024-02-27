//
//  NCMediaGridLayout.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 27/01/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit

class NCMediaGridLayout: UICollectionViewFlowLayout {
    var marginLeftRight: CGFloat = 2
    var columnCount: Int = 0
    var mediaViewController: NCMedia?

    override func prepare() {

        sectionHeadersPinToVisibleBounds = false
        minimumInteritemSpacing = 0
        minimumLineSpacing = marginLeftRight

        self.scrollDirection = .vertical
        self.sectionInset = UIEdgeInsets(top: 0, left: marginLeftRight, bottom: 0, right: marginLeftRight)

        columnCount = NCKeychain().mediaItemForLine
        mediaViewController?.buildMediaPhotoVideo(itemForLine: columnCount)
        if UIDevice.current.userInterfaceIdiom == .phone,
           (UIDevice.current.orientation == .landscapeLeft || UIDevice.current.orientation == .landscapeRight) {
            columnCount += 2
        }
    }

    override var itemSize: CGSize {
        get {
            if let collectionView = mediaViewController?.collectionView {
                let itemForLine = CGFloat(self.columnCount)
                var frameWidth = collectionView.frame.width
                if (UIDevice.current.orientation == .landscapeLeft || UIDevice.current.orientation == .landscapeRight) {
                    frameWidth = collectionView.frame.height
                }
                let itemWidth: CGFloat = (frameWidth - marginLeftRight * 2 - marginLeftRight * (itemForLine - 1)) / itemForLine
                let itemHeight: CGFloat = itemWidth
                return CGSize(width: itemWidth, height: itemHeight)
            }

            // Default fallback
            return CGSize(width: 100, height: 100)
        }
        set {
            super.itemSize = newValue
        }
    }

    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        return proposedContentOffset
    }
}
