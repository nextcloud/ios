//
//  UIView+NibTests.swift
//  SheeeeeeeeetTests
//
//  Created by Daniel Saidi on 2018-10-17.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
@testable import Sheeeeeeeeet

class UIView_NibTests: QuickSpec {
    
    override func spec() {
        
        describe("default nib") {
            
            it("is not nil for existing nib") {
                expect(ActionSheetCollectionItemCell.defaultNib).toNot(beNil())
            }
        }
    }
}
