//
//  RectangleDetector.swift
//  WeScan
//
//  Created by Boris Emorine on 2/13/18.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import Foundation
import AVFoundation

/// Class used to detect rectangles from an image.
struct RectangleDetector {
    
    /// Detects rectangles from the given image.
    ///
    /// - Parameters:
    ///   - image: The image to detect rectangles on.
    /// - Returns: The biggest detected rectangle on the image.
    static func rectangle(forImage image: CIImage) -> CIRectangleFeature? {
        let rectangleDetector = CIDetector(ofType: CIDetectorTypeRectangle, context: CIContext(options: nil), options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        
        guard let rectangleFeatures = rectangleDetector?.features(in: image) as? [CIRectangleFeature] else {
            return nil
        }
        
        guard let biggestRectangle = rectangleFeatures.biggest() else {
            return nil
        }
        
        return biggestRectangle
    }
    
}
