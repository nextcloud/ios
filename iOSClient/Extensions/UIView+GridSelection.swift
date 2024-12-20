//
//  UIView+GridSelection.swift
//  Nextcloud
//
//  Created by Sergey Kaliberda on 20.09.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import Foundation

extension UIView {
    func setBorderForGridViewCell(isSelected: Bool) {
        if isSelected {
            layer.borderWidth = 2
            layer.borderColor = NCBrandColor.shared.brandElement.cgColor
            layer.cornerRadius = 4
        } else {
            layer.borderWidth = 0
            layer.borderColor = UIColor.clear.cgColor
            layer.cornerRadius = 0
        }
    }
}
