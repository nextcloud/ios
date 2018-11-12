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
    
    
    // MARK: - Properties
    
    open var linkAppearance: ActionSheetLinkItemAppearance? {
        return appearance as? ActionSheetLinkItemAppearance
    }
    
    
    // MARK: - Functions
    
    open override func applyAppearance(_ appearance: ActionSheetAppearance) {
        super.applyAppearance(appearance)
        self.appearance = ActionSheetLinkItemAppearance(copy: appearance.linkItem)
    }
    
    open override func applyAppearance(to cell: UITableViewCell) {
        super.applyAppearance(to: cell)
        guard let appearance = linkAppearance else { return }
        cell.accessoryView = UIImageView(image: appearance.linkIcon)
    }
}
