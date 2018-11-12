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
    
    
    // MARK: - Initialization
    
    public init(title: String, state: State, group: String, selectAllTitle: String, deselectAllTitle: String) {
        self.group = group
        self.state = state
        self.deselectAllTitle = deselectAllTitle
        self.selectAllTitle = selectAllTitle
        super.init(
            title: title,
            tapBehavior: .none)
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
    
    open override func applyAppearance(_ appearance: ActionSheetAppearance) {
        super.applyAppearance(appearance)
        self.appearance = ActionSheetMultiSelectToggleItemAppearance(copy: appearance.multiSelectToggleItem)
    }
    
    open override func applyAppearance(to cell: UITableViewCell) {
        super.applyAppearance(to: cell)
        guard let appearance = appearance as? ActionSheetMultiSelectToggleItemAppearance else { return }
        let isSelectAll = state == .selectAll
        subtitle = isSelectAll ? selectAllTitle : deselectAllTitle
        appearance.subtitleTextColor = isSelectAll ? appearance.selectAllTextColor : appearance.deselectAllTextColor
        super.applyAppearance(to: cell)
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
        state = items.contains { !$0.isSelected } ? .selectAll : .deselectAll
    }
}
