//
//  UIViewController+RootViewController.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-12-01.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

//  This file contains internal util functions for resolving
//  the root view controller for the current app.

import UIKit

extension UIViewController {

    var rootViewController: UIViewController {
        return parent?.rootViewController ?? self
    }
}
