//
//  ActionSheetItem.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-24.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

/*
 
 This class represents a regular action sheet item, like the
 one used in UIAlertController. It has a title as well as an
 optional subtitle, value and image. All other items inherit
 this class, even if they don't make use of these properties.
 
 
 ## Subclassing
 
 You can subclass any item class and customize it in any way
 you need. If you need your subclass to use a different cell,
 just override `cell(for:)` to return the cell you need.
 
 
 ## Appearance
 
 Customizing the appearance of the various action sheet item
 types in Sheeeeeeeeet (as well as of your own custom items),
 is mainly done using the iOS appearance proxy for each item
 cell type. For instance, to change the title text color for
 all `ActionSheetSelectItem` instances (including subclasses),
 type `ActionSheetSelectItem.appearance().titleColor`. It is
 also possible to set these properties for each item as well.
 
 While most appearance is modified on a cell level, some are
 not. For instance, some views in `Views` have apperances of
 their own (e.g. `ActionSheetHeaderView.cornerRadius`). This
 means that you can change more than cell appearance. Have a
 look at the readme for more info on what you can customize.
 
 Action sheet insets, margins and widths are not part of the
 appearance model, but have to be changed for each sheet. If
 you want to change these values for each sheet in youer app,
 I recommend subclassing `ActionSheet` and set these values.
 
 Neither item heights are part of the appearance model. Item
 heights are instead changed by setting the static height of
 each item type, e.g. `ActionSheetTitleItem.height = 20`. It
 is not part of the cell appearance model since an item must
 know about the height before it creates any cells.
 
 
 ## Tap behavior
 
 The default tap behavior of action sheet items is "dismiss",
 which means that the action sheet will dismiss itself after
 handling the item tap. Set `tapBehavior` to `.none`, if you
 don't want the action sheet to be dismissed when an item is
 tapped. Some item types uses `.none` by default.
 
 */

import UIKit

open class ActionSheetItem: NSObject {

    
    // MARK: - Deprecated - Remove in 1.4.0 ****************
    @available(*, deprecated, message: "appearance will be removed in 1.4.0. Use the new appearance model instead.")
    public lazy internal(set) var appearance = ActionSheetItemAppearance(copy: ActionSheetAppearance.standard.item)
    @available(*, deprecated, message: "customAppearance will be removed in 1.4.0. Use the new appearance model instead.")
    public var customAppearance: ActionSheetItemAppearance?
    @available(*, deprecated, message: "applyAppearance will be removed in 1.4.0. Use the new appearance model instead.")
    open func applyAppearance(_ appearance: ActionSheetAppearance) { self.appearance = customAppearance ?? ActionSheetItemAppearance(copy: appearance.item) }
    @available(*, deprecated, message: "applyAppearance(to:) will be removed in 1.4.0. Use the new appearance model instead.")
    open func applyAppearance(to cell: UITableViewCell) { applyLegacyAppearance(to: cell) }
    // MARK: - Deprecated - Remove in 1.4.0 ****************
    
    
    // MARK: - Initialization
    
    public init(
        title: String,
        subtitle: String? = nil,
        value: Any? = nil,
        image: UIImage? = nil,
        tapBehavior: TapBehavior = .dismiss) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.image = image
        self.tapBehavior = tapBehavior
        self.cellStyle = subtitle == nil ? .default : .value1
        super.init()
    }
    
    
    // MARK: - Enums
    
    public enum TapBehavior {
        case dismiss, none
    }


    // MARK: - Properties
    
    public var image: UIImage?
    public var subtitle: String?
    public var tapBehavior: TapBehavior
    public var title: String
    public var value: Any?
    
    public var cellReuseIdentifier: String { return className }
    public var cellStyle: UITableViewCell.CellStyle
    
    
    // MARK: - Height Logic
    
    private static var heights = [String: CGFloat]()
    
    public static var height: CGFloat {
        get { return heights[className] ?? 50 }
        set { heights[className] = newValue }
    }
    
    public var height: CGFloat {
        return type(of: self).height
    }
    
    
    // MARK: - Functions
    
    open func cell(for tableView: UITableView) -> ActionSheetItemCell {
        return ActionSheetItemCell(style: cellStyle, reuseIdentifier: cellReuseIdentifier)
    }
    
    open func handleTap(in actionSheet: ActionSheet) {}
}


// MARK: -

open class ActionSheetItemCell: UITableViewCell {
    
    
    // MARK: - Layout
    
    open override func didMoveToWindow() {
        super.didMoveToWindow()
        refresh()
    }
    
    
    // MARK: - Appearance Properties
    
    @objc public dynamic var titleColor: UIColor?
    @objc public dynamic var titleFont: UIFont?
    @objc public dynamic var subtitleColor: UIColor?
    @objc public dynamic var subtitleFont: UIFont?
    
    
    // MARK: - Private Properties
    
    public private(set) weak var item: ActionSheetItem?
    
    
    // MARK: - Functions
    
    open func refresh() {
        guard let item = item else { return }
        imageView?.image = item.image
        selectionStyle = item.tapBehavior == .none ? .none : .default
        textLabel?.font = titleFont
        textLabel?.text = item.title
        textLabel?.textAlignment = .left
        textLabel?.textColor = titleColor
        detailTextLabel?.font = subtitleFont
        detailTextLabel?.text = item.subtitle
        detailTextLabel?.textColor = subtitleColor
    }
    
    func refresh(with item: ActionSheetItem) {
        self.item = item
        refresh()
    }
}
