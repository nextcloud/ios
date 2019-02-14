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
        
        var item: ActionSheetSectionTitle!
        
        describe("instance") {
            
            it("is correctly configured") {
                item = ActionSheetSectionTitle(title: "foo", subtitle: "bar")
                
                expect(item.title).to(equal("foo"))
                expect(item.subtitle).to(equal("bar"))
                expect(item.tapBehavior).to(equal(ActionSheetItem.TapBehavior.none))
            }
        }
        
        
        describe("cell") {
            
            it("is of correct type") {
                item = ActionSheetSectionTitle(title: "foo")
                let cell = item.cell(for: UITableView())
                
                expect(cell is ActionSheetSectionTitleCell).to(beTrue())
                expect(cell.reuseIdentifier).to(equal(item.cellReuseIdentifier))
            }
        }
    }
}
