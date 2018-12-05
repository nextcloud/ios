//
//  MockActionSheetButton.swift
//  SheeeeeeeeetTests
//
//  Created by Daniel Saidi on 2018-10-17.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

import Sheeeeeeeeet

class MockActionSheetButton: ActionSheetButton {
    
    var applyAppearanceInvokeCount = 0
    var applyAppearanceInvokeAppearances = [ActionSheetAppearance]()
    
    override func applyAppearance(_ appearance: ActionSheetAppearance) {
        applyAppearanceInvokeCount += 1
        applyAppearanceInvokeAppearances.append(appearance)
    }
}
