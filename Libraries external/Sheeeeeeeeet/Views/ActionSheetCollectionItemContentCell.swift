//
//  ActionSheetCollectionItemContentCell.swift
//  Sheeeeeeeeet
//
//  Created by Jonas Ullström (ullstrm) on 2018-03-01.
//  Copyright © 2018 Jonas Ullström. All rights reserved.
//

/*
 
 This protocol must be implemented by any cell that is to be
 used together with an `ActionSheetCollectionItem`.
 
 */

import UIKit

public protocol ActionSheetCollectionItemContentCell where Self: UICollectionViewCell {
    
    static var nib: UINib { get }
    static var defaultSize: CGSize { get }
    static var leftInset: CGFloat { get }
    static var rightInset: CGFloat { get }
    static var topInset: CGFloat { get }
    static var bottomInset: CGFloat { get }
    static var itemSpacing: CGFloat { get }
}
