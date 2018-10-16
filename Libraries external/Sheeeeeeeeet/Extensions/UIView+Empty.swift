//
//  UIView+Empty.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-19.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

import UIKit

extension UIView {

    static var empty: UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        view.backgroundColor = UIColor.clear
        return view
    }
}
