//
//  ActionSheetCustomViewItem.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2018-10-08.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

/*
 
 Custom items can be used to present any view in your sheets.
 Just specify the view type you want to use and make sure it
 inherits `ActionSheetItemCell`, and that it also implements
 `ActionSheetCustomItemCell`.
 
 */

import UIKit

public class ActionSheetCustomItem<T>: ActionSheetItem where T: ActionSheetCustomItemCell {
    
    
    // MARK: - Initialization
    
    public init(cellType: T.Type, setupAction: @escaping SetupAction) {
        self.cellType = cellType
        self.setupAction = setupAction
        super.init(
            title: "",
            subtitle: nil,
            value: nil,
            image: nil,
            tapBehavior: .none)
    }
    
    
    // MARK: - Typealiases
    
    public typealias SetupAction = (_ cell: T) -> ()
    
    
    // MARK: - Properties
    
    public let cellType: T.Type
    public let setupAction: SetupAction
    
    
    // MARK: - Functions
    
    public override func applyAppearance(_ appearance: ActionSheetAppearance) {
        super.applyAppearance(appearance)
        self.appearance = ActionSheetCustomItemAppearance(copy: appearance.customItem)
        self.appearance.height = T.defaultSize.height
    }
    
    open override func cell(for tableView: UITableView) -> UITableViewCell {
        tableView.register(T.nib, forCellReuseIdentifier: cellReuseIdentifier)
        let cell = super.cell(for: tableView)
        cell.selectionStyle = .none
        guard let typedCell = cell as? T else { fatalError("Invalid cell type created by superclass") }
        setupAction(typedCell)
        return typedCell
    }
}
