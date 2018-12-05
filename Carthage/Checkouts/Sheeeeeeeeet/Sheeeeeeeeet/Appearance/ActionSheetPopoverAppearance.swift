//
//  ActionSheetPopoverAppearance.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-24.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

import UIKit

open class ActionSheetPopoverAppearance {
    
    
    // MARK: - Initialization
    
    public init(width: CGFloat) {
        self.width = width
    }
    
    public init(copy: ActionSheetPopoverAppearance) {
        self.width = copy.width
    }
    
    
    // MARK: - Properties
    
    public var width: CGFloat
}
