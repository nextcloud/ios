//
//  ActionSheetItemTests.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-24.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
@testable import Sheeeeeeeeet

class ActionSheetItemTests: QuickSpec {
    
    override func spec() {
        
        func createItem(subtitle: String? = nil) -> MockActionSheetItem {
            return MockActionSheetItem(title: "foo", subtitle: subtitle, value: true, image: UIImage())
        }
        
        func createItem(_ tapBehavior: ActionSheetItem.TapBehavior) -> MockActionSheetItem {
            return MockActionSheetItem(title: "foo", subtitle: "bar", value: true, image: UIImage(), tapBehavior: tapBehavior)
        }
        
        describe("created instance") {
            
            it("applies default values") {
                let item = ActionSheetItem(title: "foo")
                
                expect(item.title).to(equal("foo"))
                expect(item.subtitle).to(beNil())
                expect(item.value).to(beNil())
                expect(item.image).to(beNil())
                expect(item.tapBehavior).to(equal(.dismiss))
                expect(item.cellStyle).to(equal(.default))
            }
            
            it("applies provided values") {
                let image = UIImage()
                let item = ActionSheetItem(title: "foo", subtitle: "bar", value: true, image: image, tapBehavior: .none)
                
                expect(item.title).to(equal("foo"))
                expect(item.subtitle).to(equal("bar"))
                expect(item.value as? Bool).to(equal(true))
                expect(item.image).to(be(image))
                expect(item.tapBehavior).to(equal(ActionSheetItem.TapBehavior.none))
                expect(item.cellStyle).to(equal(.value1))
            }
        }
        
        
        describe("cell reuse identifier") {
            
            it("is class name") {
                let item = createItem()
                
                expect(item.cellReuseIdentifier).to(equal("MockActionSheetItem"))
            }
        }
        
        
        describe("height") {
            
            let preset = CustomItem.height
            
            afterEach {
                CustomItem.height = preset
            }
            
            it("uses standard height if no custom value is registered") {
                expect(ActionSheetItem.height).to(equal(50))
            }
            
            it("only uses custom height for registered type") {
                CustomItem.height = 123
                
                expect(CustomItem.height).to(equal(123))
                expect(CustomItem(title: "").height).to(equal(123))
                expect(ActionSheetItem.height).to(equal(50))
            }
        }
        
        
        describe("resolving cell") {
            
            it("returns correct cell") {
                let item = createItem()
                let cell = item.cell(for: UITableView(frame: .zero))
                
                expect(cell.reuseIdentifier).to(equal(item.cellReuseIdentifier))
            }
        }
    }
}


class ActionSheetItemCellTests: QuickSpec {
    
    override func spec() {
        
        var cell: ActionSheetItemCell!
        var item: ActionSheetItem! {
            didSet { cell = item.cell(for: UITableView()) }
        }
        
        beforeEach {
            item = ActionSheetItem(title: "foo")
        }
        
        
        describe("moving to window") {
            
            it("refreshes cell") {
                cell.refresh(with: item)
                cell.textLabel?.text = ""
                cell.didMoveToWindow()
                
                expect(cell.textLabel?.text).to(equal("foo"))
            }
        }
        
        
        describe("refreshing") {
            
            it("aborts if cell has no item reference") {
                cell.refresh()
                
                expect(cell.textLabel?.text).to(beNil())
            }
            
            it("refreshes if cell has item reference") {
                let image = UIImage()
                item = ActionSheetItem(title: "foo", subtitle: "bar", value: "baz", image: image)
                cell.titleColor = .yellow
                cell.titleFont = .boldSystemFont(ofSize: 1)
                cell.subtitleColor = .brown
                cell.subtitleFont = .boldSystemFont(ofSize: 2)
                
                cell.refresh(with: item)
                
                expect(cell.imageView?.image).to(be(image))
                expect(cell.selectionStyle).to(equal(.default))
                expect(cell.textLabel?.font).toNot(beNil())
                expect(cell.textLabel?.font).to(be(cell.titleFont))
                expect(cell.textLabel?.text).to(equal("foo"))
                expect(cell.textLabel?.textAlignment).to(equal(.left))
                expect(cell.detailTextLabel?.font).toNot(beNil())
                expect(cell.detailTextLabel?.font).to(be(cell.subtitleFont))
                expect(cell.detailTextLabel?.text).to(equal("bar"))
            }
        }
    }
}


private class CustomItem: ActionSheetItem {}
