//
//  ActionSheetButtonTests.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-26.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
import Sheeeeeeeeet

class ActionSheetButtonTests: QuickSpec {
    
    override func spec() {
        
        var item: ActionSheetButton!
        
        
        describe("when created with value") {
            
            it("is correctly setup") {
                item = ActionSheetButton(title: "foo", value: "bar")
                
                expect(item.title).to(equal("foo"))
                expect(item.value as? String).to(equal("bar"))
                expect(item.isOkButton).to(beFalse())
            }
        }
        
        
        describe("when created with button type") {
            
            it("is correctly setup") {
                item = ActionSheetButton(title: "foo", type: .ok)
                
                expect(item.title).to(equal("foo"))
                expect(item.value as? ActionSheetButton.ButtonType).to(equal(.ok))
            }
        }
        
        
        describe("cell") {
            
            it("is of correct type") {
                item = ActionSheetButton(title: "foo", type: .ok)
                let cell = item.cell(for: UITableView())
                
                expect(cell is ActionSheetButtonCell).to(beTrue())
                expect(cell.reuseIdentifier).to(equal(item.cellReuseIdentifier))
            }
        }
        
        
        describe("button type") {
            
            func createItem(type: ActionSheetButton.ButtonType) -> ActionSheetButton {
                return ActionSheetButton(title: "foo", type: type)
            }
            
            it("is correct for each button type") {
                expect(createItem(type: .cancel).isOkButton).to(beFalse())
                expect(createItem(type: .cancel).isCancelButton).to(beTrue())
                expect(createItem(type: .ok).isOkButton).to(beTrue())
                expect(createItem(type: .ok).isCancelButton).to(beFalse())
            }
        }
    }
}


class ActionSheetButtonCellTests: QuickSpec {
    
    override func spec() {
        
        describe("refreshing") {
            
            it("center aligns text label") {
                let item = ActionSheetButton(title: "", value: nil)
                let cell = item.cell(for: UITableView())
                cell.refresh()
                expect(cell.textLabel?.textAlignment).to(equal(.center))
            }
        }
    }
}
