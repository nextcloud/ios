//
//  ViewController.swift
//  SheeeeeeeeetExample
//
//  Created by Daniel Saidi on 2017-11-18.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

/*
 
 To make the example easier to overview, the view controller
 has been split up into extension files.
 
 Action sheet appearance is setup by `AppDelegate` using the
 `DemoAppearance` class. You can play around with it to view
 how sheets and items are affected by appearance changes.
 
 */


import UIKit
import Sheeeeeeeeet

class ViewController: UIViewController {

    
    // MARK: - Properties
    
    var foodOptions: [FoodOption] {
        return [.fast, .light, .homeMade, .fancy, .none]
    }
    
    var tableViewOptions: [TableViewOption] = [
        .standard,
        .singleSelect,
        .multiSelect,
        .links,
        .headerView,
        .sections,
        .collections,
        .customView,
        .danger,
        .nonDismissable
    ]
    
    
    // MARK: - Outlets
    
    @IBOutlet weak var tableView: UITableView? {
        didSet {
            tableView?.delegate = self
            tableView?.dataSource = self
        }
    }
    
    @IBAction func testBarButtonTapped(_ sender: UIBarButtonItem) {
        let path = IndexPath(row: 1, section: 0)
        guard let sheet = actionSheet(at: path) else { return }
        sheet.presenter.events.didDismissWithBackgroundTap = { print("Background tap!") }
        sheet.present(in: self, from: sender)
    }
    
    
    // MARK: - Functions
    
    func actionSheet(at indexPath: IndexPath) -> ActionSheet? {
        let options = foodOptions
        switch tableViewOptions[indexPath.row] {
        case .collections: return CollectionActionSheet(options: options, action: alert)
        case .customView: return CustomActionSheet(options: options, buttonTapAction: alert)
        case .danger: return DestructiveActionSheet(options: options, action: alert)
        case .headerView: return HeaderActionSheet(options: options, action: alert)
        case .links: return LinkActionSheet(options: options, action: alert)
        case .multiSelect: return MultiSelectActionSheet(options: options, preselected: [.fancy, .fast], action: alert)
        case .sections: return SectionActionSheet(options: options, action: alert)
        case .singleSelect: return SingleSelectActionSheet(options: options, preselected: [.fancy, .fast], action: alert)
        case .standard: return StandardActionSheet(options: options, action: alert)
        case .nonDismissable:
            let sheet = StandardActionSheet(options: options, action: alert)
            sheet.presenter.isDismissableWithTapOnBackground = false
            return sheet
        }
    }
}
