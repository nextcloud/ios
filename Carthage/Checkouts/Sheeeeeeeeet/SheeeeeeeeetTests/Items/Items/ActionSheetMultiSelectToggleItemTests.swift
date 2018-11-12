//
//  ActionSheetMultiSelectToggleItemTests.swift
//  SheeeeeeeeetTests
//
//  Created by Daniel Saidi on 2018-03-31.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
import Sheeeeeeeeet

class ActionSheetMultiSelectToggleItemTests: QuickSpec {
    
    override func spec() {
        
        func getItem(group: String = "") -> ActionSheetMultiSelectToggleItem {
            return ActionSheetMultiSelectToggleItem(title: "foo", state: .selectAll, group: group, selectAllTitle: "select all", deselectAllTitle: "deselect all")
        }
        
        describe("when created") {
            
            it("applies provided values") {
                let item = getItem(group: "my group")
                expect(item.title).to(equal("foo"))
                expect(item.group).to(equal("my group"))
                expect(item.selectAllTitle).to(equal("select all"))
                expect(item.deselectAllTitle).to(equal("deselect all"))
            }
        }
        
        describe("cell style") {
            
            it("is value1") {
                expect(getItem().cellStyle).to(equal(UITableViewCell.CellStyle.value1))
            }
        }
        
        describe("tap behavior") {
            
            it("is none") {
                expect(getItem().tapBehavior).to(equal(ActionSheetItem.TapBehavior.none))
            }
        }
    }
}
