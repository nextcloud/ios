//
//  ActionSheetSelectItemAppearance.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-24.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

/*
 
 This appearance inherits the base appearance and applies to
 select items. The additional properties are applied when an
 item is selected:
 
 * `selectedIcon` is displayed rightmost, e.g. a checkmark
 * `selectedTextColor` is applied to the text (duh)
 * `selectedTintColor` is applied to both icons if they are rendered as template images
 * `selectedIconTintColor` can override `selectedTintColor` for the selected icon
 
 */

import UIKit

open class ActionSheetSelectItemAppearance: ActionSheetItemAppearance {
    
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
    }
    
    public override init(copy: ActionSheetItemAppearance) {
        super.init(copy: copy)
        selectedTextColor = copy.textColor
        selectedTintColor = copy.tintColor
        guard let copy = copy as? ActionSheetSelectItemAppearance else { return }
        selectedIcon = copy.selectedIcon
        selectedTextColor = copy.selectedTextColor ?? selectedTextColor
        selectedTintColor = copy.selectedTintColor ?? selectedTintColor
        selectedIconTintColor = copy.selectedIconTintColor ?? selectedTintColor
    }
    
    
    // MARK: - Properties
    
    public var selectedIcon: UIImage?
    public var selectedIconTintColor: UIColor?
    public var selectedTextColor: UIColor?
    public var selectedTintColor: UIColor?
}
