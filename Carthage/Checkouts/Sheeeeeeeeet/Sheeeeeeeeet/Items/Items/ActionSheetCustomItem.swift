//
//  ActionSheetCustomViewItem.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2018-10-08.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

/*
 
 Custom items can be used to present any views in your sheet.
 It can use any view that inherits `ActionSheetItemCell` and
 implements `ActionSheetCustomItemCell`.
 
 TODO: Unit test
 
 */

import UIKit

public class ActionSheetCustomItem<T: ActionSheetCustomItemCell>: ActionSheetItem {
    
    
    // MARK: - Deprecated - Remove in 1.4.0 ****************
    @available(*, deprecated, message: "applyAppearance will be removed in 1.4.0. Use the new appearance model instead.")
    public override func applyAppearance(_ appearance: ActionSheetAppearance) {
        super.applyAppearance(appearance)
        self.appearance = ActionSheetCustomItemAppearance(copy: appearance.customItem)
        self.appearance.height = T.defaultSize.height
    }
    // MARK: - Deprecated - Remove in 1.4.0 ****************
    
    
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
    
    public override var height: CGFloat { return T.defaultSize.height }
    public let cellType: T.Type
    public let setupAction: SetupAction
    
    
    // MARK: - Functions
    
    open override func cell(for tableView: UITableView) -> ActionSheetItemCell {
        tableView.register(T.nib, forCellReuseIdentifier: cellReuseIdentifier)
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier)
        guard let typedCell = cell as? T else { fatalError("Invalid cell type created by superclass") }
        setupAction(typedCell)
        return typedCell
    }
}


// MARK: -

public protocol ActionSheetCustomItemCell where Self: ActionSheetItemCell {
    
    static var nib: UINib { get }
    static var defaultSize: CGSize { get }
}
