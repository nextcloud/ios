//
//  UIView+Nib.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2018-10-17.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

import UIKit

extension UIView {
    
    static var defaultNib: UINib {
        return UINib(nibName: className, bundle: Bundle(for: self))
    }
}
