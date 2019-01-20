//
//  UIView+Nib.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2018-10-17.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

//  This file contains internal util functions for resolving
//  the default nib of a certain view instance.

import UIKit

extension UIView {
    
    static var defaultNib: UINib {
        return UINib(nibName: className, bundle: bundle)
    }
}
