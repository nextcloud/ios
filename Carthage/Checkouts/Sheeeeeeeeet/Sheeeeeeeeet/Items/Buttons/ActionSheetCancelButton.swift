//
//  ActionSheetCancelButton.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-26.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

/*
 
 Cancel buttons have no special behavior, but can be used in
 sheets where a user applies changes by tapping an OK button.
 
 The value of a cancel button is `ButtonType.cancel`.
 
 */

import UIKit

open class ActionSheetCancelButton: ActionSheetButton {
    
    
    // MARK: - Initialization
    
    public init(title: String) {
        super.init(title: title, type: .cancel)
    }
    
    
    // MARK: - Functions
    
    open override func applyAppearance(_ appearance: ActionSheetAppearance) {
        self.appearance = customAppearance ?? ActionSheetCancelButtonAppearance(copy: appearance.cancelButton)
    }
}
