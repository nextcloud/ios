//
//  ActionSheetButton.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-26.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

/*
 
 This class is a base class for all action sheet buttons. It
 is not intended to be used directly. Instead, use the built
 in buttons or subclass it to create your own buttons.
 
 */

import UIKit

open class ActionSheetButton: ActionSheetItem {
    
    
    // MARK: - Deprecated - Remove in 1.4.0 ****************
    @available(*, deprecated, message: "applyAppearance will be removed in 1.4.0. Use the new appearance model instead.")
    open override func applyAppearance(_ appearance: ActionSheetAppearance) {
        self.appearance = customAppearance ?? ActionSheetButtonAppearance(copy: appearance.okButton)
    }
    // MARK: - Deprecated - Remove in 1.4.0 ****************
    
    
    // MARK: - Initialization
    
    public init(title: String, value: Any?) {
        super.init(title: title, value: value)
    }
    
    public init(title: String, type: ButtonType) {
        super.init(title: title, value: type)
    }
    
    
    // MARK: - Values
    
    public enum ButtonType {
        case ok, cancel
    }
    
    
    // MARK: - Functions
    
    open override func cell(for tableView: UITableView) -> ActionSheetItemCell {
        return ActionSheetButtonCell(style: .default, reuseIdentifier: cellReuseIdentifier)
    }
}


// MARK: -

open class ActionSheetButtonCell: ActionSheetItemCell {
    
    open override func refresh() {
        super.refresh()
        textLabel?.textAlignment = .center
    }
}


// MARK: - Button Extensions

public extension ActionSheetItem {
    
    var isOkButton: Bool {
        return value as? ActionSheetButton.ButtonType == .ok
    }
    
    var isCancelButton: Bool {
        return value as? ActionSheetButton.ButtonType == .cancel
    }
}
