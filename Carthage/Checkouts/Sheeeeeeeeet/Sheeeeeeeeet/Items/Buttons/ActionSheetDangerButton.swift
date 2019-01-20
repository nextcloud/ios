//
//  ActionSheetDangerButton.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-27.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

/*
 
 Danger buttons have no special behavior, but can be used to
 indicate that the effect of the action sheet is destructive.
 They should be styled as "dangerous" (e.g. red text), using
 the appearance proxy.
 
 The value of a danger button is `.ok`.
 
 */

import UIKit

open class ActionSheetDangerButton: ActionSheetOkButton {
    
    
    // MARK: - Deprecated - Remove in 1.4.0 ****************
    @available(*, deprecated, message: "applyAppearance will be removed in 1.4.0. Use the new appearance model instead.")
    open override func applyAppearance(_ appearance: ActionSheetAppearance) {
        self.appearance = customAppearance ?? ActionSheetDangerButtonAppearance(copy: appearance.dangerButton)
    }
    // MARK: - Deprecated - Remove in 1.4.0 ****************
    
    
    // MARK: - Functions
    
    open override func cell(for tableView: UITableView) -> ActionSheetItemCell {
        return ActionSheetDangerButtonCell(style: .default, reuseIdentifier: cellReuseIdentifier)
    }
}


// MARK: -

open class ActionSheetDangerButtonCell: ActionSheetButtonCell {}
