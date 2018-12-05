//
//  ActionSheetMultiSelectItem.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2018-03-31.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

/*
 
 `ActionSheetMultiSelectItem` should be used whenever a user
 should be able to select one or several items in a sheet. A
 multi select item will not affect other items, and will not
 dismiss the sheet.
 
 Multi-select items can be used in combination with a toggle
 item (`ActionSheetMultiSelectToggleItem`), which can toggle
 the selected state of all items in the same group.
 
 A multi-select item does not dismiss the sheet, since users
 will most probably be in a context where a change should be
 applied with an OK button.
 
 */

import UIKit

open class ActionSheetMultiSelectItem: ActionSheetSelectItem {
    
    
    // MARK: - Initialization
    
    public init(
        title: String,
        isSelected: Bool,
        group: String = "",
        value: Any? = nil,
        image: UIImage? = nil) {
        super.init(
            title: title,
            isSelected: isSelected,
            group: group,
            value: value,
            image: image,
            tapBehavior: .none)
    }
    
    
    // MARK: - Functions
    
    open override func applyAppearance(_ appearance: ActionSheetAppearance) {
        super.applyAppearance(appearance)
        self.appearance = ActionSheetMultiSelectItemAppearance(copy: appearance.multiSelectItem)
    }
    
    open override func handleTap(in actionSheet: ActionSheet) {
        super.handleTap(in: actionSheet)
        let toggleItems = actionSheet.items.compactMap { $0 as? ActionSheetMultiSelectToggleItem }
        let items = toggleItems.filter { $0.group == group }
        items.forEach { $0.updateState(for: actionSheet) }
    }
}
