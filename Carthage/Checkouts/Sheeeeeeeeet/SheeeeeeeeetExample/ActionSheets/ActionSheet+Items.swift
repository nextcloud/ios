//
//  ActionSheet+Items.swift
//  SheeeeeeeeetExample
//
//  Created by Jonas Ullström on 2018-03-16.
//  Copyright © 2018 Jonas Ullström. All rights reserved.
//

/*
 
 These extensions provides action sheets with functions that
 are shared by all example action sheets.
 
 */

import Sheeeeeeeeet

extension ActionSheet {
    
    static var cancelButton: ActionSheetCancelButton {
        return ActionSheetCancelButton(title: "Cancel")
    }
    
    static var okButton: ActionSheetOkButton {
        return ActionSheetOkButton(title: "OK")
    }
    
    static var standardTitle: String {
        return "What do you want to eat?"
    }
    
    static func titleItem(title: String) -> ActionSheetTitle {
        return ActionSheetTitle(title: title)
    }
}
