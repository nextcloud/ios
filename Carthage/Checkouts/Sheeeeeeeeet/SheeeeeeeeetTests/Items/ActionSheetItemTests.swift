//
//  ActionSheetItemTests.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-24.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
import Sheeeeeeeeet

class ActionSheetItemTests: QuickSpec {
    
    func prepareStandardAppearance() {
        let appearance = ActionSheetAppearance.standard.item
        appearance.backgroundColor = .red
        appearance.font = UIFont.systemFont(ofSize: 31)
        appearance.height = 314
        appearance.separatorInsets = UIEdgeInsets(top: 1, left: 20, bottom: 3, right: 40)
        appearance.textColor = .green
        appearance.tintColor = .blue
        appearance.subtitleFont = UIFont.systemFont(ofSize: 34)
        appearance.subtitleTextColor = .yellow
    }
    
    func restoreStandardAppearance() {
        let appearance = ActionSheetAppearance.standard.item
        appearance.backgroundColor = nil
        appearance.font = nil
        appearance.height = 50
        appearance.separatorInsets = .zero
        appearance.textColor = nil
        appearance.tintColor = nil
        appearance.subtitleFont = nil
        appearance.subtitleTextColor = nil
    }
    
    func compare(
        _ appearance1: ActionSheetItemAppearance,
        _ appearance2: ActionSheetItemAppearance,
        textColor: UIColor? = nil) -> Bool {
        let textColor = textColor ?? appearance2.textColor
        return appearance1.backgroundColor == appearance2.backgroundColor
            && appearance1.font == appearance2.font
            && appearance1.height == appearance2.height
            && appearance1.separatorInsets == appearance2.separatorInsets
            && appearance1.textColor == textColor
            && appearance1.tintColor == appearance2.tintColor
            && appearance1.subtitleFont == appearance2.subtitleFont
            && appearance1.subtitleTextColor == appearance2.subtitleTextColor
    }
    
    func compare(
        _ cell: UITableViewCell,
        item: ActionSheetItem,
        appearance: ActionSheetItemAppearance,
        textColor: UIColor? = nil,
        textAlignment: NSTextAlignment = .left) -> Bool {
        let compareColor = textColor ?? appearance.textColor
        return cell.imageView?.image == item.image
            && cell.selectionStyle == .default
            //&& cell.separatorInset == appearance.item.separatorInsets))
            && cell.tintColor == appearance.tintColor
            && cell.textLabel?.text == item.title
            && cell.textLabel?.textAlignment == textAlignment
            && cell.textLabel?.textColor == compareColor
            && cell.textLabel?.font == appearance.font
            && cell.detailTextLabel?.text == item.subtitle
            && cell.detailTextLabel?.textColor == appearance.subtitleTextColor
            && cell.detailTextLabel?.font == appearance.subtitleFont
    }
    
    
    override func spec() {
        
        func createItem(subtitle: String? = nil) -> MockActionSheetItem {
            return MockActionSheetItem(title: "foo", subtitle: subtitle, value: true, image: UIImage())
            
        }
        
        func createItem(_ tapBehavior: ActionSheetItem.TapBehavior) -> MockActionSheetItem {
            return MockActionSheetItem(title: "foo", subtitle: "bar", value: true, image: UIImage(), tapBehavior: tapBehavior)
        }
        
        beforeEach {
            self.prepareStandardAppearance()
        }
        
        afterEach {
            self.restoreStandardAppearance()
        }
        
        describe("when created") {
            
            it("applies provided values") {
                let item = createItem(.none)
                expect(item.title).to(equal("foo"))
                expect(item.subtitle).to(equal("bar"))
                expect(item.value as? Bool).to(equal(true))
                expect(item.image).toNot(beNil())
                expect(item.tapBehavior).to(equal(ActionSheetItem.TapBehavior.none))
            }
            
            it("uses dismiss tap behavior by default") {
                let item = createItem()
                expect(item.tapBehavior).to(equal(ActionSheetItem.TapBehavior.dismiss))
            }
            
            it("copies standard item appearance initially") {
                let item = createItem()
                let standard = ActionSheetAppearance.standard.item
                let isEqual = self.compare(item.appearance, standard)
                expect(isEqual).to(beTrue())
            }
        }
        
        describe("cell reuse identifier") {
            
            it("is class name") {
                let item = createItem()
                expect(item.cellReuseIdentifier).to(equal("MockActionSheetItem"))
            }
        }
        
        describe("cell style") {
            
            it("is default if no subtitle is set") {
                let item = createItem(subtitle: nil)
                expect(item.cellStyle).to(equal(.default))
            }
            
            it("is value1 if subtitle is set") {
                let item = createItem(subtitle: "bar")
                expect(item.cellStyle).to(equal(.value1))
            }
        }
        
        describe("custom appearance") {
            
            it("is nil by default") {
                let item = createItem()
                expect(item.customAppearance).to(beNil())
            }
        }
        
        describe("applying appearance") {
            
            it("applies standard copy if no custom appearance is set") {
                let item = createItem()
                item.applyAppearance(ActionSheetAppearance.standard)
                expect(self.compare(item.appearance, ActionSheetAppearance.standard.item)).to(beTrue())
            }
            
            it("applies custom appearance if set") {
                let item = createItem()
                let standard = ActionSheetAppearance.standard
                let custom = ActionSheetAppearance(copy: standard)
                custom.item.backgroundColor = .yellow
                item.customAppearance = custom.item
                item.applyAppearance(standard)
                expect(item.appearance).to(be(custom.item))
            }
        }
        
        describe("applying appearance to cell") {
            
            it("applies correct style") {
                let item = createItem()
                let appearance = ActionSheetAppearance.standard
                let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")
                item.applyAppearance(appearance)
                item.applyAppearance(to: cell)
                expect(self.compare(cell, item: item, appearance: appearance.item)).to(beTrue())
            }
        }
        
        
        
        describe("resolving cell") {
            
            func tableView() -> UITableView {
                return UITableView(frame: .zero)
            }
            
            it("always returns a cell even if table view fails to dequeue") {
                let item = createItem()
                let cell = item.cell(for: tableView())
                expect(cell).toNot(beNil())
            }
            
            it("applies appearance to cell") {
                let item = createItem()
                let cell = item.cell(for: tableView())
                expect(item.applyAppearanceInvokeCount).to(equal(1))
                expect(item.applyAppearanceInvokeCells.count).to(equal(1))
                expect(item.applyAppearanceInvokeCells[0]).to(be(cell))
            }
        }
    }
}
