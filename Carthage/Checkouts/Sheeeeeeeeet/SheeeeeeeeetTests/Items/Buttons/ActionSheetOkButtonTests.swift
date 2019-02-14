//
//  ActionSheetOkButtonTests.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-26.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
import Sheeeeeeeeet

class ActionSheetOkButtonTests: QuickSpec {
    
    override func spec() {
        
        var item: ActionSheetOkButton!
        
        beforeEach {
            item = ActionSheetOkButton(title: "ok")
        }
        
        
        describe("created instance") {
            
            it("is correctly setup") {
                expect(item.title).to(equal("ok"))
                expect(item.value as? ActionSheetButton.ButtonType).to(equal(.ok))
            }
        }
        
        
        describe("cell") {
            
            it("is of correct type") {
                let cell = item.cell(for: UITableView())
                
                expect(cell is ActionSheetOkButtonCell).to(beTrue())
                expect(cell.reuseIdentifier).to(equal(item.cellReuseIdentifier))
            }
        }
    }
}
