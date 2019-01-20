//
//  ActionSheetLinkItem.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-26.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

/*
 
 Link items can be used when tapping them will take the user
 somewhere, e.g. to another view controller or a web site.
 
 */

import UIKit

open class ActionSheetLinkItem: ActionSheetItem {
    
    
    // MARK: - Deprecated - Remove in 1.4.0 ****************
    @available(*, deprecated, message: "linkAppearance will be removed in 1.4.0. Use the new appearance model instead.")
    open var linkAppearance: ActionSheetLinkItemAppearance? {
        return appearance as? ActionSheetLinkItemAppearance
    }
    @available(*, deprecated, message: "applyAppearance will be removed in 1.4.0. Use the new appearance model instead.")
    open override func applyAppearance(_ appearance: ActionSheetAppearance) {
        super.applyAppearance(appearance)
        self.appearance = ActionSheetLinkItemAppearance(copy: appearance.linkItem)
    }
    // MARK: - Deprecated - Remove in 1.4.0 ****************
    
    
    // MARK: - Functions
    
    open override func cell(for tableView: UITableView) -> ActionSheetItemCell {
        return ActionSheetLinkItemCell(style: cellStyle, reuseIdentifier: cellReuseIdentifier)
    }
}


open class ActionSheetLinkItemCell: ActionSheetItemCell {
    
    
    // MARK: - Appearance Properties
    
    @objc public dynamic var linkIcon: UIImage?
    
    
    // MARK: - Functions
    
    open override func refresh() {
        super.refresh()
        accessoryView = UIImageView(image: linkIcon)
    }
}
