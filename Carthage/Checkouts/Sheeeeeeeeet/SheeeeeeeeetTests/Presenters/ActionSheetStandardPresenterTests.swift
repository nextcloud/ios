//
//  ActionSheetStandardPresenterTests.swift
//  SheeeeeeeeetTests
//
//  Created by Daniel Saidi on 2018-10-18.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
@testable import Sheeeeeeeeet

class ActionSheetStandardPresenterTests: QuickSpec {
    
    override func spec() {
        
        var presenter: ActionSheetStandardPresenter!
        var sheet: MockActionSheet!
        var backgroundView: ActionSheetBackgroundView!
        var stackView: UIStackView!
        
        beforeEach {
            backgroundView = ActionSheetBackgroundView(frame: .zero)
            stackView = UIStackView(frame: CGRect(x: 0, y: 0, width: 0, height: 100))
            
            sheet = MockActionSheet(items: []) { _, _ in }
            sheet.backgroundView = backgroundView
            sheet.stackView = stackView
            
            presenter = ActionSheetStandardPresenter()
            presenter.animationDuration = 0
            presenter.actionSheet = sheet
        }
        
        
        describe("background tap dismissal") {
            
            it("is enabled by default") {
                expect(presenter.isDismissableWithTapOnBackground).to(beTrue())
            }
        }
        
        
        describe("dismissing action sheet") {
            
            var counter: Int!
            
            beforeEach {
                counter = 0
                presenter.dismiss { counter += 1 }
            }
            
            it("calls completion directly") {
                expect(counter).to(equal(1))
            }
            
            it("removes background view") {
                expect(backgroundView.alpha).to(equal(0))
            }
            
            it("removes action sheet") {
                expect(stackView.frame.origin.y).to(equal(200))
                expect(sheet.view.superview).to(beNil())
                expect(presenter.actionSheet).toEventually(beNil())
            }
        }
        
        
        describe("presenting action sheet") {
            
            var vc: MockViewController!
            var counter: Int!
            
            beforeEach {
                vc = MockViewController()
                vc.view.frame = CGRect(x: 1, y: 2, width: 3, height: 4)
                counter = 0
                presenter.present(sheet: sheet, in: vc) { counter += 1 }
            }
            
            it("sets action sheet") {
                expect(presenter.actionSheet).to(be(sheet))
            }
            
            it("adds actio sheet to vc view") {
                expect(sheet.view.frame).to(equal(vc.view.frame))
                expect(vc.view.subviews).to(contain(sheet.view))
            }
            
            it("adds tap gesture to background view") {
                expect(sheet.backgroundView?.isUserInteractionEnabled).to(beTrue())
                //expect(backgroundView.gestureRecognizers?.count).to(equal(1))
            }
            
            it("presents background view") {
                presenter.animationDuration = -1
                presenter.present(sheet: sheet, in: vc) {}
                expect(sheet.backgroundView?.alpha).to(equal(0))
                presenter.animationDuration = 0
                presenter.present(sheet: sheet, in: vc) {}
                expect(sheet.backgroundView?.alpha).to(equal(1))
            }
            
            it("presents stack view") {
                presenter.present(sheet: sheet, in: vc) {}
                expect(sheet.stackView?.frame.origin.y).to(equal(277))
            }
        }
    }
}
