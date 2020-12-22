//
//  UIImageView+Extensions.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 22/12/20.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//


import Foundation

extension UIImageView {
    
    func avatar(roundness: CGFloat, borderWidth: CGFloat, borderColor: UIColor, backgroundColor: UIColor, disable: Bool = false) {
     
        if disable {
            
            layer.mask = nil
            
        } else {
        
            layer.cornerRadius = bounds.width / roundness
            layer.borderWidth = borderWidth
            layer.borderColor = borderColor.cgColor
            layer.backgroundColor = backgroundColor.cgColor
            clipsToBounds = true
            
            let path = UIBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), cornerRadius: bounds.width / roundness)
            let mask = CAShapeLayer()
            
            mask.path = path.cgPath
            layer.mask = mask
        }
    }
}
