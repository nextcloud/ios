//
//  ActionSheetItemHandlerTests.swift
//  SheeeeeeeeetTests
//
//  Created by Daniel Saidi on 2018-10-17.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
@testable import Sheeeeeeeeet

class ActionSheetItemHandlerTests: QuickSpec {
    
    override func spec() {
        
        func tableView() -> MockTableView {
            return MockTableView(frame: .zero)
        }
        
        var sheet: MockActionSheet!
        var handler: ActionSheetItemHandler!
        var item1: MockActionSheetItem!
        var item2: MockActionSheetButton!
        var item3: MockActionSheetItem!
        
        beforeEach {
            item1 = MockActionSheetItem(title: "1")
            item2 = MockActionSheetButton(title: "2", value: true)
            item3 = MockActionSheetItem(title: "3")
            sheet = MockActionSheet(items: [item1, item2, item3]) { _, _ in }
            handler = ActionSheetItemHandler(actionSheet: sheet, itemType: .items)
        }
        
        describe("configured with item type") {
            
            beforeEach {
                handler = ActionSheetItemHandler(actionSheet: sheet, itemType: .items)
            }
            
            it("uses action sheet items") {
                let items = handler.items
                expect(items.count).to(equal(2))
                expect(items[0].title).to(equal("1"))
                expect(items[1].title).to(equal("3"))
            }
        }
        
        describe("configured with button type") {
            
            beforeEach {
                handler = ActionSheetItemHandler(actionSheet: sheet, itemType: .buttons)
            }
            
            it("uses action sheet buttons") {
                let items = handler.items
                expect(items.count).to(equal(1))
                expect(items[0].title).to(equal("2"))
            }
        }
        
        describe("as table view data source") {
            
            it("returns correct item at index") {
                let path1 = IndexPath(row: 0, section: 0)
                let path2 = IndexPath(row: 1, section: 0)
                expect(handler.item(at: path1)!.title).to(equal("1"))
                expect(handler.item(at: path2)!.title).to(equal("3"))
            }
            
            it("has correct section count") {
                let sections = handler.numberOfSections(in: tableView())
                expect(sections).to(equal(1))
            }
            
            it("has correct row count") {
                let rows = handler.tableView(tableView(), numberOfRowsInSection: 0)
                expect(rows).to(equal(2))
            }
            
            it("returns correct cell for existing item") {
                let path = IndexPath(row: 0, section: 0)
                item1.cell = UITableViewCell(frame: .zero)
                let result = handler.tableView(tableView(), cellForRowAt: path)
                expect(result).to(be(item1.cell))
            }
            
            it("returns fallback cell for existing item") {
                let path = IndexPath(row: 1, section: 1)
                let result = handler.tableView(tableView(), cellForRowAt: path)
                expect(result).toNot(beNil())
            }
            
            it("returns correct height for existing item") {
                let path = IndexPath(row: 0, section: 0)
                item1.appearance.height = 123
                let result = handler.tableView(tableView(), heightForRowAt: path)
                expect(result).to(equal(123))
            }
            
            it("returns zero height for existing item") {
                let path = IndexPath(row: 1, section: 1)
                let result = handler.tableView(tableView(), heightForRowAt: path)
                expect(result).to(equal(0))
            }
        }
        
        describe("as table view delegate") {
            
            it("does not deselect row for invalid path") {
                let path = IndexPath(row: 1, section: 1)
                let view = tableView()
                handler.tableView(view, didSelectRowAt: path)
                expect(view.deselectRowInvokeCount).to(equal(0))
            }
            
            it("deselects row for valid path") {
                let path = IndexPath(row: 0, section: 0)
                let view = tableView()
                handler.tableView(view, didSelectRowAt: path)
                expect(view.deselectRowInvokeCount).to(equal(1))
                expect(view.deselectRowInvokePaths.count).to(equal(1))
                expect(view.deselectRowInvokePaths[0]).to(equal(path))
                expect(view.deselectRowInvokeAnimated.count).to(equal(1))
                expect(view.deselectRowInvokeAnimated[0]).to(beTrue())
            }
            
            it("does not handle tap if missing action sheet") {
                sheet = nil
                let path = IndexPath(row: 0, section: 0)
                handler.tableView(tableView(), didSelectRowAt: path)
                expect(item1.handleTapInvokeCount).to(equal(0))
            }
            
            it("handles item tap for existing action sheet") {
                let path = IndexPath(row: 0, section: 0)
                handler.tableView(tableView(), didSelectRowAt: path)
                expect(item1.handleTapInvokeCount).to(equal(1))
                expect(item1.handleTapInvokeActionSheets.count).to(equal(1))
                expect(item1.handleTapInvokeActionSheets[0]).to(be(sheet))
            }

            it("handles sheet item tap for existing action sheet") {
                let path = IndexPath(row: 0, section: 0)
                handler.tableView(tableView(), didSelectRowAt: path)
                expect(sheet.handleTapInvokeCount).to(equal(1))
                expect(sheet.handleTapInvokeItems.count).to(equal(1))
                expect(sheet.handleTapInvokeItems[0]).to(be(item1))
            }
        }
    }
}
