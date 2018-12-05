//
//  SectionActionSheet.swift
//  SheeeeeeeeetExample
//
//  Created by Jonas Ullström on 2018-03-16.
//  Copyright © 2018 Jonas Ullström. All rights reserved.
//

import Sheeeeeeeeet

class SectionActionSheet: ActionSheet {
    
    init(options: [FoodOption], action: @escaping ([ActionSheetItem]) -> ()) {
        let items = SectionActionSheet.items(for: options)
        super.init(items: items) { _, item in
            if item.value == nil { return }
            action([item])
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

private extension SectionActionSheet {
    
    static func items(for options: [FoodOption]) -> [ActionSheetItem] {
        var items = [ActionSheetItem]()
        items.append(titleItem(title: standardTitle))
        items.append(ActionSheetSectionTitle(title: "Cheap"))
        let cheap = options.filter { $0.isCheap }.map { $0.item() }
        cheap.forEach { items.append($0) }
        items.append(ActionSheetSectionMargin())
        items.append(ActionSheetSectionTitle(title: "Expensive"))
        let expensive = options.filter { !$0.isCheap }.map { $0.item() }
        expensive.forEach { items.append($0) }
        items.append(cancelButton)
        return items
    }
}
