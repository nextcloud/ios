//
//  TableViewOption.swift
//  SheeeeeeeeetExample
//
//  Created by Daniel Saidi on 2017-11-27.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

/*
 
 This enum is used by the example app, to populate the table
 view in the main example view controller.
 
 */

import UIKit

enum TableViewOption {
    
    case
    danger,
    collections,
    customView,
    headerView,
    links,
    multiSelect,
    nonDismissable,
    sections,
    singleSelect,
    standard
    
    
    var title: String {
        switch self {
        case .collections: return "Collection items"
        case .customView: return "Custom view"
        case .danger: return "Destructive Action"
        case .headerView: return "Header View"
        case .links: return "Link items"
        case .multiSelect: return "Multi-select items"
        case .nonDismissable: return "Non-dismissable sheets"
        case .sections: return "Section items"
        case .singleSelect: return "Single-select items"
        case .standard: return "Standard items"
        }
    }
    
    var description: String {
        switch self {
        case .collections: return "Show a sheet with horizontal collections items."
        case .customView: return "Custom view items can embed any view."
        case .danger: return "Show a sheet with a destructive action."
        case .headerView: return "Show a sheet with a custom header view."
        case .links: return "Show a sheet with tappable links."
        case .multiSelect: return "Show a sheet where you can select multiple values."
        case .nonDismissable: return "Show a sheet that cannot be dismissed by tapping outside the sheet."
        case .sections: return "Show a sheet where items are divided in sections."
        case .singleSelect: return "Show a sheet where you can select a single value."
        case .standard: return "Show a sheet where you can pick a single option."
        }
    }
    
    var image: UIImage? {
        return UIImage(named: imageName)
    }
    
    var imageName: String {
        switch self {
        case .collections: return "ic_view_module"
        case .customView: return "ic_custom"
        case .danger: return "ic_warning"
        case .headerView: return "ic_header_view"
        case .links: return "ic_arrow_right"
        case .multiSelect: return "ic_checkmarks"
        case .sections: return "ic_sections"
        case .singleSelect: return "ic_checkmark"
        case .standard: return "ic_list"
        case .nonDismissable: return "ic_list"
        }
    }
}
