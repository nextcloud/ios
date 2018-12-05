//
//  ActionSheetSectionMarginAppearance.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-27.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

import Foundation

open class ActionSheetSectionMarginAppearance: ActionSheetItemAppearance {
    
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
        hideSeparator()
    }
    
    public override init(copy: ActionSheetItemAppearance) {
        super.init(copy: copy)
        hideSeparator()
    }
}
