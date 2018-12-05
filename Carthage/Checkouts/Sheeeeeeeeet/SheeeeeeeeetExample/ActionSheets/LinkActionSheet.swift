//
//  LinkActionSheet.swift
//  SheeeeeeeeetExample
//
//  Created by Jonas Ullström on 2018-03-16.
//  Copyright © 2018 Jonas Ullström. All rights reserved.
//

import Sheeeeeeeeet

class LinkActionSheet: ActionSheet {
    
    init(options: [FoodOption], action: @escaping ([ActionSheetItem]) -> ()) {
        let items = LinkActionSheet.items(for: options)
        super.init(items: items) { _, item in
            if item.value == nil { return }
            action([item])
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

private extension LinkActionSheet {
    
    static func items(for options: [FoodOption]) -> [ActionSheetItem] {
        var items = options.map { $0.linkItem() }
        items.insert(titleItem(title: standardTitle), at: 0)
        items.append(cancelButton)
        return items
    }
}
