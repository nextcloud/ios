//
//  ActionSheetTests.swift
//  SheeeeeeeeetTests
//
//  Created by Daniel Saidi on 2017-11-28.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
@testable import Sheeeeeeeeet

class ActionSheetTests: QuickSpec {
    
    override func spec() {
        
        var sheet: MockActionSheet!
        
        func createSheet(_ items: [ActionSheetItem] = []) -> MockActionSheet {
            return MockActionSheet(items: items, action: { _, _ in })
        }
        
        
        // MARK: - Initialization
        
        describe("created instance") {
            
            context("default behavior") {
                
                it("use default presenter") {
                    sheet = createSheet()
                    let isStandard = sheet.presenter is ActionSheetStandardPresenter
                    let isPopover = sheet.presenter is ActionSheetPopoverPresenter
                    let isValid = isStandard || isPopover
                    
                    expect(isValid).to(beTrue())
                }
                
                it("applies no items and buttons") {
                    sheet = createSheet()
                    
                    expect(sheet.items.count).to(equal(0))
                    expect(sheet.buttons.count).to(equal(0))
                }
                
            }
            
            context("custom properties") {
                
                it("uses provided presenter") {
                    let presenter = ActionSheetPopoverPresenter()
                    sheet = MockActionSheet(items: [], presenter: presenter, action: { _, _ in })
                    
                    expect(sheet.presenter).to(be(presenter))
                }
                
                it("sets up provided items and buttons") {
                    let items = [ActionSheetItem(title: "foo")]
                    sheet = createSheet(items)
                    
                    expect(sheet.setupItemsInvokeCount).to(equal(1))
                    expect(sheet.setupItemsInvokeItems[0]).to(be(items))
                }
            }
            
            it("uses provided action") {
                var counter = 0
                sheet = MockActionSheet(items: []) { _, _  in counter += 1 }
                sheet.selectAction(sheet, ActionSheetItem(title: "foo"))
                
                expect(counter).to(equal(1))
            }
        }
        
        
        describe("setup") {
            
            beforeEach {
                sheet = createSheet()
            }
            
            it("applies default preferred popover width") {
                sheet.setup()
                
                expect(sheet.preferredContentSize.width).to(equal(300))
            }
            
            it("applies custom preferred popover width") {
                sheet.preferredPopoverWidth = 200
                sheet.setup()
                
                expect(sheet.preferredContentSize.width).to(equal(200))
            }
        }
        
        
        describe("setup items") {
            
            beforeEach {
                sheet = createSheet()
            }
            
            it("applies empty collection") {
                sheet.setup(items: [])
                
                expect(sheet.items.count).to(equal(0))
                expect(sheet.buttons.count).to(equal(0))
            }
            
            it("separates items and buttons") {
                let item1 = ActionSheetItem(title: "foo")
                let item2 = ActionSheetItem(title: "bar")
                let button = ActionSheetOkButton(title: "baz")
                sheet.setup(items: [button, item1, item2])
                
                expect(sheet.items.count).to(equal(2))
                expect(sheet.items[0]).to(be(item1))
                expect(sheet.items[1]).to(be(item2))
                expect(sheet.buttons.count).to(equal(1))
                expect(sheet.buttons[0]).to(be(button))
            }
            
            it("reloads data") {
                sheet.reloadDataInvokeCount = 0
                sheet.setup(items: [])
                
                expect(sheet.reloadDataInvokeCount).to(equal(1))
            }
        }
        
        
        describe("loading view") {
            
            var itemsTableView: ActionSheetItemTableView!
            var buttonsTableView: ActionSheetButtonTableView!
            
            beforeEach {
                sheet = createSheet()
                itemsTableView = ActionSheetItemTableView(frame: .zero)
                buttonsTableView = ActionSheetButtonTableView(frame: .zero)
                sheet.itemsTableView = itemsTableView
                sheet.buttonsTableView = buttonsTableView
                sheet.viewDidLoad()
            }
            
            it("sets up action sheet") {
                expect(sheet.setupInvokeCount).to(equal(1))
            }
            
            it("sets up items table view") {
                expect(itemsTableView.delegate).to(be(sheet.itemHandler))
                expect(itemsTableView.dataSource).to(be(sheet.itemHandler))
                expect(itemsTableView.alwaysBounceVertical).to(beFalse())
                expect(itemsTableView.estimatedRowHeight).to(equal(44))
                expect(itemsTableView.rowHeight).to(equal(UITableView.automaticDimension))
                expect(itemsTableView.cellLayoutMarginsFollowReadableWidth).to(beFalse())
            }
            
            it("sets up buttons table view") {
                expect(buttonsTableView.delegate).to(be(sheet.buttonHandler))
                expect(buttonsTableView.dataSource).to(be(sheet.buttonHandler))
                expect(itemsTableView.alwaysBounceVertical).to(beFalse())
                expect(buttonsTableView.estimatedRowHeight).to(equal(44))
                expect(buttonsTableView.rowHeight).to(equal(UITableView.automaticDimension))
                expect(buttonsTableView.cellLayoutMarginsFollowReadableWidth).to(beFalse())
            }
        }
        
        
        describe("laying out subviews") {
            
            it("refreshes sheet") {
                sheet = createSheet()
                sheet.viewDidLayoutSubviews()
                
                expect(sheet.refreshInvokeCount).to(equal(1))
            }
        }
        
        
        describe("minimum content insets") {
            
            it("has correct default value") {
                sheet = createSheet()
                let expected = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
                
                expect(sheet.minimumContentInsets).to(equal(expected))
            }
        }
        
        
        describe("preferred popover width") {
            
            it("has correct default value") {
                sheet = createSheet()
                let expected: CGFloat = 300
                
                expect(sheet.preferredPopoverWidth).to(equal(expected))
            }
        }
        
        
        describe("section margins") {
            
            it("has correct default value") {
                sheet = createSheet()
                let expected: CGFloat = 15
                
                expect(sheet.sectionMargins).to(equal(expected))
            }
        }
        
        
        describe("items height") {
            
            beforeEach {
                ActionSheetItem.height = 100
                ActionSheetSingleSelectItem.height = 110
                ActionSheetMultiSelectItem.height = 120
                ActionSheetOkButton.height = 120
            }
            
            it("is sum of all items") {
                let item1 = ActionSheetItem(title: "foo")
                let item2 = ActionSheetSingleSelectItem(title: "bar", isSelected: true)
                let item3 = ActionSheetMultiSelectItem(title: "baz", isSelected: false)
                let button = ActionSheetOkButton(title: "ok")
                sheet = createSheet([item1, item2, item3, button])
                
                expect(sheet.itemsHeight).to(equal(330))
            }
        }
        
        
        describe("item handler") {
            
            it("has correct item type") {
                sheet = createSheet()
                
                expect(sheet.itemHandler.itemType).to(equal(.items))
            }
            
            it("has correct items") {
                let item1 = ActionSheetItem(title: "foo")
                let item2 = ActionSheetItem(title: "bar")
                let button = ActionSheetOkButton(title: "ok")
                sheet = createSheet([item1, item2, button])
                
                expect(sheet.itemHandler.items.count).to(equal(2))
                expect(sheet.itemHandler.items[0]).to(be(item1))
                expect(sheet.itemHandler.items[1]).to(be(item2))
            }
        }
        
        
        describe("items height") {
            
            beforeEach {
                ActionSheetItem.height = 100
                ActionSheetOkButton.height = 110
                ActionSheetDangerButton.height = 120
                ActionSheetCancelButton.height = 130
            }
            
            it("is sum of all items") {
                let item = ActionSheetItem(title: "foo")
                let button1 = ActionSheetOkButton(title: "ok")
                let button2 = ActionSheetDangerButton(title: "ok")
                let button3 = ActionSheetCancelButton(title: "ok")
                sheet = createSheet([item, button1, button2, button3])
                
                expect(sheet.buttonsHeight).to(equal(360))
            }
        }
        
        
        describe("item handler") {
            
            it("has correct item type") {
                sheet = createSheet()
                
                expect(sheet.buttonHandler.itemType).to(equal(.buttons))
            }
            
            it("has correct items") {
                let item = ActionSheetItem(title: "foo")
                let button1 = ActionSheetOkButton(title: "ok")
                let button2 = ActionSheetOkButton(title: "ok")
                sheet = createSheet([item, button1, button2])
                
                expect(sheet.buttonHandler.items.count).to(equal(2))
                expect(sheet.buttonHandler.items[0]).to(be(button1))
                expect(sheet.buttonHandler.items[1]).to(be(button2))
            }
        }
        
        
        context("presentation") {
            
            var presenter: MockActionSheetPresenter!
            
            beforeEach {
                presenter = MockActionSheetPresenter()
                sheet = createSheet()
                sheet.presenter = presenter
            }
            
            describe("when dismissed") {
                
                it("it calls presenter") {
                    var counter = 0
                    let completion = { counter += 1 }
                    sheet.dismiss(completion: completion)
                    presenter.dismissInvokeCompletions[0]()
                    
                    expect(presenter.dismissInvokeCount).to(equal(1))
                    expect(counter).to(equal(1))
                }
            }
            
            describe("when presented from view") {
                
                it("refreshes itself") {
                    sheet.present(in: UIViewController(), from: UIView())
                    
                    expect(sheet.refreshInvokeCount).to(equal(1))
                }
                
                it("calls presenter") {
                    var counter = 0
                    let completion = { counter += 1 }
                    let vc = UIViewController()
                    let view = UIView()
                    sheet.present(in: vc, from: view, completion: completion)
                    presenter.presentInvokeCompletions[0]()
                    
                    expect(presenter.presentInvokeCount).to(equal(1))
                    expect(presenter.presentInvokeViewControllers[0]).to(be(vc))
                    expect(presenter.presentInvokeViews[0]).to(be(view))
                    expect(counter).to(equal(1))
                }
            }
            
            describe("when presented from bar button item") {
                
                it("refreshes itself") {
                    sheet.present(in: UIViewController(), from: UIBarButtonItem())
                    
                    expect(sheet.refreshInvokeCount).to(equal(1))
                }
                
                it("calls presenter") {
                    var counter = 0
                    let completion = { counter += 1 }
                    let vc = UIViewController()
                    let item = UIBarButtonItem()
                    sheet.present(in: vc, from: item, completion: completion)
                    presenter.presentInvokeCompletions[0]()
                    
                    expect(presenter.presentInvokeCount).to(equal(1))
                    expect(presenter.presentInvokeViewControllers[0]).to(be(vc))
                    expect(presenter.presentInvokeItems[0]).to(be(item))
                    expect(counter).to(equal(1))
                }
            }
        }
        
        
        describe("refreshing") {
            
            var presenter: MockActionSheetPresenter!
            var stackView: UIStackView!
            
            beforeEach {
                presenter = MockActionSheetPresenter()
                stackView = UIStackView()
                sheet = createSheet()
                sheet.stackView = stackView
                sheet.presenter = presenter
                sheet.refresh()
            }
            
            it("refreshes header") {
                expect(sheet.refreshHeaderInvokeCount).to(equal(1))
            }
            
            it("refreshes items") {
                expect(sheet.refreshItemsInvokeCount).to(equal(1))
            }
            
            it("refreshes buttons") {
                expect(sheet.refreshButtonsInvokeCount).to(equal(1))
            }
            
            it("applies stack view spacing") {
                expect(stackView.spacing).to(equal(15))
            }
            
            it("calls presenter to refresh itself") {
                expect(presenter.refreshActionSheetInvokeCount).to(equal(1))
            }
        }
        
        
        describe("refreshing header") {
            
            var container: ActionSheetHeaderView!
            var height: NSLayoutConstraint!
            
            beforeEach {
                container = ActionSheetHeaderView()
                height = NSLayoutConstraint()
                sheet = createSheet()
                sheet.headerViewContainer = container
                sheet.headerViewContainerHeight = height
            }
            
            it("refreshes correctly if header view is nil") {
                sheet.refreshHeader()
                
                expect(container.isHidden).to(beTrue())
                expect(container.subviews.count).to(equal(0))
                expect(height.constant).to(equal(0))
            }
            
            it("refreshes correctly if header view is set") {
                let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
                sheet.headerView = view
                sheet.refreshHeader()
                
                expect(container.isHidden).to(beFalse())
                expect(container.subviews.count).to(equal(1))
                expect(container.subviews[0]).to(be(view))
                expect(height.constant).to(equal(200))
            }
        }
        
        
        describe("refreshing items") {
            
            var height: NSLayoutConstraint!
            
            beforeEach {
                height = NSLayoutConstraint()
                sheet = createSheet()
                sheet.itemsTableViewHeight = height
                ActionSheetItem.height = 12
                ActionSheetOkButton.height = 13
            }
            
            it("refreshes correctly if no items are set") {
                sheet.refreshItems()
                
                expect(height.constant).to(equal(0))
            }
            
            it("refreshes correctly if items are set") {
                let item1 = ActionSheetItem(title: "foo")
                let item2 = ActionSheetItem(title: "foo")
                let button = ActionSheetOkButton(title: "foo")
                sheet.setup(items: [item1, item2, button])
                sheet.refreshItems()
                
                expect(height.constant).to(equal(24))
            }
        }
        
        
        describe("refreshing buttons") {
            
            var height: NSLayoutConstraint!
            
            beforeEach {
                height = NSLayoutConstraint()
                sheet = createSheet()
                sheet.buttonsTableViewHeight = height
                ActionSheetItem.height = 12
                ActionSheetOkButton.height = 13
            }
            
            it("refreshes correctly if no items are set") {
                sheet.refreshButtons()
                
                expect(height.constant).to(equal(0))
            }
            
            it("refreshes correctly if items are set") {
                let item = ActionSheetItem(title: "foo")
                let button1 = ActionSheetOkButton(title: "foo")
                let button2 = ActionSheetOkButton(title: "foo")
                sheet.setup(items: [item, button1, button2])
                sheet.refreshButtons()
                
                expect(height.constant).to(equal(26))
            }
        }
        
        
        describe("handling tap on item") {
            
            beforeEach {
                sheet = createSheet()
                sheet.reloadDataInvokeCount = 0
            }
            
            it("reloads data") {
                sheet.handleTap(on: ActionSheetItem(title: ""))
                
                expect(sheet.reloadDataInvokeCount).to(equal(1))
            }
            
            it("calls select action without dismiss if item has none tap action") {
                var count = 0
                sheet = MockActionSheet { (_, _) in count += 1 }
                let item = ActionSheetItem(title: "", tapBehavior: .none)
                sheet.handleTap(on: item)
                
                expect(count).to(equal(1))
                expect(sheet.dismissInvokeCount).to(equal(0))
            }
            
            it("calls select action after dismiss if item has dismiss tap action") {
                var count = 0
                sheet = MockActionSheet { (_, _) in count += 1 }
                let item = ActionSheetItem(title: "", tapBehavior: .dismiss)
                sheet.handleTap(on: item)
                
                expect(count).to(equal(1))
                expect(sheet.dismissInvokeCount).to(equal(1))
            }
        }
        
        
        describe("margin at position") {
            
            beforeEach {
                sheet = createSheet()
            }
            
            it("ignores custom edge margins with smaller value than the default ones") {
                let sheet = createSheet()
                sheet.minimumContentInsets = UIEdgeInsets(top: -1, left: -1, bottom: -1, right: -1)
                
                expect(sheet.margin(at: .top)).to(equal(sheet.view.safeAreaInsets.top))
                expect(sheet.margin(at: .left)).to(equal(sheet.view.safeAreaInsets.left))
                expect(sheet.margin(at: .right)).to(equal(sheet.view.safeAreaInsets.right))
                expect(sheet.margin(at: .bottom)).to(equal(sheet.view.safeAreaInsets.bottom))
            }

            it("uses custom edge margins with greated value than the default ones") {
                let sheet = createSheet()
                sheet.minimumContentInsets = UIEdgeInsets(top: 111, left: 222, bottom: 333, right: 444)
                
                expect(sheet.margin(at: .top)).to(equal(111))
                expect(sheet.margin(at: .left)).to(equal(222))
                expect(sheet.margin(at: .bottom)).to(equal(333))
                expect(sheet.margin(at: .right)).to(equal(444))
            }
        }
        
        describe("reloading data") {
            
            it("reloads both table views") {
                let view1 = MockItemTableView(frame: .zero)
                let view2 = MockButtonTableView(frame: .zero)
                sheet = createSheet()
                sheet.itemsTableView = view1
                sheet.buttonsTableView = view2
                sheet.reloadData()
                
                expect(view1.reloadDataInvokeCount).to(equal(1))
                expect(view2.reloadDataInvokeCount).to(equal(1))
            }
        }
    }
}
