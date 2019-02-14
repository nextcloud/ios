//
//  ActionSheetDangerButtonTests.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-27.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
import Sheeeeeeeeet

class ActionSheetDangerButtonTests: QuickSpec {
    
    override func spec() {
        
        var item: ActionSheetDangerButton!
        
        beforeEach {
            item = ActionSheetDangerButton(title: "danger")
        }
        
        
        describe("created instance") {
            
            it("is correctly setup") {
                expect(item.title).to(equal("danger"))
                expect(item.value as? ActionSheetButton.ButtonType).to(equal(.ok))
            }
        }
        
        
        describe("cell") {
            
            it("is of correct type") {
                let cell = item.cell(for: UITableView())
                
                expect(cell is ActionSheetDangerButtonCell).to(beTrue())
                expect(cell.reuseIdentifier).to(equal(item.cellReuseIdentifier))
            }
        }
    }
}
