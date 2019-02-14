//
//  ActionSheetSelectItem.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-26.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

/*
 
 Select items are used to let the user select one or several
 items in an action sheet. Unlike the `ActionSheetItem` type,
 this type has an `isSelected` state, a selected icon and an
 extended appearance.
 
 This item type is not meant to be used directly. However, a
 `selectItem` appearance property is still available, so you
 can style single and multiselect items in a single way.
 
 Instead of this type, you should use any of its subclasses:
 
 * `ActionSheetSingleSelectItem`
 * `ActionSheetMultiSelectItem`
 
 */

import UIKit

open class ActionSheetSelectItem: ActionSheetItem {
    
    
    // MARK: - Deprecated - Remove in 1.4.0 ****************
    @available(*, deprecated, message: "applyAppearance will be removed in 1.4.0. Use the new appearance model instead.")
    open override func applyAppearance(_ appearance: ActionSheetAppearance) {
        super.applyAppearance(appearance)
        self.appearance = ActionSheetSelectItemAppearance(copy: appearance.selectItem)
    }
    // MARK: - Deprecated - Remove in 1.4.0 ****************
    
    
    // MARK: - Initialization
    
    public init(
        title: String,
        subtitle: String? = nil,
        isSelected: Bool,
        group: String = "",
        value: Any? = nil,
        image: UIImage? = nil,
        tapBehavior: TapBehavior = .dismiss) {
        self.isSelected = isSelected
        self.group = group
        super.init(
            title: title,
            subtitle: subtitle,
            value: value,
            image: image,
            tapBehavior: tapBehavior)
    }
    
    
    // MARK: - Properties
    
    open var group: String
    open var isSelected: Bool
    
    
    // MARK: - Functions
    
    open override func cell(for tableView: UITableView) -> ActionSheetItemCell {
        return ActionSheetSelectItemCell(style: cellStyle, reuseIdentifier: cellReuseIdentifier)
    }
    
    open override func handleTap(in actionSheet: ActionSheet) {
        super.handleTap(in: actionSheet)
        isSelected = !isSelected
    }
}


// MARK: -

open class ActionSheetSelectItemCell: ActionSheetItemCell {
    
    
    // MARK: - Appearance Properties
    
    @objc public dynamic var selectedIcon: UIImage?
    @objc public dynamic var selectedIconColor: UIColor?
    @objc public dynamic var selectedSubtitleColor: UIColor?
    @objc public dynamic var selectedSubtitleFont: UIFont?
    @objc public dynamic var selectedTitleColor: UIColor?
    @objc public dynamic var selectedTitleFont: UIFont?
    @objc public dynamic var selectedTintColor: UIColor?
    @objc public dynamic var unselectedIcon: UIImage?
    @objc public dynamic var unselectedIconColor: UIColor?
    
    
    // MARK: - Functions
    
    open override func refresh() {
        super.refresh()
        guard let item = item as? ActionSheetSelectItem else { return }
        applyAccessoryView(for: item)
        applyAccessoryViewColor(for: item)
        applySubtitleColor(for: item)
        applySubtitleFont(for: item)
        applyTintColor(for: item)
        applyTitleColor(for: item)
        applyTitleFont(for: item)
    }
}


private extension ActionSheetSelectItemCell {
    
    func applyAccessoryView(for item: ActionSheetSelectItem) {
        guard let image = item.isSelected ? selectedIcon : unselectedIcon else { return }
        accessoryView = UIImageView(image: image)
    }
    
    func applyAccessoryViewColor(for item: ActionSheetSelectItem) {
        guard let color = item.isSelected ? selectedIconColor : unselectedIconColor else { return }
        accessoryView?.tintColor = color
    }
    
    func applySubtitleColor(for item: ActionSheetSelectItem) {
        guard let color = item.isSelected ? selectedSubtitleColor : subtitleColor else { return }
        detailTextLabel?.textColor = color
    }
    
    func applySubtitleFont(for item: ActionSheetSelectItem) {
        guard let font = item.isSelected ? selectedSubtitleFont : subtitleFont else { return }
        detailTextLabel?.font = font
    }
    
    func applyTintColor(for item: ActionSheetSelectItem) {
        let defaultTint = type(of: self).appearance().tintColor
        guard let color = item.isSelected ? selectedTintColor : defaultTint else { return }
        tintColor = color
    }
    
    func applyTitleColor(for item: ActionSheetSelectItem) {
        guard let color = item.isSelected ? selectedTitleColor : titleColor else { return }
        textLabel?.textColor = color
    }
    
    func applyTitleFont(for item: ActionSheetSelectItem) {
        guard let font = item.isSelected ? selectedTitleFont : titleFont else { return }
        textLabel?.font = font
    }
}
