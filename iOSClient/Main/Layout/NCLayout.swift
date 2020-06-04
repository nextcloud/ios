//
//  NCLayout.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 05/11/2018.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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

import Foundation

class NCListLayout: UICollectionViewFlowLayout {
    
    let itemHeight: CGFloat = 60
    
    override init() {
        super.init()
        
        sectionHeadersPinToVisibleBounds = false
        
        minimumInteritemSpacing = 0
        minimumLineSpacing = 1
        
        self.scrollDirection = .vertical
        self.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var itemSize: CGSize {
        get {
            if let collectionView = collectionView {
                let itemWidth: CGFloat = collectionView.frame.width
                return CGSize(width: itemWidth, height: self.itemHeight)
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

class NCGridLayout: UICollectionViewFlowLayout {
    
    var heightLabelPlusButton: CGFloat = 45
    var preferenceWidth: CGFloat = 110
    var marginLeftRight: CGFloat = 1
    var numItems: Int = 0
    
    override init() {
        super.init()
        
        sectionHeadersPinToVisibleBounds = false
        
        minimumInteritemSpacing = 1
        minimumLineSpacing = 1
        
        self.scrollDirection = .vertical
        self.sectionInset = UIEdgeInsets(top: 10, left: marginLeftRight, bottom: 0, right:  marginLeftRight)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var itemSize: CGSize {
        get {
            if let collectionView = collectionView {
                
                self.numItems = Int(collectionView.frame.width / preferenceWidth)
                let itemWidth: CGFloat = (collectionView.frame.width - (marginLeftRight * 2) - CGFloat(numItems)) / CGFloat(numItems)
                let itemHeight: CGFloat = itemWidth + heightLabelPlusButton
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

class NCGridMediaLayout: UICollectionViewFlowLayout {
    
    var increasing = true
    var itemPerLine: CGFloat = 3
    var marginLeftRight: CGFloat = 6
    var numItems: Int = 0
    
    override init() {
        super.init()
        
        sectionHeadersPinToVisibleBounds = false
        
        minimumInteritemSpacing = 0
        minimumLineSpacing = marginLeftRight
        
        self.scrollDirection = .vertical
        self.sectionInset = UIEdgeInsets(top: 0, left: marginLeftRight, bottom: 0, right:  marginLeftRight)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var itemSize: CGSize {
        get {
            if let collectionView = collectionView {
                
                let itemWidth: CGFloat = (collectionView.frame.width - marginLeftRight * 2 - marginLeftRight * (itemPerLine - 1)) / itemPerLine
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
extension UICollectionView {

var centerPoint : CGPoint {

    get {
        return CGPoint(x: self.center.x + self.contentOffset.x, y: self.center.y + self.contentOffset.y);
    }
}

var centerCellIndexPath: IndexPath? {

    if let centerIndexPath: IndexPath  = self.indexPathForItem(at: self.centerPoint) {
        return centerIndexPath
    }
    return nil
}
}
