//
//  Array+Utils.swift
//  WeScan
//
//  Created by Boris Emorine on 2/8/18.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import Foundation

extension Array where Element: CIRectangleFeature {
    
    /// Finds the biggest rectangle within an array of `CIRectangleFeature` objects.
    func biggest() -> CIRectangleFeature? {
        guard count > 1 else {
            return first
        }
        
        let biggestRectangle = self.max(by: { (rect1, rect2) -> Bool in
            return rect1.perimeter() < rect2.perimeter()
        })
        
        return biggestRectangle
    }
    
}
