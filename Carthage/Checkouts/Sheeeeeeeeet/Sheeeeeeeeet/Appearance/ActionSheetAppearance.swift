//
//  ActionSheetAppearance.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-18.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

/*
 
 This class is used to specify the appearance for all action
 sheets and action sheet items provided by Sheeeeeeeeet. Use
 `ActionSheetAppearance.standard` to style all action sheets
 in an entire app. You can then apply individual appearances
 to individual action sheets and item types.
 
 The `item` appearance property is used as the base template
 for all other item appearances.
 
 */

import UIKit

open class ActionSheetAppearance {
    
    
    // MARK: - Initialization
    
    public init() {}
    
    public init(copy: ActionSheetAppearance) {
        cornerRadius = copy.cornerRadius
        contentInset = copy.contentInset
        groupMargins = copy.groupMargins
        
        backgroundColor = copy.backgroundColor
        itemsBackgroundColor = copy.itemsBackgroundColor ?? backgroundColor
        buttonsSeparatorColor = copy.buttonsSeparatorColor ?? backgroundColor
        
        separatorColor = copy.separatorColor
        itemsSeparatorColor = copy.itemsSeparatorColor ?? separatorColor
        buttonsSeparatorColor = copy.buttonsSeparatorColor ?? separatorColor
        
        item = ActionSheetItemAppearance(copy: copy.item)
        popover = ActionSheetPopoverAppearance(copy: copy.popover)
        
        cancelButton = ActionSheetCancelButtonAppearance(copy: copy.cancelButton)
        dangerButton = ActionSheetDangerButtonAppearance(copy: copy.dangerButton)
        okButton = ActionSheetOkButtonAppearance(copy: copy.okButton)
        
        collectionItem = ActionSheetCollectionItemAppearance(copy: copy.collectionItem)
        customItem = ActionSheetCustomItemAppearance(copy: copy.customItem)
        linkItem = ActionSheetLinkItemAppearance(copy: copy.linkItem)
        multiSelectItem = ActionSheetMultiSelectItemAppearance(copy: copy.multiSelectItem)
        multiSelectToggleItem = ActionSheetMultiSelectToggleItemAppearance(copy: copy.multiSelectToggleItem)
        selectItem = ActionSheetSelectItemAppearance(copy: copy.selectItem)
        singleSelectItem = ActionSheetSingleSelectItemAppearance(copy: copy.singleSelectItem)
        
        sectionMargin = ActionSheetSectionMarginAppearance(copy: copy.sectionMargin)
        sectionTitle = ActionSheetSectionTitleAppearance(copy: copy.sectionTitle)
        title = ActionSheetTitleAppearance(copy: copy.title)
    }
    
    
    // MARK: - Properties
    
    public var cornerRadius: CGFloat = 10
    public var contentInset: CGFloat = 15
    public var groupMargins: CGFloat = 15
    
    public var backgroundColor: UIColor?
    public var separatorColor: UIColor?
    public var itemsBackgroundColor: UIColor?
    public var itemsSeparatorColor: UIColor?
    public var buttonsBackgroundColor: UIColor?
    public var buttonsSeparatorColor: UIColor?
    
    
    // MARK: - Appearance Properties
    
    public static var standard = ActionSheetAppearance()
    
    public lazy var item: ActionSheetItemAppearance = {
        return ActionSheetItemAppearance()
    }()
    
    public lazy var popover: ActionSheetPopoverAppearance = {
        return ActionSheetPopoverAppearance(width: 300)
    }()
    
    
    // MARK: - Buttons
    
    public lazy var cancelButton: ActionSheetCancelButtonAppearance = {
        return ActionSheetCancelButtonAppearance(copy: item)
    }()
    
    public lazy var dangerButton: ActionSheetDangerButtonAppearance = {
        return ActionSheetDangerButtonAppearance(copy: item)
    }()
    
    public lazy var okButton: ActionSheetOkButtonAppearance = {
        return ActionSheetOkButtonAppearance(copy: item)
    }()
    
    
    // MARK: - Items
    
    public lazy var collectionItem: ActionSheetCollectionItemAppearance = {
        return ActionSheetCollectionItemAppearance(copy: item)
    }()
    
    public lazy var customItem: ActionSheetCustomItemAppearance = {
        return ActionSheetCustomItemAppearance(copy: item)
    }()
    
    public lazy var linkItem: ActionSheetLinkItemAppearance = {
        return ActionSheetLinkItemAppearance(copy: item)
    }()
    
    public lazy var multiSelectItem: ActionSheetMultiSelectItemAppearance = {
        return ActionSheetMultiSelectItemAppearance(copy: selectItem)
    }()
    
    public lazy var multiSelectToggleItem: ActionSheetMultiSelectToggleItemAppearance = {
        return ActionSheetMultiSelectToggleItemAppearance(copy: item)
    }()
    
    public lazy var selectItem: ActionSheetSelectItemAppearance = {
        return ActionSheetSelectItemAppearance(copy: item)
    }()
    
    public lazy var singleSelectItem: ActionSheetSingleSelectItemAppearance = {
        return ActionSheetSingleSelectItemAppearance(copy: selectItem)
    }()
    
    
    // MARK: - Titles
    
    public lazy var sectionMargin: ActionSheetSectionMarginAppearance = {
        return ActionSheetSectionMarginAppearance(copy: item)
    }()
    
    public lazy var sectionTitle: ActionSheetSectionTitleAppearance = {
        return ActionSheetSectionTitleAppearance(copy: item)
    }()
    
    public lazy var title: ActionSheetTitleAppearance = {
        return ActionSheetTitleAppearance(copy: item)
    }()
}
