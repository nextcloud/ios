//
//  AppDelegate+Appearance.swift
//  SheeeeeeeeetExample
//
//  Created by Daniel Saidi on 2018-10-08.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

/*
 
 This extension isolates how the example app applies colors,
 fonts etc to the example action sheets.
 
 */

import UIKit
import Sheeeeeeeeet

extension AppDelegate {
    
    func applyAppearance() {
        applyViewAppearances()
        applyColors()
        applyFonts()
        applyHeights()
        applyIcons()
        applySelectItemAppearances()
        applySeparatorInsets()
        applyPopoverWidth()
    }
}


private extension AppDelegate {
    
    func applyViewAppearances() {
//        ActionSheetBackgroundView.appearance().backgroundColor = .purple
        ActionSheetHeaderView.appearance().cornerRadius = 10
        ActionSheetTableView.appearance().cornerRadius = 10
//        ActionSheetTableView.appearance().separatorLineColor = .purple
//        ActionSheetItemTableView.appearance().cornerRadius = 20
//        ActionSheetTableView.appearance(whenContainedInInstancesOf: [MultiSelectActionSheet.self]).cornerRadius = 20
    }
    
    func applyColors() {
        ActionSheetItemCell.appearance().titleColor = .darkText
        ActionSheetItemCell.appearance().subtitleColor = .exampleBlue
        ActionSheetItemCell.appearance().tintColor = .darkText
//        ActionSheetItemCell.appearance().separatorColor = .red
//        ActionSheetItemCell.appearance().backgroundColor = red
//        ActionSheetItemCell.appearance(whenContainedInInstancesOf: [ActionSheetItemTableView.self]).backgroundColor = .purple
        ActionSheetOkButtonCell.appearance().titleColor = .darkGray
        ActionSheetCancelButtonCell.appearance().titleColor = .lightGray
        ActionSheetDangerButtonCell.appearance().titleColor = .examplePink
    }
    
    func applyFonts() {
        ActionSheetItemCell.appearance().titleFont = .robotoRegular(size: 17)
        ActionSheetItemCell.appearance().subtitleFont = .robotoRegular(size: 14)
        ActionSheetLinkItemCell.appearance().titleFont = .robotoRegular(size: 17)
        ActionSheetMultiSelectToggleItemCell.appearance().titleFont = .robotoMedium(size: 13)
        ActionSheetSectionTitleCell.appearance().titleFont = .robotoMedium(size: 13)
        ActionSheetTitleCell.appearance().titleFont = .robotoMedium(size: 15)
        ActionSheetOkButtonCell.appearance().titleFont = .robotoBlack(size: 17)
        ActionSheetDangerButtonCell.appearance().titleFont = .robotoMedium(size: 17)
        ActionSheetCancelButtonCell.appearance().titleFont = .robotoRegular(size: 17)
    }
    
    func applyHeights() {
        ActionSheetSectionTitle.height = 20
        ActionSheetSectionMargin.height = 20
    }
    
    func applyIcons() {
        ActionSheetLinkItemCell.appearance().linkIcon = UIImage(named: "ic_arrow_right")
    }
    
    func applySelectItemAppearances() {
        ActionSheetSelectItemCell.appearance().selectedIcon = UIImage(named: "ic_checkmark")
        ActionSheetSelectItemCell.appearance().unselectedIcon = UIImage(named: "ic_empty")
        ActionSheetSelectItemCell.appearance().selectedTintColor = .exampleBlue
        ActionSheetSelectItemCell.appearance().selectedTitleColor = .exampleGreen
        ActionSheetSelectItemCell.appearance().selectedIconColor = .examplePurple
        
        ActionSheetSingleSelectItemCell.appearance().selectedTintColor = .exampleGreen
        ActionSheetSingleSelectItemCell.appearance().selectedTitleFont = .robotoMedium(size: 35)
        ActionSheetSingleSelectItemCell.appearance().selectedSubtitleFont = .robotoMedium(size: 25)
        ActionSheetSingleSelectItemCell.appearance().selectedTitleColor = .examplePurple
        ActionSheetSingleSelectItemCell.appearance().selectedIconColor = .exampleBlue
        
        ActionSheetMultiSelectItemCell.appearance().tintColor = UIColor.darkText.withAlphaComponent(0.4)
        ActionSheetMultiSelectItemCell.appearance().titleColor = UIColor.darkText.withAlphaComponent(0.4)
        ActionSheetMultiSelectItemCell.appearance().selectedTintColor = .examplePurple
        ActionSheetMultiSelectItemCell.appearance().selectedTitleColor = .exampleBlue
        ActionSheetMultiSelectItemCell.appearance().selectedIconColor = .exampleGreen
        
        ActionSheetMultiSelectToggleItemCell.appearance().selectAllSubtitleColor = .lightGray
        ActionSheetMultiSelectToggleItemCell.appearance().deselectAllSubtitleColor = .exampleRed
    }
    
    func applySeparatorInsets() {
        ActionSheetItemCell.appearance().separatorInset = .zero
        ActionSheetTitleCell.appearance().separatorInset = .hiddenSeparator
        ActionSheetSectionTitleCell.appearance().separatorInset = .hiddenSeparator
        ActionSheetSectionMarginCell.appearance().separatorInset = .hiddenSeparator
        ActionSheetMultiSelectToggleItemCell.appearance().separatorInset = .hiddenSeparator
    }
    
    func applyPopoverWidth() {
//        ActionSheet.preferredPopoverWidth = 700
    }
}
