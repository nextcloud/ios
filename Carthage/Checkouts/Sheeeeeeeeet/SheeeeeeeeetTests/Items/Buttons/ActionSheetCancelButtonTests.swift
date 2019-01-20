//
//  ActionSheetCancelButtonTests.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-26.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
import Sheeeeeeeeet

class ActionSheetCancelButtonTests: QuickSpec {
    
    override func spec() {
        
        var item: ActionSheetCancelButton!
        
        beforeEach {
            item = ActionSheetCancelButton(title: "cancel")
        }
        
        
        describe("created instance") {
            
            it("is correctly setup") {
                expect(item.title).to(equal("cancel"))
                expect(item.value as? ActionSheetButton.ButtonType).to(equal(.cancel))
            }
        }
        
        
        describe("cell") {
            
            it("is of correct type") {
                let cell = item.cell(for: UITableView())
                
                expect(cell is ActionSheetCancelButtonCell).to(beTrue())
                expect(cell.reuseIdentifier).to(equal(item.cellReuseIdentifier))
            }
        }
    }
}
