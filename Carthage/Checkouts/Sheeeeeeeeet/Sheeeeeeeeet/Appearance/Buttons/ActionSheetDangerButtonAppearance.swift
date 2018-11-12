//
//  ActionSheetDangerButtonAppearance.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-27.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

import UIKit

open class ActionSheetDangerButtonAppearance: ActionSheetButtonAppearance {
    
    public override init() {
        super.init()
        textColor = .red
    }
    
    public override init(copy: ActionSheetItemAppearance) {
        super.init(copy: copy)
        textColor = .red
    }
}
