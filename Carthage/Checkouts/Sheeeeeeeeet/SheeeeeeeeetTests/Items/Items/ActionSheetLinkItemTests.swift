//
//  ActionSheetLinkItemTests.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-26.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
import Sheeeeeeeeet

class ActionSheetLinkItemTests: QuickSpec {
    
    override func spec() {
        
        let item = ActionSheetLinkItem(title: "foo", value: true, image: UIImage())
        
        describe("when created") {
            
            it("applies provided values") {
                expect(item.title).to(equal("foo"))
                expect(item.value as? Bool).to(equal(true))
                expect(item.image).toNot(beNil())
            }
        }
        
        describe("tap behavior") {
            
            it("is dismiss") {
                expect(item.tapBehavior).to(equal(ActionSheetItem.TapBehavior.dismiss))
            }
        }
    }
}
