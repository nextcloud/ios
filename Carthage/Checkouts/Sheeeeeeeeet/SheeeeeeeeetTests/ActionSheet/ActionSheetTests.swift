//
//  ActionSheetTests.swift
//  SheeeeeeeeetTests
//
//  Created by Daniel Saidi on 2017-11-28.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

//  TODO: Improve these tests, since much logic has changed.

import Quick
import Nimble
@testable import Sheeeeeeeeet

class ActionSheetTests: QuickSpec {
    
    override func spec() {
        
        func createButton(_ title: String) -> ActionSheetButton {
            return ActionSheetOkButton(title: title)
        }
        
        func createItem(_ title: String) -> ActionSheetItem {
            return ActionSheetItem(title: title)
        }
        
        func createSheet(_ items: [ActionSheetItem] = []) -> MockActionSheet {
            return MockActionSheet(items: items, action: { _, _ in })
        }
        
        func createTableView() -> ActionSheetTableView {
            return ActionSheetTableView(frame: .zero)
        }
        
        
        // MARK: - Initialization
        
        describe("when initialized with parameters") {
            
            it("applies provided items") {
                let item1 = createItem("foo")
                let item2 = createItem("bar")
                let sheet = createSheet([item1, item2])
                
                expect(sheet.items.count).to(equal(2))
                expect(sheet.items[0]).to(be(item1))
                expect(sheet.items[1]).to(be(item2))
            }

            it("separates provided items and buttons") {
                let button = createButton("Sheeeeeeeeet")
                let item1 = createItem("foo")
                let item2 = createItem("bar")
                let sheet = createSheet([button, item1, item2])

                expect(sheet.items.count).to(equal(2))
                expect(sheet.items[0]).to(be(item1))
                expect(sheet.items[1]).to(be(item2))
                expect(sheet.buttons.count).to(equal(1))
                expect(sheet.buttons[0]).to(be(button))
            }

            it("applies default presenter if none is provided") {
                let sheet = createSheet()
                let isStandard = sheet.presenter is ActionSheetStandardPresenter
                let isPopover = sheet.presenter is ActionSheetPopoverPresenter
                let isValid = isStandard || isPopover
                
                expect(isValid).to(beTrue())
            }

            it("applies provided presenter") {
                let presenter = ActionSheetPopoverPresenter()
                let sheet = MockActionSheet(items: [], presenter: presenter, action: { _, _ in })
                
                expect(sheet.presenter).to(be(presenter))
            }

            it("applies provided action") {
                var counter = 0
                let sheet = MockActionSheet(items: []) { _, _  in counter += 1 }
                sheet.selectAction(sheet, createItem("foo"))
                
                expect(counter).to(equal(1))
            }
        }
        
        
        // MARK: - Properties

        describe("appearance") {
            
            it("is initially a copy of standard appearance") {
                let original = ActionSheetAppearance.standard.popover.width
                ActionSheetAppearance.standard.popover.width = -1
                let sheet = createSheet()
                let appearance = sheet.appearance
                ActionSheetAppearance.standard.popover.width = original
                
                expect(appearance.popover.width).to(equal(-1))
            }
        }
        
        
        // MARK: - Item Properties
        
        describe("items height") {
            
            it("is sum of all item appearances") {
                let item1 = createItem("foo")
                let item2 = createItem("bar")
                let item3 = createButton("baz")
                item1.appearance.height = 100
                item2.appearance.height = 110
                item3.appearance.height = 120
                let sheet = createSheet([item1, item2, item3])
                
                expect(sheet.itemsHeight).to(equal(210))
            }
        }
        
        describe("item handler") {
            
            it("has correct item type") {
                let sheet = createSheet()
                expect(sheet.itemHandler.itemType).to(equal(.items))
            }
            
            it("has correct items") {
                let item1 = createItem("foo")
                let item2 = createItem("bar")
                let item3 = createButton("baz")
                let sheet = createSheet([item1, item2, item3])
                
                expect(sheet.itemHandler.items.count).to(equal(2))
                expect(sheet.itemHandler.items[0]).to(be(item1))
                expect(sheet.itemHandler.items[1]).to(be(item2))
            }
        }
        
        describe("item table view") {
            
            it("is correctly setup when view is loaded") {
                let sheet = createSheet()
                let view = createTableView()
                sheet.itemsTableView = view
                sheet.viewDidLoad()
                
                expect(view.delegate).to(be(sheet.itemHandler))
                expect(view.dataSource).to(be(sheet.itemHandler))
                expect(view.estimatedRowHeight).to(equal(44))
                expect(view.rowHeight).to(equal(UITableView.automaticDimension))
                expect(view.cellLayoutMarginsFollowReadableWidth).to(beFalse())
            }
        }
        
        
        // MARK: - Button Properties
        
        describe("buttons height") {
            
            it("is sum of all button appearances") {
                let item1 = createItem("foo")
                let item2 = createButton("bar")
                let item3 = createButton("baz")
                item1.appearance.height = 100
                item2.appearance.height = 110
                item3.appearance.height = 120
                let sheet = createSheet([item1, item2, item3])
                
                expect(sheet.buttonsHeight).to(equal(230))
            }
        }
        
        describe("button handler") {
            
            it("has correct item type") {
                let sheet = createSheet()
                expect(sheet.buttonHandler.itemType).to(equal(.buttons))
            }
            
            it("has correct items") {
                let item1 = createItem("foo")
                let item2 = createButton("bar")
                let item3 = createButton("baz")
                let sheet = createSheet([item1, item2, item3])
                
                expect(sheet.buttonHandler.items.count).to(equal(2))
                expect(sheet.buttonHandler.items[0]).to(be(item2))
                expect(sheet.buttonHandler.items[1]).to(be(item3))
            }
        }
        
        describe("button table view") {
            
            it("is correctly setup when view is loaded") {
                let sheet = createSheet()
                let view = createTableView()
                sheet.buttonsTableView = view
                sheet.viewDidLoad()
                
                expect(view.delegate).to(be(sheet.buttonHandler))
                expect(view.dataSource).to(be(sheet.buttonHandler))
                expect(view.estimatedRowHeight).to(equal(44))
                expect(view.rowHeight).to(equal(UITableView.automaticDimension))
                expect(view.cellLayoutMarginsFollowReadableWidth).to(beFalse())
            }
        }
        
        
        // MARK: - Presentation Functions
        
        context("presentation") {
            
            var presenter: MockActionSheetPresenter!
            
            func createSheet() -> MockActionSheet {
                presenter = MockActionSheetPresenter()
                return MockActionSheet(items: [], presenter: presenter, action: { _, _ in })
            }
            
            describe("when dismissed") {
                
                it("dismisses itself by calling presenter") {
                    var counter = 0
                    let completion = { counter += 1 }
                    let sheet = createSheet()
                    sheet.dismiss(completion: completion)
                    presenter.dismissInvokeCompletions[0]()
                    
                    expect(presenter.dismissInvokeCount).to(equal(1))
                    expect(counter).to(equal(1))
                }
            }
            
            describe("when presented from view") {
                
                it("refreshes itself") {
                    let sheet = createSheet()
                    sheet.present(in: UIViewController(), from: UIView())
                    
                    expect(sheet.refreshInvokeCount).to(equal(1))
                }
                
                it("presents itself by calling presenter") {
                    var counter = 0
                    let completion = { counter += 1 }
                    let sheet = createSheet()
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
                    let sheet = createSheet()
                    sheet.present(in: UIViewController(), from: UIBarButtonItem())
                    
                    expect(sheet.refreshInvokeCount).to(equal(1))
                }
                
                it("presents itself by calling presenter") {
                    var counter = 0
                    let completion = { counter += 1 }
                    let sheet = createSheet()
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
        
        
        // MARK: - Refresh Functions
        
        describe("when refreshing") {
            
            var sheet: MockActionSheet!
            var headerViewContainer: UIView!
            var itemsView: ActionSheetTableView!
            var buttonsView: ActionSheetTableView!
            var stackView: UIStackView!
            
            beforeEach {
                sheet = createSheet()
                sheet.appearance.groupMargins = 123
                sheet.appearance.cornerRadius = 90
                headerViewContainer = UIView(frame: .zero)
                itemsView = createTableView()
                buttonsView = createTableView()
                stackView = UIStackView(frame: .zero)
                sheet.headerViewContainer = headerViewContainer
                sheet.itemsTableView = itemsView
                sheet.buttonsTableView = buttonsView
                sheet.stackView = stackView
            }
            
            context("sheet") {
                
                it("applies round corners") {
                    sheet.refresh()
                    
                    expect(headerViewContainer.layer.cornerRadius).to(equal(90))
                    expect(itemsView.layer.cornerRadius).to(equal(90))
                    expect(buttonsView.layer.cornerRadius).to(equal(90))
                }
                
                it("applies stack view spacing") {
                    sheet.refresh()
                    
                    expect(sheet.stackView?.spacing).to(equal(123))
                }
                
                it("asks presenter to refresh sheet") {
                    let presenter = MockActionSheetPresenter()
                    let sheet = MockActionSheet(items: [], presenter: presenter) { (_, _) in }
                    sheet.refresh()
                    
                    expect(presenter.refreshActionSheetInvokeCount).to(equal(1))
                }
            }
            
            context("header") {
                
                it("refreshes header visibility") {
                    sheet.refresh()
                    expect(sheet.refreshHeaderInvokeCount).to(equal(1))
                }
                
                it("adds header view to header container") {
                    let header = UIView(frame: .zero)
                    sheet.headerView = header
                    expect(header.constraints.count).to(equal(0))
                    sheet.refresh()
                    expect(headerViewContainer.subviews.count).to(equal(1))
                    expect(headerViewContainer.subviews[0]).to(be(header))
                    expect(header.translatesAutoresizingMaskIntoConstraints).to(beFalse())
                }
            }
            
            context("header visibility") {
                
                it("hides header container if header view is nil") {
                    sheet.refreshHeader()
                    expect(headerViewContainer.isHidden).to(beTrue())
                }
                
                it("shows header container if header view is nil") {
                    sheet.headerView = UIView(frame: .zero)
                    sheet.refreshHeader()
                    expect(headerViewContainer.isHidden).to(beFalse())
                }
            }
            
            context("items") {
                
                it("applies appearances to all items") {
                    let item1 = MockActionSheetItem(title: "foo")
                    let item2 = MockActionSheetItem(title: "foo")
                    sheet.setup(items: [item1, item2])
                    sheet.refresh()
                    
                    expect(item1.applyAppearanceInvokeCount).to(equal(1))
                    expect(item2.applyAppearanceInvokeCount).to(equal(1))
                    expect(item1.applyAppearanceInvokeAppearances[0]).to(be(sheet.appearance))
                    expect(item2.applyAppearanceInvokeAppearances[0]).to(be(sheet.appearance))
                }
                
                it("applies background color") {
                    sheet.appearance.itemsBackgroundColor = .yellow
                    let view = createTableView()
                    sheet.itemsTableView = view
                    sheet.refresh()
                    
                    expect(view.backgroundColor).to(equal(.yellow))
                }
                
                it("applies separator color") {
                    sheet.appearance.itemsSeparatorColor = .yellow
                    let view = createTableView()
                    sheet.itemsTableView = view
                    sheet.refresh()

                    expect(view.separatorColor).to(equal(.yellow))
                }
            }
            
            context("buttons") {
                
                it("refreshes buttons visibility") {
                    sheet.refresh()
                    expect(sheet.refreshButtonsInvokeCount).to(equal(1))
                }
                
                it("applies appearances to all buttons") {
                    let item1 = MockActionSheetButton(title: "foo", value: true)
                    let item2 = MockActionSheetButton(title: "foo", value: true)
                    sheet.setup(items: [item1, item2])
                    sheet.refresh()
                    
                    expect(item1.applyAppearanceInvokeCount).to(equal(1))
                    expect(item2.applyAppearanceInvokeCount).to(equal(1))
                    expect(item1.applyAppearanceInvokeAppearances[0]).to(be(sheet.appearance))
                    expect(item2.applyAppearanceInvokeAppearances[0]).to(be(sheet.appearance))
                }
                
                it("applies background color") {
                    sheet.appearance.buttonsBackgroundColor = .yellow
                    let view = createTableView()
                    sheet.buttonsTableView = view
                    sheet.refresh()
                    
                    expect(view.backgroundColor).to(equal(.yellow))
                }
                
                it("applies separator color") {
                    sheet.appearance.buttonsSeparatorColor = .yellow
                    let view = createTableView()
                    sheet.buttonsTableView = view
                    sheet.refresh()
                    
                    expect(view.separatorColor).to(equal(.yellow))
                }
            }
            
            context("button visibility") {
                
                it("hides buttons if sheet has no buttons") {
                    sheet.refreshButtons()
                    expect(buttonsView.isHidden).to(beTrue())
                }
                
                it("shows buttons if sheet has buttons") {
                    sheet.setup(items: [MockActionSheetButton(title: "foo", value: true)])
                    sheet.refreshButtons()
                    expect(buttonsView.isHidden).to(beFalse())
                }
            }
        }
        
        
        // MARK: - Protected Functions
        
        describe("handling tap on item") {
            
            it("reloads data") {
                let sheet = createSheet()
                sheet.reloadDataInvokeCount = 0
                sheet.handleTap(on: createItem(""))
                
                expect(sheet.reloadDataInvokeCount).to(equal(1))
            }
            
            it("calls select action without dismiss if item has none tap action") {
                var count = 0
                let sheet = MockActionSheet(items: []) { (_, _) in count += 1 }
                let item = createItem("")
                item.tapBehavior = .none
                sheet.handleTap(on: item)
                
                expect(count).to(equal(1))
                expect(sheet.dismissInvokeCount).to(equal(0))
            }
            
            it("calls select action after dismiss if item has dismiss tap action") {
                var count = 0
                let sheet = MockActionSheet(items: []) { (_, _) in count += 1 }
                let item = createItem("")
                item.tapBehavior = .dismiss
                sheet.handleTap(on: item)
//                expect(count).toEventually(equal(1), time)        TODO
//                expect(sheet.dismissInvokeCount).to(equal(1))     TODO
            }
        }
        
        describe("margin at position") {
            
            it("uses apperance if no superview value exists") {
                let sheet = createSheet()
                sheet.appearance.contentInset = 80
                
                expect(sheet.margin(at: .top)).to(equal(80))
                expect(sheet.margin(at: .left)).to(equal(80))
                expect(sheet.margin(at: .right)).to(equal(80))
                expect(sheet.margin(at: .bottom)).to(equal(80))
            }
        }
        
        describe("reloading data") {
            
            it("reloads both table views") {
                let view1 = MockTableView(frame: .zero)
                let view2 = MockTableView(frame: .zero)
                let sheet = createSheet()
                sheet.itemsTableView = view1
                sheet.buttonsTableView = view2
                sheet.reloadData()
                
                expect(view1.reloadDataInvokeCount).to(equal(1))
                expect(view2.reloadDataInvokeCount).to(equal(1))
            }
        }
    }
}
