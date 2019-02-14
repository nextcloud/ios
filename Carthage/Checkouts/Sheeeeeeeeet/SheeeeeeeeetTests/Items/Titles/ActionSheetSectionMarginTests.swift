//
//  ActionSheetSectionMarginTests.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-27.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
import Sheeeeeeeeet

class ActionSheetSectionMarginTests: QuickSpec {
    
    override func spec() {
        
        var item: ActionSheetSectionMargin!
        
        beforeEach {
            item = ActionSheetSectionMargin()
        }
        
        
        describe("instance") {
            
            it("is correctly configured") {
                expect(item.title).to(equal(""))
                expect(item.value).to(beNil())
                expect(item.image).to(beNil())
                expect(item.tapBehavior).to(equal(ActionSheetItem.TapBehavior.none))
            }
        }
        
        
        describe("cell") {
            
            it("is of correct type") {
                let cell = item.cell(for: UITableView())
                
                expect(cell is ActionSheetSectionMarginCell).to(beTrue())
                expect(cell.reuseIdentifier).to(equal(item.cellReuseIdentifier))
            }
        }
    }
}
