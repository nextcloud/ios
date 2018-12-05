//
//  ActionSheetItemAppearance.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-24.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

import UIKit

open class ActionSheetItemAppearance {
    
    
    // MARK: - Initialization
    
    public init() {}
    
    public init(copy: ActionSheetItemAppearance) {
        backgroundColor = copy.backgroundColor
        font = copy.font
        height = copy.height
        separatorInsets = copy.separatorInsets
        textColor = copy.textColor
        tintColor = copy.tintColor
        subtitleFont = copy.subtitleFont
        subtitleTextColor = copy.subtitleTextColor
    }
    
    
    // MARK: - Properties
    
    public var backgroundColor: UIColor?
    public var font: UIFont?
    public var height: CGFloat = 50
    public var separatorInsets: UIEdgeInsets = .zero
    public var textColor: UIColor?
    public var tintColor: UIColor?
    public var subtitleFont: UIFont?
    public var subtitleTextColor: UIColor?
}


// MARK: - Public Extensions

public extension ActionSheetItemAppearance {
    
    public static var noSeparator: UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 100_000)
    }
    
    public func hideSeparator() {
        separatorInsets = ActionSheetItemAppearance.noSeparator
    }
}
