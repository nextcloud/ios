//
//  ActionSheetLinkItemAppearance.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-24.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

import UIKit

open class ActionSheetLinkItemAppearance: ActionSheetItemAppearance {
    
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
    }
    
    public override init(copy: ActionSheetItemAppearance) {
        super.init(copy: copy)
        guard let copy = copy as? ActionSheetLinkItemAppearance else { return }
        linkIcon = copy.linkIcon
    }
    
    
    // MARK: - Properties
    
    public var linkIcon: UIImage?
}
