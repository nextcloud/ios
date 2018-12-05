//
//  ActionSheetSectionTitleTests.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-26.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
import Sheeeeeeeeet

class ActionSheetSectionTitleTests: QuickSpec {
    
    override func spec() {
        
        let item = ActionSheetSectionTitle(title: "foo", subtitle: "bar")
        
        describe("when created") {
            
            it("applies provided values") {
                expect(item.title).to(equal("foo"))
                expect(item.subtitle).to(equal("bar"))
                expect(item.value).to(beNil())
                expect(item.image).to(beNil())
            }
            
            it("applies non-provided values") {
                expect(item.cellStyle).to(equal(UITableViewCell.CellStyle.value1))
                expect(item.tapBehavior).to(equal(ActionSheetItem.TapBehavior.none))
            }
        }
        
        describe("applying appearance to cell") {
            
            it("is correctly configures cell") {
                let cell = UITableViewCell()
                item.applyAppearance(to: cell)
                expect(cell.selectionStyle).to(equal(UITableViewCell.SelectionStyle.none))
            }
        }
    }
}
