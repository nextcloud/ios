//
//  ActionSheetMultiSelectToggleItem.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2018-03-31.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

/*
 
 Multi-select toggle items can be used together with a group
 of `ActionSheetMultiSelectItem`s. When tapped, it will make
 all multi-select items in the same group select/deselect.
 
 Since this item must know about the multi-select items when
 setting its select/deselect title text, you must provide it
 with an initial `State` when creating it. After that, it is
 able to update itself whenever it is tapped.
 
 */

import UIKit

open class ActionSheetMultiSelectToggleItem: ActionSheetItem {
    
    
    // MARK: - Deprecated - Remove in 1.4.0 ****************
    @available(*, deprecated, message: "applyAppearance will be removed in 1.4.0. Use the new appearance model instead.")
    open override func applyAppearance(_ appearance: ActionSheetAppearance) {
        super.applyAppearance(appearance)
        self.appearance = ActionSheetMultiSelectToggleItemAppearance(copy: appearance.multiSelectToggleItem)
    }
    // MARK: - Deprecated - Remove in 1.4.0 ****************
    
    
    // MARK: - Initialization
    
    public init(title: String, state: State, group: String, selectAllTitle: String, deselectAllTitle: String) {
        self.group = group
        self.state = state
        self.deselectAllTitle = deselectAllTitle
        self.selectAllTitle = selectAllTitle
        super.init(title: title, tapBehavior: .none)
        cellStyle = .value1
    }
    
    
    // MARK: - State
    
    public enum State {
        case selectAll, deselectAll
    }
    
    
    // MARK: - Properties
    
    open var deselectAllTitle: String
    open var group: String
    open var selectAllTitle: String
    open var state: State
    
    
    // MARK: - Functions
    
    open override func cell(for tableView: UITableView) -> ActionSheetItemCell {
        return ActionSheetMultiSelectToggleItemCell(style: cellStyle, reuseIdentifier: cellReuseIdentifier)
    }
    
    open override func handleTap(in actionSheet: ActionSheet) {
        super.handleTap(in: actionSheet)
        let selectItems = actionSheet.items.compactMap { $0 as? ActionSheetMultiSelectItem }
        let items = selectItems.filter { $0.group == group }
        let shouldSelectAll = items.contains { !$0.isSelected }
        items.forEach { $0.isSelected = shouldSelectAll ? true : false }
        updateState(for: actionSheet)
    }
    
    open func updateState(for actionSheet: ActionSheet) {
        let selectItems = actionSheet.items.compactMap { $0 as? ActionSheetMultiSelectItem }
        let items = selectItems.filter { $0.group == group }
        guard items.count > 0 else { return state = .selectAll }
        state = items.contains { !$0.isSelected } ? .selectAll : .deselectAll
    }
}


// MARK: - 

open class ActionSheetMultiSelectToggleItemCell: ActionSheetItemCell {
    
    
    // MARK: - Appearance Properties
    
    @objc public dynamic var deselectAllImage: UIColor?
    @objc public dynamic var deselectAllSubtitleColor: UIColor?
    @objc public dynamic var deselectAllTitleColor: UIColor?
    @objc public dynamic var selectAllImage: UIColor?
    @objc public dynamic var selectAllSubtitleColor: UIColor?
    @objc public dynamic var selectAllTitleColor: UIColor?
    
    
    // MARK: - Public Functions
    
    open override func refresh() {
        super.refresh()
        guard let item = item as? ActionSheetMultiSelectToggleItem else { return }
        let isSelectAll = item.state == .selectAll
        item.subtitle = isSelectAll ? item.selectAllTitle : item.deselectAllTitle
        titleColor = isSelectAll ? selectAllTitleColor : deselectAllTitleColor
        subtitleColor = isSelectAll ? selectAllSubtitleColor : deselectAllSubtitleColor
        super.refresh()
    }
}
