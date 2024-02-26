//
//  NCMediaDynamicLayout.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 20/02/24.
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

protocol NCMediaDynamicLayoutDelegate: AnyObject {
    func itemSize(_ collectionView: UICollectionView, indexPath: IndexPath, itemForLine: CGFloat) -> CGSize
}

class NCMediaDynamicLayout: UICollectionViewLayout {
    var delegate: NCMediaDynamicLayoutDelegate?
    var columSpacing: CGFloat = 0
    var rowSpacing: CGFloat = 0
    var sectionInset: UIEdgeInsets = UIEdgeInsets.zero
    var itemForLine: Int = 0

    private var attributesArray: [UICollectionViewLayoutAttributes] = []
    private var maxYsArray: [NSNumber] = []

    override func prepare() {
        super.prepare()

        attributesArray.removeAll()
        maxYsArray.removeAll()

        let itemCount = collectionView?.numberOfItems(inSection: 0) ?? 0
        let layoutMaxY: CGFloat = 0

        if UIDevice.current.userInterfaceIdiom == .phone,
           (UIDevice.current.orientation == .landscapeLeft || UIDevice.current.orientation == .landscapeRight) {
            itemForLine = NCKeychain().mediaItemForLine + 2
        } else {
            itemForLine = NCKeychain().mediaItemForLine
        }

        for _ in 0..<itemForLine {
            maxYsArray.append(NSNumber(value: Float(sectionInset.top + layoutMaxY)))
        }

        for index in 0..<itemCount {
            if let attribute = layoutAttributesForItem(at: IndexPath(item: index, section: 0)) {
                attributesArray.append(attribute)
            }
        }
    }

    override var collectionViewContentSize: CGSize {
        var maxValue: Float = 0
        for i in 0..<maxYsArray.count {
            let value = maxYsArray[i].floatValue
            if maxValue < value {
                maxValue = value
            }
        }
        return CGSize(width: 0, height: CGFloat(maxValue) + sectionInset.bottom)
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let collectionView, let delegate = self.delegate else { return nil }
        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        let columnTotalSpacing: CGFloat = CGFloat(itemForLine - 1) * columSpacing

        let size = delegate.itemSize(collectionView, indexPath: indexPath, itemForLine: CGFloat(itemForLine))
        let itemWidth = ((collectionView.frame.size.width - sectionInset.left - sectionInset.right) - columnTotalSpacing) / CGFloat(itemForLine)
        let ratio = itemWidth / size.width
        let itemHeight = size.height * ratio

        var minValue: Float = maxYsArray.first?.floatValue ?? 0
        var minIndex: Int = 0
        for i in 0..<maxYsArray.count {
            let value = maxYsArray[i].floatValue
            if minValue >= value {
                minValue = value
                minIndex = i
            }
        }

        let itemX: CGFloat = sectionInset.left + (columSpacing + itemWidth) * CGFloat((itemForLine - minIndex) - 1)
        let itemY: CGFloat = CGFloat(minValue) + rowSpacing
        attributes.frame = CGRect(x: itemX, y: itemY, width: itemWidth, height: itemHeight)
        maxYsArray[minIndex] = NSNumber(value: Float(attributes.frame.maxY))

        return attributes
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return attributesArray
    }

    override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let supplementaryViewAttributes = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: elementKind, with: indexPath)
        return supplementaryViewAttributes
    }
}
