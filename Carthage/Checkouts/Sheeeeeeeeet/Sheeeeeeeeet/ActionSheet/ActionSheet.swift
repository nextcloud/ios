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
 
 
 ## Creating action sheet instances
 
 You create instances of this class by providing `init(...)`
 with the items to present and an action to call whenever an
 item is selected. If you must have an action sheet instance
 before you can setup its items (this may happen when you're
 subclassing), you can setup the items afterwards by calling
 the `setup(items:)` function.
 
 
 ## Subclassing
 
 This class can be subclassed, which is a good practice when
 you want to use your own models in a controlled way. If you
 have a podcast app, you could have a `SleepTimerActionSheet`
 that automatically sets up its `SleepTimerTime` options and
 streamlines how you work with a sleep timer. This is a good
 way to setup the base action sheet for specific use cases.
 
 
 ## Presentation
 
 You can inject a custom presenter if you want to change how
 the sheet is presented and dismissed. The default presenter
 for iPhone devices is `ActionSheetStandardPresenter`, while
 iPad devices most often get an `ActionSheetPopoverPresenter`.
 
 
 ## Appearance
 
 To change the global appearance for all action sheets, just
 modify the `ActionSheetAppearance.standard` to look the way
 you want. To change the appearance of a single action sheet,
 modify its `appearance` property. To change the appearances
 of single items, modify their `customAppearance` property.
 
 
 ## Handling item selections
 
 The `selectAction` is triggered when a user taps an item in
 the action sheet. It provides you with the action sheet and
 the selected item. It is very important to use `[weak self]`
 in this block, to avoid memory leaks.
 
 
 ## Handling item taps
 
 Action sheets receive a call to `handleTap(on:)` every time
 an item is tapped. You can override it if you, for instance,
 want to perform any animations before calling `super`.
 
 */

import UIKit

open class ActionSheet: UIViewController {
    
    
    // MARK: - Deprecated Members
    
    @available(*, deprecated, message: "setupItemsAndButtons(with:) is deprecated and will be removed shortly. Use `setup(items:)` instead")
    open func setupItemsAndButtons(with items: [ActionSheetItem]) { setup(items: items) }
    
    @available(*, deprecated, message: "itemSelectAction is deprecated and will be removed in shortly. Use `selectAction` instead")
    open var itemSelectAction: SelectAction { return selectAction }
    
    
    // MARK: - Initialization
    
    public init(
        items: [ActionSheetItem] = [],
        presenter: ActionSheetPresenter = ActionSheet.defaultPresenter,
        action: @escaping SelectAction) {
        self.presenter = presenter
        selectAction = action
        super.init(nibName: ActionSheet.className, bundle: ActionSheet.bundle)
        setup(items: items)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        presenter = ActionSheet.defaultPresenter
        selectAction = { _, _ in print("itemSelectAction is not set") }
        super.init(coder: aDecoder)
    }
    
    
    // MARK: - Setup
    
    open func setup() {}
    
    open func setup(items: [ActionSheetItem]) {
        self.items = items.filter { !($0 is ActionSheetButton) }
        buttons = items.compactMap { $0 as? ActionSheetButton }
        reloadData()
    }
    
    
    // MARK: - View Controller Lifecycle
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        setup(itemsTableView, with: itemHandler)
        setup(buttonsTableView, with: buttonHandler)
    }
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        refresh()
    }
    
    
    // MARK: - Typealiases
    
    public typealias SelectAction = (ActionSheet, ActionSheetItem) -> ()
    
    
    // MARK: - Init properties
    
    public var presenter: ActionSheetPresenter
    public var selectAction: SelectAction
    
    
    // MARK: - Appearance
    
    public var appearance = ActionSheetAppearance(copy: .standard)
    
    
    // MARK: - Outlets
    
    @IBOutlet weak var backgroundView: UIView?
    @IBOutlet weak var stackView: UIStackView?
    
    @IBOutlet weak var topMargin: NSLayoutConstraint?
    @IBOutlet weak var leftMargin: NSLayoutConstraint?
    @IBOutlet weak var rightMargin: NSLayoutConstraint?
    @IBOutlet weak var bottomMargin: NSLayoutConstraint?
    
    
    // MARK: - Header Properties
    
    open var headerView: UIView?
    
    @IBOutlet weak var headerViewContainer: UIView?
    
    @IBOutlet weak var headerViewContainerHeight: NSLayoutConstraint?
    
    
    // MARK: - Item Properties
    
    public internal(set) var items = [ActionSheetItem]()
    
    public var itemsHeight: CGFloat { return totalHeight(for: items) }
    
    public lazy var itemHandler = ActionSheetItemHandler(actionSheet: self, itemType: .items)
    
    @IBOutlet weak var itemsTableView: ActionSheetTableView?
    
    @IBOutlet weak var itemsTableViewHeight: NSLayoutConstraint?
    
    
    // MARK: - Button Properties
    
    public internal(set) var buttons = [ActionSheetButton]()
    
    public var buttonsHeight: CGFloat { return totalHeight(for: buttons) }
    
    public lazy var buttonHandler = ActionSheetItemHandler(actionSheet: self, itemType: .buttons)
    
    @IBOutlet weak var buttonsTableView: ActionSheetTableView?
    
    @IBOutlet weak var buttonsTableViewHeight: NSLayoutConstraint?
    
    
    // MARK: - Presentation Functions
    
    open func dismiss(completion: @escaping () -> () = {}) {
        presenter.dismiss { completion() }
    }

    open func present(in vc: UIViewController, from view: UIView?, completion: @escaping () -> () = {}) {
        refresh()
        presenter.present(sheet: self, in: vc.rootViewController, from: view, completion: completion)
    }

    open func present(in vc: UIViewController, from item: UIBarButtonItem, completion: @escaping () -> () = {}) {
        refresh()
        presenter.present(sheet: self, in: vc.rootViewController, from: item, completion: completion)
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
        let height = headerView?.frame.height ?? 0
        headerViewContainerHeight?.constant = height
        headerViewContainer?.isHidden = headerView == nil
        guard let view = headerView else { return }
        headerViewContainer?.addSubviewToFill(view)
    }
    
    open func refreshItems() {
        items.forEach { $0.applyAppearance(appearance) }
        itemsTableView?.backgroundColor = appearance.itemsBackgroundColor
        itemsTableView?.separatorColor = appearance.itemsSeparatorColor
        itemsTableViewHeight?.constant = itemsHeight
    }
    
    open func refreshButtons() {
        buttonsTableView?.isHidden = buttons.count == 0
        buttons.forEach { $0.applyAppearance(appearance) }
        buttonsTableView?.backgroundColor = appearance.buttonsBackgroundColor
        buttonsTableView?.separatorColor = appearance.buttonsSeparatorColor
        buttonsTableViewHeight?.constant = buttonsHeight
    }
    
    
    // MARK: - Protected Functions
    
    open func handleTap(on item: ActionSheetItem) {
        reloadData()
        if item.tapBehavior != .dismiss { return selectAction(self, item) }
        self.dismiss { self.selectAction(self, item) }
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
        tableView?.estimatedRowHeight = 44
        tableView?.rowHeight = UITableView.automaticDimension
        tableView?.cellLayoutMarginsFollowReadableWidth = false
    }
    
    func totalHeight(for items: [ActionSheetItem]) -> CGFloat {
        return items.reduce(0) { $0 + $1.appearance.height }
    }
}
