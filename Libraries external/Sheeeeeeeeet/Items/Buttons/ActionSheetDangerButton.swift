//
//  ActionSheetDangerButton.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-27.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

/*
 
 Danger buttons have no special behavior, but can be used to
 indicate that the effect of the action sheet is destructive.
 
 The value of a danger button is `true` by default.
 
 */

import UIKit

open class ActionSheetDangerButton: ActionSheetButton {
    
    
    // MARK: - Initialization
    
    public init(title: String) {
        super.init(title: title, value: true)
    }
    
    
    // MARK: - Functions
    
    open override func applyAppearance(_ appearance: ActionSheetAppearance) {
        self.appearance = ActionSheetDangerButtonAppearance(copy: appearance.dangerButton)
    }
}
