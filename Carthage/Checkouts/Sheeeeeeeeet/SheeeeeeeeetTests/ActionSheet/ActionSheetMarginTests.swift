//
//  ActionSheetMarginTests.swift
//  SheeeeeeeeetTests
//
//  Created by Daniel Saidi on 2018-10-17.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
@testable import Sheeeeeeeeet

class ActionSheetMarginTests: QuickSpec {
    
    override func spec() {
        
        describe("value in view") {
            
            func value(for margin: ActionSheetMargin) -> CGFloat? {
                let view = UIView(frame: .zero)
                return margin.value(in: view)
            }
            
            it("returns safe area inset value") {
                expect(value(for: .top)).to(equal(0))
                expect(value(for: .left)).to(equal(0))
                expect(value(for: .right)).to(equal(0))
                expect(value(for: .bottom)).to(equal(0))
            }
        }
        
        describe("value with minimum fallback in view") {
            
            func value(for margin: ActionSheetMargin) -> CGFloat? {
                let view = UIView(frame: .zero)
                return margin.value(in: view, minimum: 10)
            }
            
            it("returns safe area inset value") {
                expect(value(for: .top)).to(equal(10))
                expect(value(for: .left)).to(equal(10))
                expect(value(for: .right)).to(equal(10))
                expect(value(for: .bottom)).to(equal(10))
            }
        }
    }
}
