//
//  ActionSheetPopoverPresenterTests.swift
//  SheeeeeeeeetTests
//
//  Created by Daniel Saidi on 2018-10-18.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
@testable import Sheeeeeeeeet

class ActionSheetPopoverPresenterTests: QuickSpec {
    
    override func spec() {
        
        var presenter: ActionSheetPopoverPresenter!
        var sheet: MockActionSheet!
        var headerView: UIView!
        var headerViewContainer: ActionSheetHeaderView!
        var itemView: ActionSheetItemTableView!
        var buttonView: ActionSheetButtonTableView!
        
        beforeEach {
            let items: [ActionSheetItem] = [
                ActionSheetSingleSelectItem(title: "item 1", isSelected: true),
                ActionSheetCancelButton(title: "cancel"),
                ActionSheetOkButton(title: "ok"),
                ActionSheetMultiSelectItem(title: "item 2", isSelected: true)
            ]
            
            headerView = UIView(frame: .zero)
            headerViewContainer = ActionSheetHeaderView(frame: .zero)
            itemView = ActionSheetItemTableView(frame: .zero)
            buttonView = ActionSheetButtonTableView(frame: .zero)
            
            sheet = MockActionSheet(items: items) { (_, _) in }
            sheet.headerViewContainer = headerViewContainer
            sheet.headerView = headerView
            sheet.itemsTableView = itemView
            sheet.buttonsTableView = buttonView
            
            presenter = ActionSheetPopoverPresenter()
            presenter.actionSheet = sheet
        }
        
        
        describe("background tap dismissal") {
            
            it("is enabled by default") {
                expect(presenter.isDismissableWithTapOnBackground).to(beTrue())
            }
        }
        
        
        describe("dismissing") {
            
            it("completes dismissal directly if action sheet has no presenting view controller") {
                var count = 0
                presenter.dismiss { count += 1 }
                
                expect(count).to(equal(1))
                expect(presenter.actionSheet).to(beNil())
            }
            
            it("completes dismissal after presenting view controller has finished dismissing") {
                var count = 0
                let vc = MockViewController()
                sheet.presentingViewController = vc
                presenter.dismiss { count += 1 }
                
                expect(vc.dismissInvokeCount).to(equal(1))
                expect(vc.dismissInvokeAnimateds).to(equal([true]))
                expect(vc.dismissInvokeCompletions.count).to(equal(1))
                expect(count).to(equal(0))
                expect(presenter.actionSheet).toNot(beNil())
                
                vc.completeDismissal()
                
                expect(count).to(equal(1))
                expect(presenter.actionSheet).to(beNil())
            }
        }
        
        
        describe("presenting action sheet from view") {
            
            var vc: MockViewController!
            var view: UIView!
            var completion: (() -> ())!
            
            beforeEach {
                vc = MockViewController()
                view = UIView(frame: CGRect(x: 1, y: 2, width: 3, height: 4))
                completion = {}
                presenter.present(sheet: sheet, in: vc, from: view, completion: completion)
            }
            
            it("sets up sheet for popover presentation") {
                expect(sheet.items.count).to(equal(3))
                expect(sheet.buttons.count).to(equal(0))
                expect(sheet.modalPresentationStyle).to(equal(.popover))
            }
            
            it("sets up popover presentation controller") {
                expect(presenter.popover?.delegate).to(be(presenter))
                expect(presenter.popover?.sourceView).to(be(view))
                expect(presenter.popover?.sourceRect).to(equal(view.bounds))
            }
            
            it("performs presentation") {
                expect(vc.presentInvokeCount).to(equal(1))
                expect(vc.presentInvokeVcs).to(equal([sheet]))
                expect(vc.presentInvokeAnimateds).to(equal([true]))
                expect(vc.presentInvokeCompletions.count).to(equal(1))
            }
        }
        
        
        describe("presenting action sheet from bar button item") {
            
            var vc: MockViewController!
            var item: UIBarButtonItem!
            var completion: (() -> ())!
            
            beforeEach {
                vc = MockViewController()
                item = UIBarButtonItem(customView: UIView(frame: .zero))
                completion = {}
                presenter.present(sheet: sheet, in: vc, from: item, completion: completion)
            }
            
            it("sets up sheet for popover presentation") {
                expect(sheet.items.count).to(equal(3))
                expect(sheet.buttons.count).to(equal(0))
                expect(sheet.modalPresentationStyle).to(equal(.popover))
            }
            
            it("sets up popover presentation controller") {
                expect(presenter.popover?.delegate).to(be(presenter))
                expect(presenter.popover?.barButtonItem).to(be(item))
                expect(presenter.popover?.sourceRect).to(equal(.zero))
            }
            
            it("performs presentation") {
                expect(vc.presentInvokeCount).to(equal(1))
                expect(vc.presentInvokeVcs).to(equal([sheet]))
                expect(vc.presentInvokeAnimateds).to(equal([true]))
                expect(vc.presentInvokeCompletions.count).to(equal(1))
            }
        }
        
        
        describe("refreshing action sheet") {
            
            beforeEach {
                sheet.itemsTableView?.backgroundColor = .red
                presenter.present(sheet: sheet, in: UIViewController(), from: UIView()) {}
                presenter.refreshActionSheet()
            }
            
            it("hides unused views") {
                expect(sheet.buttonsTableView?.isHidden).to(beTrue())
                expect(sheet.headerViewContainer?.isHidden).to(beTrue())
            }
            
            it("resizes popover") {
                expect(sheet.preferredContentSize.height).to(equal(150))
            }
            
            it("applies color to popover arrow") {
                expect(presenter.popover?.backgroundColor).to(equal(.red))
            }
        }
        
        
        describe("popover should dismiss") {
            
            var popover: UIPopoverPresentationController!
            var presenting: MockViewController!
            var dismissEventCount: Int!
            
            beforeEach {
                popover = UIPopoverPresentationController(presentedViewController: UIViewController(), presenting: nil)
                presenting = MockViewController()
                sheet.presentingViewController = presenting
                dismissEventCount = 0
                presenter.events.didDismissWithBackgroundTap = { dismissEventCount += 1 }
            }
            
            it("aborts and returns false if background tap is disabled") {
                presenter.isDismissableWithTapOnBackground = false
                let result = presenter.popoverPresentationControllerShouldDismissPopover(popover)
                
                expect(result).to(beFalse())
                expect(dismissEventCount).to(equal(0))
                expect(presenting.dismissInvokeCount).to(equal(0))
            }
            
            it("completes and returns false if background tap is enabled") {
                presenter.isDismissableWithTapOnBackground = true
                let result = presenter.popoverPresentationControllerShouldDismissPopover(popover)
                
                expect(result).to(beFalse())
                expect(dismissEventCount).to(equal(1))
                expect(presenting.dismissInvokeCount).to(equal(1))
            }
            
        }
        
        
        describe("setting up sheet for popover presentation") {
            
            beforeEach {
                presenter.setupSheetForPresentation(sheet)
            }
            
            it("sets popover style") {
                expect(sheet.modalPresentationStyle).to(equal(.popover))
            }
            
            it("moves non-cancel buttons last into items group") {
                expect(sheet.items.count).to(equal(3))
                expect(sheet.buttons.count).to(equal(0))
                expect(sheet.items[0] is ActionSheetSingleSelectItem).to(beTrue())
                expect(sheet.items[1] is ActionSheetMultiSelectItem).to(beTrue())
                expect(sheet.items[2] is ActionSheetOkButton).to(beTrue())
            }
        }
    }
}
