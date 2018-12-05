//
//  ActionSheetItem.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-24.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

/*
 
 This class represents a regular action sheet item, like the
 ones used in UIAlertController. It has a title, an optional
 value and an optional image. All other items builds on this.
 
 The default tap behavior of action sheet items is "dismiss",
 which means that the action sheet will dismiss itself after
 handling the item tap. Set `tapBehavior` to `.none`, if you
 don't want the action sheet to be dismissed when an item is
 tapped. Some item types uses `.none` by default.
 
 The item appearance is set by the sheet. It either uses the
 global appearance or an individual instance. To use a fully
 custom appearances for a single action sheet item, just set
 the `customAppearance` property.
 
 */

import UIKit

open class ActionSheetItem: NSObject {
    
    
    // MARK: - Initialization
    
    public init(
        title: String,
        subtitle: String? = nil,
        value: Any? = nil,
        image: UIImage? = nil,
        tapBehavior: TapBehavior = .dismiss) {
        let appearance = ActionSheetAppearance.standard.item
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.image = image
        self.tapBehavior = tapBehavior
        self.appearance = ActionSheetItemAppearance(copy: appearance)
        super.init()
    }
    
    
    // MARK: - Enums
    
    public enum TapBehavior {
        case dismiss, none
    }


    // MARK: - Properties
    
    public internal(set) var appearance: ActionSheetItemAppearance
    public var image: UIImage?
    public var subtitle: String?
    public var tapBehavior: TapBehavior
    public var title: String
    public var value: Any?
    
    public var cellReuseIdentifier: String { return className }
    public var cellStyle: UITableViewCell.CellStyle = .default
    public var customAppearance: ActionSheetItemAppearance?
    
    
    // MARK: - Functions
    
    open func applyAppearance(_ appearance: ActionSheetAppearance) {
        self.appearance = customAppearance ?? ActionSheetItemAppearance(copy: appearance.item)
    }
    
    open func applyAppearance(to cell: UITableViewCell) {
        if let color = appearance.backgroundColor {
            cell.backgroundColor = color
        }
        cell.imageView?.image = image
        cell.selectionStyle = .default
        cell.separatorInset = appearance.separatorInsets
        cell.tintColor = appearance.tintColor
        cell.textLabel?.text = title
        cell.textLabel?.textAlignment = .left
        cell.textLabel?.textColor = appearance.textColor
        cell.textLabel?.font = appearance.font
        cell.detailTextLabel?.text = subtitle
        cell.detailTextLabel?.font = appearance.subtitleFont
        cell.detailTextLabel?.textColor = appearance.subtitleTextColor
    }
    
    open func cell(for tableView: UITableView) -> UITableViewCell {
        let id = cellReuseIdentifier
        let cell = tableView.dequeueReusableCell(withIdentifier: id) as? ActionSheetItemCell
            ?? ActionSheetItemCell(style: cellStyle, reuseIdentifier: id)
        applyAppearance(to: cell)
        return cell
    }
    
    open func handleTap(in actionSheet: ActionSheet) {}
}
