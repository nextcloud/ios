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
        
        func createItem(group: String) -> ActionSheetMultiSelectToggleItem {
            return ActionSheetMultiSelectToggleItem(title: "foo", state: .selectAll, group: group, selectAllTitle: "select all", deselectAllTitle: "deselect all")
        }
        
        describe("instance") {
            
            it("can be created with custom values") {
                let item = createItem(group: "group")
                expect(item.title).to(equal("foo"))
                expect(item.state).to(equal(.selectAll))
                expect(item.group).to(equal("group"))
                expect(item.value).to(beNil())
                expect(item.selectAllTitle).to(equal("select all"))
                expect(item.deselectAllTitle).to(equal("deselect all"))
                expect(item.tapBehavior).to(equal(ActionSheetItem.TapBehavior.none))
            }
        }
        
    
        describe("cell") {
            
            it("is of correct type") {
                let item = createItem(group: "group")
                let cell = item.cell(for: UITableView())
                
                expect(cell is ActionSheetMultiSelectToggleItemCell).to(beTrue())
                expect(cell.reuseIdentifier).to(equal(item.cellReuseIdentifier))
            }
        }
        
        
        describe("handling tap") {
            
            var sheet: ActionSheet!
            var item1: ActionSheetMultiSelectItem!
            var item2: ActionSheetMultiSelectItem!
            var item3: ActionSheetMultiSelectItem!
            var toggle1: ActionSheetMultiSelectToggleItem!
            var toggle2: ActionSheetMultiSelectToggleItem!
            
            beforeEach {
                item1 = ActionSheetMultiSelectItem(title: "foo", isSelected: false, group: "group 1")
                item2 = ActionSheetMultiSelectItem(title: "bar", isSelected: false, group: "group 2")
                item3 = ActionSheetMultiSelectItem(title: "baz", isSelected: false, group: "group 1")
                toggle1 = createItem(group: "group 1")
                toggle2 = createItem(group: "group 3")
                sheet = ActionSheet(items: [item1, item2, item3, toggle1, toggle2]) { (_, _) in }
            }
            
            it("resets state if no matching items exist in sheet") {
                toggle2.state = .deselectAll
                toggle2.handleTap(in: sheet)
                expect(toggle2.state).to(equal(.selectAll))
            }
            
            it("toggles select items in the same group") {
                toggle1.handleTap(in: sheet)
                expect(item1.isSelected).to(beTrue())
                expect(item2.isSelected).to(beFalse())
                expect(item3.isSelected).to(beTrue())
                expect(toggle1.state).to(equal(.deselectAll))
                expect(toggle2.state).to(equal(.selectAll))
                toggle1.handleTap(in: sheet)
                expect(item1.isSelected).to(beFalse())
                expect(item2.isSelected).to(beFalse())
                expect(item3.isSelected).to(beFalse())
                expect(toggle1.state).to(equal(.selectAll))
                expect(toggle2.state).to(equal(.selectAll))
                toggle2.handleTap(in: sheet)
                expect(item1.isSelected).to(beFalse())
                expect(item2.isSelected).to(beFalse())
                expect(item3.isSelected).to(beFalse())
                expect(toggle1.state).to(equal(.selectAll))
                expect(toggle2.state).to(equal(.selectAll))
            }
        }
    }
}
