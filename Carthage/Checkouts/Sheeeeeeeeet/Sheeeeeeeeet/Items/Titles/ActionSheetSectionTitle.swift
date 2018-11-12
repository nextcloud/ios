//
//  ActionSheetSectionTitle.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-26.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

/*
 
 Section title items can be used to segment action sheets in
 sections. They serve no purpose beyond to visually indicate
 that certain items belong together. A section item can have
 a title and a subtitle.
 
 To add additional space above a section title, make sure to
 add a `ActionSheetSectionMargin` before the section title.
 
 */

import UIKit

open class ActionSheetSectionTitle: ActionSheetItem {
    
    
    // MARK: - Initialization
    
    public init(title: String, subtitle: String? = nil) {
        super.init(title: title, subtitle: subtitle, tapBehavior: .none)
        cellStyle = .value1
    }
    
    
    // MARK: - Functions
    
    open override func applyAppearance(_ appearance: ActionSheetAppearance) {
        self.appearance = ActionSheetSectionTitleAppearance(copy: appearance.sectionTitle)
    }
    
    open override func applyAppearance(to cell: UITableViewCell) {
        super.applyAppearance(to: cell)
        cell.selectionStyle = .none
    }
}
