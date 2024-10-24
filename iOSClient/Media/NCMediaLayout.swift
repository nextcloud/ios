//
//  NCMediaLayout.swift
//
//  Created by Marino Faggiana on 26/02/24.
//  Based on CHTCollectionViewWaterfallLayout by Nelson Tai
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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

public let mediaSectionHeader = "mediaSectionHeader"
public let mediaSectionFooter = "mediaSectionFooter"

protocol NCMediaLayoutDelegate: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: IndexPath, columnCount: Int, typeLayout: String) -> CGSize
    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, heightForHeaderInSection section: Int) -> Float
    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, heightForFooterInSection section: Int) -> Float
    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, insetForSection section: Int) -> UIEdgeInsets
    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, insetForHeaderInSection section: Int) -> UIEdgeInsets
    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, insetForFooterInSection section: Int) -> UIEdgeInsets
    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, minimumInteritemSpacingForSection section: Int) -> Float
    func getLayout() -> String?
    func getColumnCount() -> Int
}

public class NCMediaLayout: UICollectionViewLayout {

    // MARK: - Private constants
    /// How many items to be union into a single rectangle
    private let unionSize = 20

    // MARK: - Public Properties
    public var columnCount: Int = 0 {
        didSet {
            invalidateIfNotEqual(oldValue, newValue: columnCount)
        }
    }
    public var minimumColumnSpacing: Float = 1.0 {
        didSet {
            invalidateIfNotEqual(oldValue, newValue: minimumColumnSpacing)
        }
    }
    public var minimumInteritemSpacing: Float = .zero {
        didSet {
            invalidateIfNotEqual(oldValue, newValue: minimumInteritemSpacing)
        }
    }
    public var headerHeight: Float = .zero {
        didSet {
            invalidateIfNotEqual(oldValue, newValue: headerHeight)
        }
    }
    public var footerHeight: Float = .zero {
        didSet {
            invalidateIfNotEqual(oldValue, newValue: footerHeight)
        }
    }
    public var headerInset: UIEdgeInsets = .zero {
        didSet {
            invalidateIfNotEqual(oldValue, newValue: headerInset)
        }
    }
    public var footerInset: UIEdgeInsets = .zero {
        didSet {
            invalidateIfNotEqual(oldValue, newValue: footerInset)
        }
    }
    public var sectionInset: UIEdgeInsets = .zero {
        didSet {
            invalidateIfNotEqual(oldValue, newValue: sectionInset)
        }
    }
    public override var collectionViewContentSize: CGSize {
        let numberOfSections = collectionView?.numberOfSections
        if numberOfSections == 0 {
            return CGSize.zero
        }
        var contentSize = collectionView?.bounds.size

        contentSize?.height = CGFloat(columnHeights[0])
        return contentSize!
    }
    public var frameWidth: Float = 0
    public var itemWidth: Float = 0

    // MARK: - Private Properties
    private weak var delegate: NCMediaLayoutDelegate? {
        return collectionView?.delegate as? NCMediaLayoutDelegate
    }
    private var columnHeights = [Float]()
    private var sectionItemAttributes = [[UICollectionViewLayoutAttributes]]()
    private var allItemAttributes = [UICollectionViewLayoutAttributes]()
    private var headersAttribute = [Int: UICollectionViewLayoutAttributes]()
    private var footersAttribute = [Int: UICollectionViewLayoutAttributes]()
    private var unionRects = [CGRect]()

    // MARK: - UICollectionViewLayout Methods
    public override func prepare() {
        super.prepare()

        guard let numberOfSections = collectionView?.numberOfSections,
              let collectionView = collectionView,
              let delegate = delegate else { return }

        columnCount = delegate.getColumnCount()
        (delegate as? NCMedia)?.buildMediaPhotoVideo(columnCount: columnCount)

        // Initialize variables
        headersAttribute.removeAll(keepingCapacity: false)
        footersAttribute.removeAll(keepingCapacity: false)
        unionRects.removeAll(keepingCapacity: false)
        columnHeights.removeAll(keepingCapacity: false)
        allItemAttributes.removeAll(keepingCapacity: false)
        sectionItemAttributes.removeAll(keepingCapacity: false)

        for _ in 0..<columnCount {
            self.columnHeights.append(0)
        }

        // Create attributes
        var top: Float = 0
        var attributes: UICollectionViewLayoutAttributes

        for section in 0..<numberOfSections {
            /*
            * 1. Get section-specific metrics (minimumInteritemSpacing, sectionInset)
            */
            let minimumInteritemSpacing: Float = delegate.collectionView(collectionView, layout: self, minimumInteritemSpacingForSection: section)
            let sectionInset: UIEdgeInsets = delegate.collectionView(collectionView, layout: self, insetForSection: section)
            frameWidth = Float(collectionView.frame.size.width - sectionInset.left - sectionInset.right)
            itemWidth = ((frameWidth - Float(columnCount - 1) * Float(minimumColumnSpacing)) / Float(columnCount))

            /*
            * 2. Section header
            */
            let headerHeight: Float = delegate.collectionView(collectionView, layout: self, heightForHeaderInSection: section)
            let headerInset: UIEdgeInsets = delegate.collectionView(collectionView, layout: self, insetForHeaderInSection: section)

            top += Float(headerInset.top)

            if headerHeight > 0 {
                attributes = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: mediaSectionHeader, with: NSIndexPath(item: 0, section: section) as IndexPath)
                attributes.frame = CGRect(x: headerInset.left, y: CGFloat(top), width: collectionView.frame.size.width - (headerInset.left + headerInset.right), height: CGFloat(headerHeight))

                headersAttribute[section] = attributes
                allItemAttributes.append(attributes)

                top = Float(attributes.frame.maxY) + Float(headerInset.bottom)
            }

            top += Float(sectionInset.top)
            for idx in 0..<columnCount {
                columnHeights[idx] = top
            }

            /*
            * 3. Section items
            */
            let itemCount = collectionView.numberOfItems(inSection: section)
            var itemAttributes = [UICollectionViewLayoutAttributes]()

            // Item will be put into shortest column.
            for idx in 0..<itemCount {
                let indexPath = IndexPath(item: idx, section: section)
                let columnIndex = shortestColumnIndex()

                let xOffset = Float(sectionInset.left) + Float(itemWidth + minimumColumnSpacing) * Float(columnIndex)
                let yOffset = columnHeights[columnIndex]
                let typeLayout = delegate.getLayout() ?? NCGlobal.shared.mediaLayoutRatio
                let itemSize = delegate.collectionView(collectionView, layout: self, sizeForItemAtIndexPath: indexPath, columnCount: self.columnCount, typeLayout: typeLayout)
                var itemHeight: Float = 0.0
                if itemSize.height > 0 && itemSize.width > 0 {
                    itemHeight = Float(itemSize.height) * itemWidth / Float(itemSize.width)
                }

                attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath as IndexPath)
                attributes.frame = CGRect(x: CGFloat(xOffset), y: CGFloat(yOffset), width: CGFloat(itemWidth), height: CGFloat(itemHeight))
                itemAttributes.append(attributes)
                allItemAttributes.append(attributes)
                columnHeights[columnIndex] = Float(attributes.frame.maxY) + minimumInteritemSpacing
            }

            sectionItemAttributes.append(itemAttributes)

            /*
            * 4. Section footer
            */
            let columnIndex = longestColumnIndex()
            top = columnHeights[columnIndex] - minimumInteritemSpacing + Float(sectionInset.bottom)
            top += Float(footerInset.top)
            let footerHeight = delegate.collectionView(collectionView, layout: self, heightForFooterInSection: section)

            if footerHeight > 0 {
                attributes = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: mediaSectionFooter, with: NSIndexPath(item: 0, section: section) as IndexPath)
                attributes.frame = CGRect(x: footerInset.left, y: CGFloat(top), width: collectionView.frame.size.width - (footerInset.left + footerInset.right), height: CGFloat(footerHeight))

                footersAttribute[section] = attributes
                allItemAttributes.append(attributes)

                top = Float(attributes.frame.maxY) + Float(footerInset.bottom)
            }

            for idx in 0..<columnCount {
                columnHeights[idx] = top
            }
        }

        // Build union rects
        var idx = 0
        let itemCounts = allItemAttributes.count

        while idx < itemCounts {
            let rect1 = allItemAttributes[idx].frame
            idx = min(idx + unionSize, itemCounts) - 1
            let rect2 = allItemAttributes[idx].frame
            unionRects.append(rect1.union(rect2))
            idx += 1
        }
    }

    public override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        if indexPath.section >= sectionItemAttributes.count {
            return nil
        }

        if indexPath.item >= sectionItemAttributes[indexPath.section].count {
            return nil
        }

        return sectionItemAttributes[indexPath.section][indexPath.item]
    }

    public override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        var attribute: UICollectionViewLayoutAttributes?

        if elementKind == mediaSectionHeader {
            attribute = headersAttribute[indexPath.section]
        } else if elementKind == mediaSectionFooter {
            attribute = footersAttribute[indexPath.section]
        }

        return attribute
    }

    public override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var begin: Int = 0
        var end: Int = unionRects.count
        var attrs = [UICollectionViewLayoutAttributes]()

        for i in 0..<unionRects.count {
            if rect.intersects(unionRects[i]) {
                begin = i * unionSize
                break
            }
        }
        for i in (0..<unionRects.count).reversed() {
            if rect.intersects(unionRects[i]) {
                end = min((i + 1) * unionSize, allItemAttributes.count)
                break
            }
        }
        for i in begin..<end {
            let attr = allItemAttributes[i]
            if rect.intersects(attr.frame) {
                attrs.append(attr)
            }
        }

        return Array(attrs)
    }

    public override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        let oldBounds = collectionView?.bounds
        if newBounds.width != oldBounds?.width {
            return true
        }

        return false
    }
}

// MARK: - Private Methods
extension NCMediaLayout {
    func shortestColumnIndex() -> Int {
        var index: Int = 0
        var shortestHeight = MAXFLOAT

        for (idx, height) in columnHeights.enumerated() {
            if height < shortestHeight {
                shortestHeight = height
                index = idx
            }
        }

        return index
    }

    func longestColumnIndex() -> Int {
        var index: Int = 0
        var longestHeight: Float = 0
        for (idx, height) in columnHeights.enumerated() {
            if height > longestHeight {
                longestHeight = height
                index = idx
            }
        }
        return index
    }

    func invalidateIfNotEqual<T: Equatable>(_ oldValue: T, newValue: T) {
        if oldValue != newValue {
            invalidateLayout()
        }
    }
}
