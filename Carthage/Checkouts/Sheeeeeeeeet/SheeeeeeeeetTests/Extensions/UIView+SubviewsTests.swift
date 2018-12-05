//
//  UIView+SubviewsTests.swift
//  SheeeeeeeeetTests
//
//  Created by Daniel Saidi on 2018-10-17.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
@testable import Sheeeeeeeeet

class UIView_SubviewsTests: QuickSpec {
    
    override func spec() {
        
        describe("adding subview to fill") {
            
            it("adds subview with filling configuration") {
                let parent = UIView(frame: CGRect(x: 10, y: 20, width: 30, height: 40))
                let view = UIView(frame: .zero)
                parent.addSubviewToFill(view)
                
                expect(parent.subviews.count).to(equal(1))
                expect(parent.subviews[0]).to(be(view))
                expect(view.translatesAutoresizingMaskIntoConstraints).to(beFalse())
            }
        }
    }
}
