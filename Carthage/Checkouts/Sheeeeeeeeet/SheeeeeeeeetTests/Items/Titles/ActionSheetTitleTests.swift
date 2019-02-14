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
        
        var item: ActionSheetTitle!
        
        describe("instance") {
            
            it("is correctly configured") {
                item = ActionSheetTitle(title: "foo")
                
                expect(item.title).to(equal("foo"))
                expect(item.tapBehavior).to(equal(ActionSheetItem.TapBehavior.none))
            }
        }
        
        
        describe("cell") {
            
            it("is of correct type") {
                item = ActionSheetTitle(title: "foo")
                let cell = item.cell(for: UITableView())
                
                expect(cell is ActionSheetTitleCell).to(beTrue())
                expect(cell.reuseIdentifier).to(equal(item.cellReuseIdentifier))
            }
        }
    }
}
