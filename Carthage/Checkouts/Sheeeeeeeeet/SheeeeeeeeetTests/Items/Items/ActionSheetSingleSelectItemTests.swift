//
//  ActionSheetSingleSelectItemTests.swift
//  SheeeeeeeeetTests
//
//  Created by Daniel Saidi on 2018-03-12.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
import Sheeeeeeeeet

class ActionSheetSingleSelectItemTests: QuickSpec {
    
    override func spec() {
        
        describe("cell") {
            
            it("is of correct type") {
                let item = ActionSheetSingleSelectItem(title: "foo", isSelected: false)
                let cell = item.cell(for: UITableView())
                
                expect(cell is ActionSheetSingleSelectItemCell).to(beTrue())
                expect(cell.reuseIdentifier).to(equal(item.cellReuseIdentifier))
            }
        }
        
        
        describe("handling tap") {
            
            it("deselects other single select items in the same group") {
                let item1 = ActionSheetSingleSelectItem(title: "foo", isSelected: false, group: "group 1")
                let item2 = ActionSheetSingleSelectItem(title: "bar", isSelected: false, group: "group 2")
                let item3 = ActionSheetSingleSelectItem(title: "baz", isSelected: false, group: "group 1")
                let items = [item1, item2, item3]
                let sheet = ActionSheet(items: items) { (_, _) in }
                
                item1.handleTap(in: sheet)
                expect(item1.isSelected).to(beTrue())
                expect(item2.isSelected).to(beFalse())
                expect(item3.isSelected).to(beFalse())
                item2.handleTap(in: sheet)
                expect(item1.isSelected).to(beTrue())
                expect(item2.isSelected).to(beTrue())
                expect(item3.isSelected).to(beFalse())
                item3.handleTap(in: sheet)
                expect(item1.isSelected).to(beFalse())
                expect(item2.isSelected).to(beTrue())
                expect(item3.isSelected).to(beTrue())
            }
        }
    }
}
