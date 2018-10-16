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
 in buttons or subclass this class to create your own button.
 
 */

import UIKit

open class ActionSheetButton: ActionSheetItem {
    
    
    // MARK: - Initialization
    
    public init(title: String, value: Bool?) {
        super.init(title: title, value: value)
    }
    
    
    // MARK: - Properties
    
    open override var itemType: ItemType { return .button }
    
    
    // MARK: - Functions
    
    open override func applyAppearance(_ appearance: ActionSheetAppearance) {
        self.appearance = ActionSheetButtonAppearance(copy: appearance.okButton)
    }
    
    open override func applyAppearance(to cell: UITableViewCell) {
        super.applyAppearance(to: cell)
        cell.textLabel?.textAlignment = .center
    }
}
