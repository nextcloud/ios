//
//  ActionSheetSelectItemTests.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-26.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
@testable import Sheeeeeeeeet

class ActionSheetSelectItemTests: QuickSpec {
    
    override func spec() {
        
        
        describe("instance") {
            
            it("can be created with default values") {
                let item = ActionSheetSelectItem(title: "foo", isSelected: false)
                expect(item.title).to(equal("foo"))
                expect(item.isSelected).to(beFalse())
                expect(item.group).to(equal(""))
                expect(item.value).to(beNil())
                expect(item.image).to(beNil())
                expect(item.tapBehavior).to(equal(ActionSheetItem.TapBehavior.dismiss))
            }
            
            it("can be created with custom values") {
                let item = ActionSheetSelectItem(title: "foo", isSelected: true, group: "group", value: true, image: UIImage())
                expect(item.title).to(equal("foo"))
                expect(item.isSelected).to(beTrue())
                expect(item.group).to(equal("group"))
                expect(item.value as? Bool).to(equal(true))
                expect(item.image).toNot(beNil())
                expect(item.tapBehavior).to(equal(ActionSheetItem.TapBehavior.dismiss))
            }
        }
        
        
        describe("cell") {
            
            it("is of correct type") {
                let item = ActionSheetSelectItem(title: "foo", isSelected: false)
                let cell = item.cell(for: UITableView())
                
                expect(cell is ActionSheetSelectItemCell).to(beTrue())
                expect(cell.reuseIdentifier).to(equal(item.cellReuseIdentifier))
            }
        }
        
        
        describe("handling tap") {
            
            it("toggles selected state") {
                let item = ActionSheetSelectItem(title: "foo", isSelected: false)
                let sheet = ActionSheet { _, _ in }
                item.handleTap(in: sheet)
                expect(item.isSelected).to(beTrue())
                item.handleTap(in: sheet)
                expect(item.isSelected).to(beFalse())
            }
        }
    }
}


class ActionSheetSelectItemCellTests: QuickSpec {
    
    override func spec() {
        
        describe("refreshing") {
            
            var item: ActionSheetSelectItem!
            var cell: ActionSheetSelectItemCell!
            
            beforeEach {
                let label = UILabel()
                item = ActionSheetSelectItem(title: "foo", isSelected: false)
                cell = item.cell(for: UITableView()) as? ActionSheetSelectItemCell
                cell.tintColor = UIColor.purple.withAlphaComponent(0.1)
                cell.titleColor = UIColor.yellow.withAlphaComponent(0.1)
                cell.titleFont = .systemFont(ofSize: 11)
                cell.subtitleColor = UIColor.red.withAlphaComponent(0.1)
                cell.subtitleFont = .systemFont(ofSize: 12)
                cell.selectedIcon = UIImage()
                cell.selectedIconColor = .green
                cell.selectedTintColor = .purple
                cell.selectedTitleColor = .yellow
                cell.selectedTitleFont = .systemFont(ofSize: 13)
                cell.selectedSubtitleColor = .red
                cell.selectedSubtitleFont = .systemFont(ofSize: 14)
                cell.unselectedIcon = UIImage()
                cell.unselectedIconColor = UIColor.green.withAlphaComponent(0.1)
                cell.refresh(with: item)
            }
            
            it("refreshes correctly for selected item") {
                item.isSelected = true
                cell.refresh()
                expect((cell.accessoryView as? UIImageView)?.image).to(be(cell.selectedIcon))
                expect(cell.accessoryView?.tintColor).to(be(cell.selectedIconColor))
                expect(cell.tintColor).to(be(cell.selectedTintColor))
                expect(cell.textLabel?.textColor).to(be(cell.selectedTitleColor))
                expect(cell.textLabel?.font).to(be(cell.selectedTitleFont))
//                expect(cell.detailTextLabel?.textColor).to(be(cell.selectedSubtitleColor))
//                expect(cell.detailTextLabel?.font).to(be(cell.selectedSubtitleFont))
            }
            
            it("refreshes correctly for unselected item") {
                item.isSelected = false
                cell.refresh()
                expect((cell.accessoryView as? UIImageView)?.image).to(be(cell.unselectedIcon))
                expect(cell.accessoryView?.tintColor).to(be(cell.unselectedIconColor))
                expect(cell.tintColor).to(be(cell.tintColor))
                expect(cell.textLabel?.textColor).to(be(cell.titleColor))
                expect(cell.textLabel?.font).to(be(cell.titleFont))
//                expect(cell.detailTextLabel?.textColor).to(be(cell.subtitleColor))
//                expect(cell.detailTextLabel?.font).to(be(cell.subtitleFont))
            }
        }
    }
}
