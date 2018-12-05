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
        
        func getItem(isSelected: Bool, group: String = "") -> ActionSheetMultiSelectItem {
            return ActionSheetMultiSelectItem(title: "foo", isSelected: isSelected, group: group, value: true, image: UIImage())
        }
        
        describe("when created") {
            
            it("applies provided values") {
                let item = getItem(isSelected: true, group: "my group")
                expect(item.title).to(equal("foo"))
                expect(item.group).to(equal("my group"))
                expect(item.value as? Bool).to(equal(true))
                expect(item.image).toNot(beNil())
            }
            
            it("applies provided selection state") {
                expect(getItem(isSelected: true).isSelected).to(beTrue())
                expect(getItem(isSelected: false).isSelected).to(beFalse())
            }
        }
        
        describe("tap behavior") {
            
            it("is none") {
                let item = getItem(isSelected: true)
                expect(item.tapBehavior).to(equal(ActionSheetItem.TapBehavior.none))
            }
        }
    }
}
