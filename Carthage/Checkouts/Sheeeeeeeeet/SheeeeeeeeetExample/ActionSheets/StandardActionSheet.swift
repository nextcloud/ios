//
//  StandardActionSheet.swift
//  SheeeeeeeeetExample
//
//  Created by Jonas Ullström on 2018-03-16.
//  Copyright © 2018 Jonas Ullström. All rights reserved.
//

import Sheeeeeeeeet

class StandardActionSheet: ActionSheet {
    
    init(options: [FoodOption], action: @escaping ([ActionSheetItem]) -> ()) {
        let items = StandardActionSheet.items(for: options)
        super.init(items: items) { _, item in
            if item.value == nil { return }
            action([item])
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

private extension StandardActionSheet {
    
    static func items(for options: [FoodOption]) -> [ActionSheetItem] {
        var items = options.map { $0.item() }
        items.insert(titleItem(title: standardTitle), at: 0)
        items.append(cancelButton)
        return items
    }
}
