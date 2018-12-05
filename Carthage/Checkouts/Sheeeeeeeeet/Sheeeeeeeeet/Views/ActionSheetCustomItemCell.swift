//
//  ActionSheetCustomItemCell.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2018-10-08.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

/*
 
 This protocol must be implemented by any cell that is to be
 used together with an `ActionSheetCustomItem`.
 
 */

import UIKit

public protocol ActionSheetCustomItemCell where Self: ActionSheetItemCell {
    
    static var nib: UINib { get }
    static var defaultSize: CGSize { get }
}
