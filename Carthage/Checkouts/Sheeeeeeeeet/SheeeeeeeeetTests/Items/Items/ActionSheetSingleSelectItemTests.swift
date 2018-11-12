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
        
        func getItem(isSelected: Bool = false, group: String = "") -> ActionSheetSingleSelectItem {
            return ActionSheetSingleSelectItem(title: "foo", isSelected: isSelected, group: group, value: true, image: UIImage())
        }
        
        describe("when created") {
            
            it("applies provided values") {
                let item = ActionSheetSingleSelectItem(title: "foo", isSelected: true, group: "my group", value: true, image: UIImage(), tapBehavior: .none)
                expect(item.title).to(equal("foo"))
                expect(item.isSelected).to(beTrue())
                expect(item.group).to(equal("my group"))
                expect(item.value as? Bool).to(equal(true))
                expect(item.image).toNot(beNil())
                expect(item.tapBehavior).to(equal(ActionSheetItem.TapBehavior.none))
            }
            
            it("applies provided selection state") {
                expect(getItem(isSelected: true).isSelected).to(beTrue())
                expect(getItem(isSelected: false).isSelected).to(beFalse())
            }
        }
        
        describe("tap behavior") {
            
            it("is dismiss by default") {
                let item = getItem()
                expect(item.tapBehavior).to(equal(ActionSheetItem.TapBehavior.dismiss))
            }
        }
        
        describe("when tapped") {
            
            var sheet: ActionSheet!
            
            beforeEach {
                sheet = ActionSheet(items: [
                    getItem(isSelected: true, group: "foo"),
                    getItem(isSelected: false, group: "foo"),
                    getItem(isSelected: true, group: "bar"),
                    getItem(isSelected: false, group: "bar"),
                    getItem(isSelected: true, group: "baz"),
                    getItem(isSelected: false, group: "baz")
                    ], action: { _, _ in })
            }
            
            it("selects unselected item") {
                let item = getItem(isSelected: false)
                item.handleTap(in: sheet)
                expect(item.isSelected).to(beTrue())
            }
            
            it("does not deselect selected item") {
                let item = getItem(isSelected: true)
                item.handleTap(in: sheet)
                expect(item.isSelected).to(beTrue())
            }
            
            it("does not affect sheet items in other groups") {
                let item = getItem(isSelected: false, group: "baz")
                item.handleTap(in: sheet)
                let items = sheet.items.compactMap { $0 as? ActionSheetSingleSelectItem }
                expect(items[0].isSelected).to(beTrue())
                expect(items[1].isSelected).to(beFalse())
                expect(items[2].isSelected).to(beTrue())
                expect(items[3].isSelected).to(beFalse())
                expect(items[4].isSelected).to(beFalse())
                expect(items[5].isSelected).to(beFalse())
            }
        }
    }
}
