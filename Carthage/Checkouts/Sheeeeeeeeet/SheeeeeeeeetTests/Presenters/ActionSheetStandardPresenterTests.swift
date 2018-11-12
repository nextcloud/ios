//
//  ActionSheetStandardPresenterTests.swift
//  SheeeeeeeeetTests
//
//  Created by Daniel Saidi on 2018-10-18.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
import Sheeeeeeeeet

class ActionSheetStandardPresenterTests: QuickSpec {
    
    override func spec() {
        
        var presenter: ActionSheetStandardPresenter!
        
        beforeEach {
            presenter = ActionSheetStandardPresenter()
        }
        
        describe("background tap dismissal") {
            
            it("is enabled by default") {
                expect(presenter.isDismissableWithTapOnBackground).to(beTrue())
            }
        }
    }
}
