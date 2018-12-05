//
//  ActionSheetTitleTests.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-26.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
import Sheeeeeeeeet

class ActionSheetTitleTests: QuickSpec {
    
    override func spec() {
        
        let item = ActionSheetTitle(title: "foo")
        
        describe("when created") {
            
            it("applies provided values") {
                expect(item.title).to(equal("foo"))
                expect(item.value).to(beNil())
                expect(item.image).to(beNil())
                expect(item.tapBehavior).to(equal(ActionSheetItem.TapBehavior.none))
            }
            
            it("applies non-provided values") {
                expect(item.tapBehavior).to(equal(ActionSheetItem.TapBehavior.none))
            }
        }
        
        describe("applying appearance to cell") {
            
            it("is correctly configures cell") {
                let cell = UITableViewCell()
                item.applyAppearance(to: cell)
                expect(cell.selectionStyle).to(equal(UITableViewCell.SelectionStyle.none))
                expect(cell.textLabel?.textAlignment).to(equal(NSTextAlignment.center))
            }
        }
    }
}
