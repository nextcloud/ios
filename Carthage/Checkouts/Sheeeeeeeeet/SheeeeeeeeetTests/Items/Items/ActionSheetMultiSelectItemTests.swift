//
//  ActionSheetMultiSelectItemTests.swift
//  SheeeeeeeeetTests
//
//  Created by Daniel Saidi on 2018-03-12.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
import Sheeeeeeeeet

class ActionSheetMultiSelectItemTests: QuickSpec {
    
    override func spec() {
        
        describe("instance") {
            
            it("can be created with default values") {
                let item = ActionSheetMultiSelectItem(title: "foo", isSelected: false)
                expect(item.title).to(equal("foo"))
                expect(item.isSelected).to(beFalse())
                expect(item.group).to(equal(""))
                expect(item.value).to(beNil())
                expect(item.image).to(beNil())
                expect(item.tapBehavior).to(equal(ActionSheetItem.TapBehavior.none))
            }
            
            it("can be created with custom values") {
                let item = ActionSheetMultiSelectItem(title: "foo", isSelected: true, group: "group", value: true, image: UIImage())
                expect(item.title).to(equal("foo"))
                expect(item.isSelected).to(beTrue())
                expect(item.group).to(equal("group"))
                expect(item.value as? Bool).to(equal(true))
                expect(item.image).toNot(beNil())
                expect(item.tapBehavior).to(equal(ActionSheetItem.TapBehavior.none))
            }
        }
        
        
        describe("cell") {
            
            it("is of correct type") {
                let item = ActionSheetMultiSelectItem(title: "foo", isSelected: false)
                let cell = item.cell(for: UITableView())
                
                expect(cell is ActionSheetMultiSelectItemCell).to(beTrue())
                expect(cell.reuseIdentifier).to(equal(item.cellReuseIdentifier))
            }
        }
        
        
        describe("handling tap") {
            
            it("updates toggle item in the same group") {
                let item1 = ActionSheetMultiSelectItem(title: "foo", isSelected: false, group: "group 1")
                let item2 = ActionSheetMultiSelectItem(title: "bar", isSelected: false, group: "group 2")
                let item3 = ActionSheetMultiSelectItem(title: "baz", isSelected: false, group: "group 1")
                let toggle1 = ActionSheetMultiSelectToggleItem(title: "toggle 1", state: .selectAll, group: "group 1", selectAllTitle: "", deselectAllTitle: "")
                let toggle2 = ActionSheetMultiSelectToggleItem(title: "toggle 2", state: .selectAll, group: "group 2", selectAllTitle: "", deselectAllTitle: "")
                let items = [item1, item2, item3, toggle1, toggle2]
                let sheet = ActionSheet(items: items) { (_, _) in }
                
                item1.handleTap(in: sheet)
                expect(toggle1.state).to(equal(.selectAll))
                expect(toggle2.state).to(equal(.selectAll))
                item2.handleTap(in: sheet)
                expect(toggle1.state).to(equal(.selectAll))
                expect(toggle2.state).to(equal(.deselectAll))
                item3.handleTap(in: sheet)
                expect(toggle1.state).to(equal(.deselectAll))
                expect(toggle2.state).to(equal(.deselectAll))
            }
        }
    }
}
