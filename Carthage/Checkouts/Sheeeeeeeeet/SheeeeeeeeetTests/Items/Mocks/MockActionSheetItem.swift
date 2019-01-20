//
//  MockActionSheetItem.swift
//  SheeeeeeeeetTests
//
//  Created by Daniel Saidi on 2018-10-17.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

import Sheeeeeeeeet

class MockActionSheetItem: ActionSheetItem {
    
    var handleTapInvokeCount = 0
    var handleTapInvokeActionSheets = [ActionSheet]()
    
    var cell: ActionSheetItemCell?
    
    override func handleTap(in actionSheet: ActionSheet) {
        super.handleTap(in: actionSheet)
        handleTapInvokeCount += 1
        handleTapInvokeActionSheets.append(actionSheet)
    }
    
    override func cell(for tableView: UITableView) -> ActionSheetItemCell {
        return cell ?? super.cell(for: tableView)
    }
}
