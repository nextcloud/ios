//
//  ActionSheetCollectionItem.swift
//  Sheeeeeeeeet
//
//  Created by Jonas Ullström (ullstrm) on 2018-03-01.
//  Copyright © 2018 Jonas Ullström. All rights reserved.
//

/*
 
 Collection items can be used to present item collections in
 a collection view, using cell types that you define in your
 project and implement `ActionSheetCollectionItemContentCell`.
 The cell `.xib` should have the same name as the cell class.
 
 This class will dequeue a different cell type than standard
 action sheet items. If you look at `cell(for: ...)`, you'll
 see that it uses `ActionSheetCollectionItemCell` for its id.
 
 */

import Foundation

open class ActionSheetCollectionItem<T>: ActionSheetItem, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout where T: ActionSheetCollectionItemContentCell {
    
    
    // MARK: - Initialization
    
    public init(
        itemCellType: T.Type,
        itemCount: Int,
        setupAction: @escaping CellAction,
        selectionAction: @escaping CellAction) {
        self.itemCellType = itemCellType
        self.itemCount = itemCount
        self.setupAction = setupAction
        self.selectionAction = selectionAction
        super.init(title: "")
    }
    
    
    // MARK: - Typealiases
    
    public typealias CellAction = (_ cell: T, _ index: Int) -> ()
    
    
    // MARK: - Properties
    
    public let itemCellType: T.Type
    public let itemCount: Int
    public private(set) var selectionAction: CellAction
    public let setupAction: CellAction
    
    
    // MARK: - Functions
    
    open override func applyAppearance(_ appearance: ActionSheetAppearance) {
        super.applyAppearance(appearance)
        self.appearance = ActionSheetCollectionItemAppearance(copy: appearance.collectionItem)
        self.appearance.height = T.defaultSize.height + T.topInset + T.bottomInset + 0.5
    }
    
    open override func applyAppearance(to cell: UITableViewCell) {
        super.applyAppearance(to: cell)
        guard let itemCell = cell as? ActionSheetCollectionItemCell else { return }
        itemCell.setup(withNib: T.nib, owner: self)
    }
    
    open override func cell(for tableView: UITableView) -> UITableViewCell {
        tableView.register(ActionSheetCollectionItemCell.nib, forCellReuseIdentifier: cellReuseIdentifier)
        return super.cell(for: tableView)
    }
    
    open func extendSelectionAction(toReload actionSheet: ActionSheet) {
        extendSelectionAction { _, _ in
            actionSheet.reloadData()
        }
    }
    
    open func extendSelectionAction(with action: @escaping CellAction) {
        let currentSelectionAction = selectionAction
        selectionAction = { cell, index in
            currentSelectionAction(cell, index)
            action(cell, index)
        }
    }
    
    
    // MARK: - UICollectionViewDataSource
    
    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return itemCount
    }
    
    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let id = ActionSheetCollectionItemCell.itemCellIdentifier
        let dequeued = collectionView.dequeueReusableCell(withReuseIdentifier: id, for: indexPath)
        guard let cell = dequeued as? T else { return UICollectionViewCell() }
        setupAction(cell, indexPath.row)
        return cell
    }
    
    
    // MARK: - UICollectionViewDelegate
    
    open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? T else { return }
        selectionAction(cell, indexPath.row)
    }
    
    
    // MARK: - FlowLayout delegate
    
    open func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return T.defaultSize
    }
    
    open func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: T.topInset, left: T.leftInset, bottom: T.bottomInset, right: T.rightInset)
    }
    
    open func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return T.itemSpacing
    }
    
    open func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
}
