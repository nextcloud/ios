//
//  ActionSheetSingleSelectItem.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2018-03-12.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

/*
 
 `ActionSheetSingleSelectItem` should be used whenever users
 should only be able to select a single item in a sheet or a
 group. It automatically deselects other single select items
 in the same group. You can have several groups in one sheet.
 
 A single select item will dismiss the sheet when tapped. To
 change this behavior, set `tapBehavior` to `.none`.
 
 */

import UIKit

open class ActionSheetSingleSelectItem: ActionSheetSelectItem {
    
    
     // MARK: - Functions
    
    open override func applyAppearance(_ appearance: ActionSheetAppearance) {
        super.applyAppearance(appearance)
        self.appearance = ActionSheetSingleSelectItemAppearance(copy: appearance.singleSelectItem)
    }
    
    open override func handleTap(in actionSheet: ActionSheet) {
        super.handleTap(in: actionSheet)
        let items = actionSheet.items.compactMap { $0 as? ActionSheetSingleSelectItem }
        let deselectItems = items.filter { $0.group == group }
        deselectItems.forEach { $0.isSelected = false }
        isSelected = true
    }
}
