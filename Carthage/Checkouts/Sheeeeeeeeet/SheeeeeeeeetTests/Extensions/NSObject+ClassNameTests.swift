//
//  NSObject+ClassNameTests.swift
//  SheeeeeeeeetTests
//
//  Created by Daniel Saidi on 2018-10-17.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
@testable import Sheeeeeeeeet

class NSObject_ClassNameTests: QuickSpec {
    
    override func spec() {
        
        describe("class name") {
            
            it("is valid for base type") {
                expect(ActionSheet.className).to(equal("ActionSheet"))
            }
            
            it("is valid for base type instance") {
                let obj = ActionSheet(items: []) { _, _ in }
                expect(obj.className).to(equal("ActionSheet"))
            }
            
            it("is valid for inherited type") {
                expect(TestSheet.className).to(equal("TestSheet"))
            }
            
            it("is valid for inherited type instance") {
                let obj = TestSheet(items: []) { _, _ in }
                expect(obj.className).to(equal("TestSheet"))
            }
        }
    }
}

private class TestSheet: ActionSheet {}
