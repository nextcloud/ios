//
//  ActionSheetMargin.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2018-02-22.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

import UIKit

public enum ActionSheetMargin {
    
    case top, left, right, bottom
    
    func value(in view: UIView) -> CGFloat {
        if #available(iOS 11.0, *) {
            let insets = view.safeAreaInsets
            switch self {
            case .top: return insets.top
            case .left: return insets.left
            case .right: return insets.right
            case .bottom: return insets.bottom
            }
        } else {
            return 0
        }
    }
    
    func value(in view: UIView, minimum: CGFloat) -> CGFloat {
        return max(value(in: view), minimum)
    }
}
