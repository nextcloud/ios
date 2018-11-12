//
//  FoodOption+ActionSheetItems.swift
//  SheeeeeeeeetExample
//
//  Created by Jonas Ullström on 2018-03-16.
//  Copyright © 2018 Jonas Ullström. All rights reserved.
//

import Sheeeeeeeeet

extension FoodOption {
    
    func item() -> ActionSheetItem {
        return ActionSheetItem(
            title: displayName,
            value: self,
            image: image)
    }
    
    func linkItem() -> ActionSheetItem {
        return ActionSheetLinkItem(
            title: displayName,
            value: self,
            image: image)
    }
    
    func multiSelectItem(isSelected: Bool, group: String) -> ActionSheetItem {
        return ActionSheetMultiSelectItem(
            title: displayName,
            isSelected: isSelected,
            group: group,
            value: self,
            image: image)
    }
    
    func singleSelectItem(isSelected: Bool, group: String) -> ActionSheetItem {
        let item = ActionSheetSingleSelectItem(
            title: displayName,
            isSelected: isSelected,
            group: group,
            value: self,
            image: image)
        item.tapBehavior = .none
        return item
    }
}
