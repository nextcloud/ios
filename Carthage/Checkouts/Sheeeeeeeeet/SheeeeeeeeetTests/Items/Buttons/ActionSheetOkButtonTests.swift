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

class ActionSheetOkButtonTests: ActionSheetItemTests {
    
    override func spec() {
        
        let item = ActionSheetOkButton(title: "foo")
        
        describe("when created") {
            
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
    }
}
