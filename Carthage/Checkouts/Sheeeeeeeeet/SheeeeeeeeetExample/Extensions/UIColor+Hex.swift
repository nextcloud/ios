//
//  UIColor+Hex.swift
//  SheeeeeeeeetExample
//
//  Created by Daniel Saidi Daniel on 2016-11-17.
//  Copyright © 2016 Daniel Saidi. All rights reserved.
//

import UIKit


// MARK: - Initialization

public extension UIColor {
    
    public convenience init(hex: Int) {
        self.init(hex: hex, alpha: 1)
    }
    
    public convenience init(hex: Int, alpha: CGFloat) {
        let components = (
            R: CGFloat((hex >> 16) & 0xff) / 255,
            G: CGFloat((hex >> 08) & 0xff) / 255,
            B: CGFloat((hex >> 00) & 0xff) / 255
        )
        self.init(red: components.R, green: components.G, blue: components.B, alpha: alpha)
    }
}


// MARK: - Public Properties

public extension UIColor {
    
    public var hexString: String {
        return hexString(withAlpha: false)
    }
}


// MARK: - Public Functions

public extension UIColor {
    
    public func hexString(withAlpha: Bool) -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        return withAlpha
            ? String(format: "#%02X%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255), Int(a * 255))
            : String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
