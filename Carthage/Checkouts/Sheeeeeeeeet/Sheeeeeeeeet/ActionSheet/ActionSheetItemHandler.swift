//
//  ActionSheetItemHandler.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-24.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

/*
 
 This class is used as data source and delegate for the item
 and button table views of the action sheet class.
 
 */

import UIKit

open class ActionSheetItemHandler: NSObject {
    
    
    // MARK: - Initialization
    
    public init(actionSheet: ActionSheet, itemType: ItemType) {
        self.actionSheet = actionSheet
        self.itemType = itemType
    }
    
    
    // MARK: - Enum
    
    public enum ItemType {
        case items, buttons
    }
    
    
    // MARK: - Properties
    
    private weak var actionSheet: ActionSheet?
    
    let itemType: ItemType
    
    var items: [ActionSheetItem] {
        switch itemType {
        case .buttons: return actionSheet?.buttons ?? []
        case .items: return actionSheet?.items ?? []
        }
    }
}


// MARK: - UITableViewDataSource

extension ActionSheetItemHandler: UITableViewDataSource {
    
    public func item(at indexPath: IndexPath) -> ActionSheetItem? {
        guard indexPath.section == 0 else { return nil }
        guard items.count > indexPath.row else { return nil }
        return items[indexPath.row]
    }
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let item = self.item(at: indexPath) else { return UITableViewCell(frame: .zero) }
        let cell = item.cell(for: tableView)
        item.applyAppearance(to: cell)                      // TODO: Deprecated - Remove in 1.4.0
        cell.refresh(with: item)
        return cell
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let item = self.item(at: indexPath) else { return 0 }
        return CGFloat(item.height)
    }
}


// MARK: - UITableViewDelegate

extension ActionSheetItemHandler: UITableViewDelegate {
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = self.item(at: indexPath) else { return }
        tableView.deselectRow(at: indexPath, animated: true)
        guard let sheet = actionSheet else { return }
        item.handleTap(in: sheet)
        sheet.handleTap(on: item)
    }
}
