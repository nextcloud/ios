//
//  ActionSheet.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-26.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

/*
 
 This is the main class in the Sheeeeeeeeet library. You can
 use it to create action sheets and present them in any view
 controller, from any source view or bar button item.
 
 To create an action sheet, just call the initializer with a
 list of items and buttons and a block that should be called
 whenever an item is selected.
 
 
 ## Items
 
 You provide an action sheet with a collection of items when
 you create it. The sheet will automatically split the items
 into items and buttons. You can also create an action sheet
 with an empty item collection, then call `setup(items:)` at
 a later time. This is sometimes required if you must create
 the action sheet before you can create the items.
 
 
 ## Presentation
 
 You can inject a custom presenter if you want to change how
 the sheet is presented and dismissed. The default presenter
 for iPhone devices is `ActionSheetStandardPresenter`, while
 iPad devices get `ActionSheetPopoverPresenter` instead.
 
 
 ## Subclassing
 
 `ActionSheet` can be subclassed, which may be nice whenever
 you want to use your own domain model. For instance, if you
 want to present a list of `Food` items, you should create a
 `FoodActionSheet` sheet, then populate it with `Food` items.
 The selected value will then be of the type `Food`. You can
 either override the initializers or the `setup` function to
 change how you populate the sheet with items.
 
 
 ## Appearance
 
 Sheeeeeeeeet's action sheet appearance if easily customized.
 To change the global appearance for every sheet in your app,
 just modify `ActionSheetAppearance.standard`. To change the
 appearance of a single action sheet, modify the `appearance`
 property. To change the appearance of a single item, modify
 its `customAppearance` property.
 
 
 ## Handling item selections
 
 The `selectAction` is triggered when a user taps an item in
 the action sheet. It provides you with the action sheet and
 the selected item. It is very important to use `[weak self]`
 in this block to avoid memory leaks.
 
 
 ## Handling item taps
 
 Action sheets receive a call to `handleTap(on:)` every time
 an item is tapped. You can override it when you create your
 own action sheet subclasses, but you probably shouldn't.
 
 */

import UIKit

open class ActionSheet: UIViewController {
    
    
    // MARK: - Initialization
    
    public init(
        items: [ActionSheetItem],
        presenter: ActionSheetPresenter = ActionSheet.defaultPresenter,
        action: @escaping SelectAction) {
        self.presenter = presenter
        selectAction = action
        super.init(nibName: ActionSheet.className, bundle: Bundle(for: ActionSheet.self))
        setup(items: items)
        setup()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        presenter = ActionSheet.defaultPresenter
        selectAction = { _, _ in print("itemSelectAction is not set") }
        super.init(coder: aDecoder)
        setup()
    }
    
    deinit { print("\(type(of: self)) deinit") }
    
    
    // MARK: - Setup
    
    open func setup() {}
    
    open func setup(items: [ActionSheetItem]) {
        self.items = items.filter { !($0 is ActionSheetButton) }
        buttons = items.compactMap { $0 as? ActionSheetButton }
        reloadData()
    }
    
    @available(*, deprecated, message: "setupItemsAndButtons(with:) is deprecated. Use setup(items:) instead")
    open func setupItemsAndButtons(with items: [ActionSheetItem]) {
        setup(items: items)
    }
    
    
    // MARK: - View Controller Lifecycle
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        refresh()
    }
    
    
    // MARK: - Typealiases
    
    public typealias SelectAction = (ActionSheet, ActionSheetItem) -> ()
    
    
    // MARK: - Properties
    
    open var appearance = ActionSheetAppearance(copy: .standard)
    
    public let presenter: ActionSheetPresenter

    public var selectAction: SelectAction
    
    @available(*, deprecated, message: "itemSelectAction is deprecated. Use selectAction instead")
    open var itemSelectAction: SelectAction { return selectAction }
    
    
    // MARK: - Margin Outlets
    
    @IBOutlet weak var topMargin: NSLayoutConstraint?
    @IBOutlet weak var leftMargin: NSLayoutConstraint?
    @IBOutlet weak var rightMargin: NSLayoutConstraint?
    @IBOutlet weak var bottomMargin: NSLayoutConstraint?
    
    
    // MARK: - View Outlets
    
    @IBOutlet weak var backgroundView: UIView?
    @IBOutlet weak var stackView: UIStackView?
    
    
    // MARK: - Header Properties
    
    open var headerView: UIView? {
        didSet { refresh() }
    }
    
    @IBOutlet weak var headerViewContainer: UIView? {
        didSet {
            headerViewContainer?.backgroundColor = .clear
            refreshHeaderVisibility()
        }
    }
    
    @IBOutlet weak var headerViewContainerHeight: NSLayoutConstraint! {
        didSet { refreshHeaderVisibility() }
    }
    
    
    // MARK: - Item Properties
    
    public var items = [ActionSheetItem]()
    
    public var itemsHeight: CGFloat { return totalHeight(for: items) }
    
    public lazy var itemHandler = ActionSheetItemHandler(actionSheet: self, itemType: .items)
    
    @IBOutlet weak var itemsTableView: ActionSheetTableView? {
        didSet { setup(itemsTableView, with: itemHandler) }
    }
    
    @IBOutlet weak var itemsTableViewHeight: NSLayoutConstraint?
    
    
    // MARK: - Button Properties
    
    public var buttons = [ActionSheetButton]()
    
    public var buttonsHeight: CGFloat { return totalHeight(for: buttons) }
    
    public lazy var buttonHandler = ActionSheetItemHandler(actionSheet: self, itemType: .buttons)
    
    @IBOutlet weak var buttonsTableView: ActionSheetTableView? {
        didSet {
            setup(buttonsTableView, with: buttonHandler)
            refreshButtonsVisibility()
        }
    }
    
    @IBOutlet weak var buttonsTableViewHeight: NSLayoutConstraint? {
        didSet { refreshButtonsVisibility() }
    }
    
    
    // MARK: - Presentation Functions
    
    open func dismiss(completion: @escaping () -> () = {}) {
        presenter.dismiss { completion() }
    }

    open func present(in vc: UIViewController, from view: UIView?, completion: @escaping () -> () = {}) {
        refresh()
        presenter.present(sheet: self, in: vc.rootViewController, from: view, completion: completion)
    }

    open func present(in vc: UIViewController, from barButtonItem: UIBarButtonItem, completion: @escaping () -> () = {}) {
        refresh()
        presenter.present(sheet: self, in: vc.rootViewController, from: barButtonItem, completion: completion)
    }

    
    // MARK: - Refresh Functions
    
    open func refresh() {
        applyRoundCorners()
        refreshHeader()
        refreshItems()
        refreshButtons()
        stackView?.spacing = appearance.groupMargins
        presenter.refreshActionSheet()
    }
    
    open func refreshHeader() {
        refreshHeaderVisibility()
        let height = headerView?.frame.height ?? 0
        headerViewContainerHeight?.constant = height
        guard let view = headerView else { return }
        headerViewContainer?.addSubviewToFill(view)
    }
    
    open func refreshHeaderVisibility() {
        headerViewContainer?.isHidden = headerView == nil
    }
    
    open func refreshItems() {
        items.forEach { $0.applyAppearance(appearance) }
        itemsTableView?.backgroundColor = appearance.itemsBackgroundColor
        itemsTableView?.separatorColor = appearance.itemsSeparatorColor
        itemsTableViewHeight?.constant = itemsHeight
    }
    
    open func refreshButtons() {
        refreshButtonsVisibility()
        buttons.forEach { $0.applyAppearance(appearance) }
        buttonsTableView?.backgroundColor = appearance.buttonsBackgroundColor
        buttonsTableView?.separatorColor = appearance.buttonsSeparatorColor
        buttonsTableViewHeight?.constant = buttonsHeight
    }
    
    open func refreshButtonsVisibility() {
        buttonsTableView?.isHidden = buttons.count == 0
    }
    
    
    // MARK: - Protected Functions
    
    open func handleTap(on item: ActionSheetItem) {
        reloadData()
        guard item.tapBehavior == .dismiss else { return selectAction(self, item) }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            self.dismiss { self.selectAction(self, item) }
        }
    }
    
    open func margin(at margin: ActionSheetMargin) -> CGFloat {
        let minimum = appearance.contentInset
        return margin.value(in: view.superview, minimum: minimum)
    }

    open func reloadData() {
        itemsTableView?.reloadData()
        buttonsTableView?.reloadData()
    }
}


// MARK: - Private Functions

private extension ActionSheet {
    
    func applyRoundCorners() {
        applyRoundCorners(to: headerView)
        applyRoundCorners(to: headerViewContainer)
        applyRoundCorners(to: itemsTableView)
        applyRoundCorners(to: buttonsTableView)
    }

    func applyRoundCorners(to view: UIView?) {
        view?.clipsToBounds = true
        view?.layer.cornerRadius = appearance.cornerRadius
    }
    
    func setup(_ tableView: UITableView?, with handler: ActionSheetItemHandler) {
        tableView?.delegate = handler
        tableView?.dataSource = handler
        tableView?.alwaysBounceVertical = false
        setupAppearance(for: tableView)
    }
    
    func setupAppearance(for tableView: UITableView?) {
        tableView?.estimatedRowHeight = 44
        tableView?.rowHeight = UITableView.automaticDimension
        tableView?.cellLayoutMarginsFollowReadableWidth = false
    }
    
    func totalHeight(for items: [ActionSheetItem]) -> CGFloat {
        return items.reduce(0) { $0 + $1.appearance.height }
    }
}
