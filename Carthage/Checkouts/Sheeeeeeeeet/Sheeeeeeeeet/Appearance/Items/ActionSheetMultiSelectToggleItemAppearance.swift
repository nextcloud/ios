//
//  ActionSheetMultiSelectToggleItemAppearance.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2018-03-31.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

import UIKit

open class ActionSheetMultiSelectToggleItemAppearance: ActionSheetItemAppearance {
    
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
    }
    
    public override init(copy: ActionSheetItemAppearance) {
        super.init(copy: copy)
        guard let copy = copy as? ActionSheetMultiSelectToggleItemAppearance else { return }
        deselectAllTextColor = copy.deselectAllTextColor
        selectAllTextColor = copy.selectAllTextColor
    }
    
    
    // MARK: - Properties
    
    public var deselectAllTextColor: UIColor?
    public var selectAllTextColor: UIColor?
}
