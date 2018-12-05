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

class ActionSheetButtonTests: ActionSheetItemTests {
    
    override func spec() {
        
        var item: ActionSheetButton!
        
        beforeEach {
            item = ActionSheetButton(title: "foo", type: .ok)
            self.prepareStandardAppearance()
        }
        
        afterEach {
            self.restoreStandardAppearance()
        }
        
        describe("when created with value") {
            
            beforeEach {
                item = ActionSheetButton(title: "foo", value: "bar")
            }
            
            it("applies provided values") {
                expect(item.title).to(equal("foo"))
                expect(item.value as? String).to(equal("bar"))
            }
            
            it("is correctly setup") {
                expect(item.isOkButton).to(beFalse())
            }
        }
        
        describe("when created with type") {
            
            it("applies provided values") {
                expect(item.title).to(equal("foo"))
            }
            
            it("is correctly setup") {
                expect(item.value as? ActionSheetButton.ButtonType).to(equal(.ok))
                expect(item.isOkButton).to(beTrue())
            }
        }
        
        describe("applying appearance") {
            
            it("applies standard copy if no custom appearance is set") {
                item.applyAppearance(ActionSheetAppearance.standard)
                expect(self.compare(item.appearance, ActionSheetAppearance.standard.okButton)).to(beTrue())
            }
            
            it("applies custom appearance if set") {
                let standard = ActionSheetAppearance.standard
                let custom = ActionSheetAppearance(copy: standard)
                item.customAppearance = custom.okButton
                item.applyAppearance(standard)
                expect(item.appearance).to(be(custom.okButton))
            }
        }
        
        describe("applying appearance to cell") {
            
            it("applies correct style") {
                let appearance = ActionSheetAppearance.standard
                let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")
                item.applyAppearance(appearance)
                item.applyAppearance(to: cell)
                expect(self.compare(cell, item: item, appearance: appearance.okButton, textAlignment: .center)).to(beTrue())
            }
        }
    }
}
