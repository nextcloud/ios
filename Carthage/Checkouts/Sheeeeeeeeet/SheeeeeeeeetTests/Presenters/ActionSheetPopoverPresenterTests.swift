//
//  ActionSheetPopoverPresenterTests.swift
//  SheeeeeeeeetTests
//
//  Created by Daniel Saidi on 2018-10-18.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

//  TODO: Write more tests

import Quick
import Nimble
@testable import Sheeeeeeeeet

class ActionSheetPopoverPresenterTests: QuickSpec {
    
    override func spec() {
        
        var presenter: ActionSheetPopoverPresenter!
        var sheet: ActionSheet!
        var headerView: UIView!
        
        beforeEach {
            let items: [ActionSheetItem] = [
                ActionSheetSingleSelectItem(title: "item 1", isSelected: true),
                ActionSheetCancelButton(title: "cancel"),
                ActionSheetOkButton(title: "ok"),
                ActionSheetMultiSelectItem(title: "item 2", isSelected: true)
            ]
            headerView = UIView(frame: .zero)
            sheet = ActionSheet(items: items) { (_, _) in }
            sheet.headerView = headerView
            presenter = ActionSheetPopoverPresenter()
        }
        
        describe("background tap dismissal") {
            
            it("is enabled by default") {
                expect(presenter.isDismissableWithTapOnBackground).to(beTrue())
            }
        }
        
        describe("setting up sheet for popover presentation") {
            
            beforeEach {
                presenter.setupSheetForPresentation(sheet)
            }
            
            it("removes header view") {
                expect(sheet.headerView).to(beNil())
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
