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
 
 
 ## Custom presentation
 
 You can also inject a custom sheet presenter if you want to
 customize how your sheet is presented and dismissed. If you
 do not use a custom presenter, `ActionSheetDefaultPresenter`
 is used. It honors the default iOS behavior by using action
 sheets on iPhones and popovers on iPad.
 
 
 ## Subclassing
 
 `ActionSheet` can be subclassed, which may be nice whenever
 you use Sheeeeeeeeet in your own app and want to use an app
 specific domain model. For instance, if you want to present
 a list of `Food` items, you could create a `FoodActionSheet`
 subclass, that is responsible to populate itself with items.
 When you subclass `ActionSheet` you can either override the
 initializers. However, you could also just override `setup`
 and configure the action sheet in your override.
 
 
 ## Appearance
 
 Sheeeeeeeeet's action sheet appearance if easily customized.
 To change the global appearance for every action sheet that
 is used in your app, use `UIActionSheetAppearance.standard`.
 To change the appearance of a single action sheet, use it's
 `appearance` property. To change the appearance of a single
 item, use it's `appearance` property.
 
 
 ## Triggered actions
 
 `ActionSheet` has two actions that are triggered by tapping
 an item. `itemTapAction` is used by the sheet itself when a
 tap occurs on an item. You can override this if you want to,
 but you don't have to. `itemSelectAction`, however, must be
 set to detect when an item is selected after a tap. This is
 the main item action to observe, and the action you provide
 in the initializer.
 
 */

import UIKit

open class ActionSheet: UIViewController {
    
    
    // MARK: - Initialization
    
    public init(
        items: [ActionSheetItem],
        presenter: ActionSheetPresenter = ActionSheet.defaultPresenter,
        action: @escaping SelectAction) {
        self.presenter = presenter
        itemSelectAction = action
        super.init(nibName: nil, bundle: nil)
        setupItemsAndButtons(with: items)
        setup()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        presenter = ActionSheet.defaultPresenter
        itemSelectAction = { _, _ in print("itemSelectAction is not set") }
        super.init(coder: aDecoder)
        setup()
    }
    
    deinit { print("\(type(of: self)) deinit") }
    
    
    // MARK: - Setup
    
    open func setup() {
        view.backgroundColor = .clear
    }
    
    
    // MARK: - View Controller Lifecycle
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        prepareForPresentation()
    }
    
    
    // MARK: - Typealiases
    
    public typealias SelectAction = (ActionSheet, ActionSheetItem) -> ()
    public typealias TapAction = (ActionSheetItem) -> ()
    
    
    // MARK: - Dependencies
    
    open var appearance = ActionSheetAppearance(copy: .standard)
    
    open var presenter: ActionSheetPresenter
    
    
    // MARK: - Actions
    
    open var itemSelectAction: SelectAction
    
    open lazy var itemTapAction: TapAction = { [weak self] item in
        self?.handleTap(on: item)
    }
    
    
    // MARK: - Item Properties
    
    open var buttons = [ActionSheetButton]()
    
    open var items = [ActionSheetItem]()
    
    
    // MARK: - Properties
    
    open var availableItemHeight: CGFloat {
        return UIScreen.main.bounds.height
            - 2 * margin(at: .top)
            - margin(at: .bottom)
            - headerSectionHeight
            - buttonsSectionHeight
    }
    
    open var bottomPresentationFrame: CGRect {
        guard let view = view.superview else { return .zero }
        var frame = view.frame
        let leftMargin = margin(at: .left)
        let rightMargin = margin(at: .right)
        let maxMargin = max(leftMargin, rightMargin)
        frame = frame.insetBy(dx: maxMargin, dy: 0)
        frame.size.height = contentHeight
        frame.origin.y = view.frame.height - contentHeight
        frame.origin.y -= margin(at: .bottom)
        return frame
    }
    
    open var buttonsSectionHeight: CGFloat {
        return buttonsViewHeight
    }
    
    open var buttonsViewHeight: CGFloat {
        return buttons.reduce(0) { $0 + $1.appearance.height }
    }
    
    open var contentHeight: CGFloat {
        return headerSectionHeight + itemsSectionHeight + buttonsSectionHeight
    }
    
    open var contentWidth: CGFloat {
        return super.preferredContentSize.width
    }
    
    open var headerSectionHeight: CGFloat {
        guard headerViewHeight > 0 else { return 0 }
        return headerViewHeight + appearance.contentInset
    }
    
    open var headerViewHeight: CGFloat {
        return headerView?.frame.height ?? 0
    }
    
    open var itemsSectionHeight: CGFloat {
        guard itemsViewHeight > 0 else { return 0 }
        guard buttonsSectionHeight > 0 else { return itemsViewHeight }
        return itemsViewHeight + appearance.contentInset
    }
    
    open var itemsViewHeight: CGFloat {
        let required = requiredItemHeight
        let available = availableItemHeight
        return min(required, available)
    }
    
    open var itemsViewRequiresScrolling: Bool {
        let required = requiredItemHeight
        let available = availableItemHeight
        return available < required
    }
    
    open override var preferredContentSize: CGSize {
        get { return CGSize(width: contentWidth, height: contentHeight) }
        set { super.preferredContentSize = newValue }
    }
    
    open var preferredPopoverSize: CGSize {
        let width = appearance.popover.width
        return CGSize(width: width, height: contentHeight)
    }
    
    open var requiredItemHeight: CGFloat {
        return items.reduce(0) { $0 + $1.appearance.height }
    }


    // MARK: - View Properties
    
    open lazy var buttonsView: UITableView = {
        let tableView = createTableView(handler: buttonHandler)
        view.addSubview(tableView)
        return tableView
    }()

    open var headerView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            guard let header = headerView else { return }
            view.addSubview(header)
        }
    }
    
    open lazy var itemsView: UITableView = {
        let tableView = createTableView(handler: itemHandler)
        view.addSubview(tableView)
        return tableView
    }()
    
    
    // MARK: - Data Properties
    
    public lazy var buttonHandler = ActionSheetItemHandler(actionSheet: self, handles: .buttons)
    
    public lazy var itemHandler = ActionSheetItemHandler(actionSheet: self, handles: .items)

    
    // MARK: - Presentation Functions
    
    open func applyAppearance() {
        itemsView.separatorColor = appearance.itemsSeparatorColor
        buttonsView.separatorColor = appearance.buttonsSeparatorColor
    }
    
    open func dismiss(completion: @escaping () -> ()) {
        presenter.dismiss { completion() }
    }
    
    open func present(in vc: UIViewController, from view: UIView?) {
        prepareForPresentation()
        presenter.present(sheet: self, in: vc.rootViewController, from: view)
    }
    
    open func present(in vc: UIViewController, from barButtonItem: UIBarButtonItem) {
        prepareForPresentation()
        presenter.present(sheet: self, in: vc.rootViewController, from: barButtonItem)
    }
    
    open func prepareForPresentation() {
        applyAppearance()
        items.forEach { $0.applyAppearance(appearance) }
        buttons.forEach { $0.applyAppearance(appearance) }
        applyRoundCorners()
        positionViews()
    }
    
    
    // MARK: - Public Functions
    
    open func margin(at margin: ActionSheetMargin) -> CGFloat {
        let minimum = appearance.contentInset
        return margin.value(in: view.superview, minimum: minimum)
    }
    
    public func item(at indexPath: IndexPath) -> ActionSheetItem {
        return items[indexPath.row]
    }
    
    open func reloadData() {
        itemsView.reloadData()
        buttonsView.reloadData()
    }
    
    open func setupItemsAndButtons(with items: [ActionSheetItem]) {
        self.items = items.filter { !($0 is ActionSheetButton) }
        buttons = items.compactMap { $0 as? ActionSheetButton }
        reloadData()
    }
}


// MARK: - Private Functions

private extension ActionSheet {
    
    func applyRoundCorners() {
        applyRoundCorners(to: headerView)
        applyRoundCorners(to: itemsView)
        applyRoundCorners(to: buttonsView)
    }
    
    func applyRoundCorners(to view: UIView?) {
        view?.clipsToBounds = true
        view?.layer.cornerRadius = appearance.cornerRadius
    }
    
    func createTableView(handler: ActionSheetItemHandler) -> UITableView {
        let tableView = UITableView(frame: view.frame, style: .plain)
        tableView.isScrollEnabled = false
        tableView.tableFooterView = UIView.empty
        tableView.cellLayoutMarginsFollowReadableWidth = false
        tableView.dataSource = handler
        tableView.delegate = handler
        return tableView
    }
    
    func handleTap(on item: ActionSheetItem) {
        reloadData()
        if item.tapBehavior == .dismiss {
            dismiss { self.itemSelectAction(self, item) }
        } else {
            itemSelectAction(self, item)
        }
    }
    
    func positionViews() {
        let width = view.frame.width
        positionHeaderView(width: width)
        positionItemsView(width: width)
        positionButtonsView(width: width)
        positionSheet()
    }
    
    func positionSheet() {
        guard let superview = view.superview else { return }
        guard let frame = presenter.presentationFrame(for: self, in: superview) else { return }
        view.frame = frame
    }
    
    func positionButtonsView(width: CGFloat) {
        buttonsView.frame.origin.x = 0
        buttonsView.frame.origin.y = headerSectionHeight + itemsSectionHeight
        buttonsView.frame.size.width = width
        buttonsView.frame.size.height = buttonsViewHeight
    }
    
    func positionHeaderView(width: CGFloat) {
        guard let view = headerView else { return }
        view.frame.origin = .zero
        view.frame.size.width = width
    }
    
    func positionItemsView(width: CGFloat) {
        itemsView.frame.origin.x = 0
        itemsView.frame.origin.y = headerSectionHeight
        itemsView.frame.size.width = width
        itemsView.frame.size.height = itemsViewHeight
        itemsView.isScrollEnabled = itemsViewRequiresScrolling
    }
}
