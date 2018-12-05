//
//  MultiSelectActionSheet.swift
//  SheeeeeeeeetExample
//
//  Created by Jonas Ullström on 2018-03-16.
//  Copyright © 2018 Jonas Ullström. All rights reserved.
//

import Sheeeeeeeeet

class SingleSelectActionSheet: ActionSheet {
    
    init(options: [FoodOption], preselected: [FoodOption], action: @escaping ([ActionSheetItem]) -> ()) {
        let items = SingleSelectActionSheet.items(for: options, preselected: preselected)
        super.init(items: items) { sheet, item in
            guard item.isOkButton else { return }
            let selectItems = sheet.items.compactMap { $0 as? ActionSheetSelectItem }
            let selectedItems = selectItems.filter { $0.isSelected }
            action(selectedItems)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

private extension SingleSelectActionSheet {
    
    static func items(for options: [FoodOption], preselected: [FoodOption]) -> [ActionSheetItem] {
        var items = [ActionSheetItem]()
        items.append(titleItem(title: standardTitle))
        items.append(contentsOf: itemsGroup(for: options, preselected: .fast, group: "Appetizer"))
        items.append(ActionSheetSectionMargin())
        items.append(contentsOf: itemsGroup(for: options, preselected: .homeMade, group: "Main Dish"))
        items.append(okButton)
        items.append(cancelButton)
        return items
    }
    
    static func itemsGroup(for options: [FoodOption], preselected: FoodOption?, group: String) -> [ActionSheetItem] {
        var items = [ActionSheetItem]()
        let options = options.filter { $0 != .none && $0 != .fancy }
        let foodItems = options.map { $0.singleSelectItem(isSelected: $0 == preselected, group: group) }
        items.append(ActionSheetSectionTitle(title: group))
        items.append(contentsOf: foodItems)
        return items
    }
}
