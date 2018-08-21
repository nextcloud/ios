//
//  CGAffineTransform+Utils.swift
//  WeScan
//
//  Created by Boris Emorine on 2/15/18.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import Foundation

extension CGAffineTransform {
    
    /// Convenience function to easily get a scale `CGAffineTransform` instance.
    ///
    /// - Parameters:
    ///   - fromSize: The size that needs to be transformed to fit (aspect fill) in the other given size.
    ///   - toSize: The size that should be matched by the `fromSize` parameter.
    /// - Returns: The transform that will make the `fromSize` parameter fir (aspect fill) inside the `toSize` parameter.
    static func scaleTransform(forSize fromSize: CGSize, aspectFillInSize toSize: CGSize) -> CGAffineTransform {
        let scale = max(toSize.width / fromSize.width, toSize.height / fromSize.height)
        return CGAffineTransform(scaleX: scale, y: scale)
    }
    
    /// Convenience function to easily get a translate `CGAffineTransform` instance.
    ///
    /// - Parameters:
    ///   - fromRect: The rect which center needs to be translated to the center of the other passed in rect.
    ///   - toRect: The rect that should be matched.
    /// - Returns: The transform that will translate the center of the `fromRect` parameter to the center of the `toRect` parameter.
    static func translateTransform(fromCenterOfRect fromRect: CGRect, toCenterOfRect toRect: CGRect) -> CGAffineTransform {
        let translate = CGPoint(x: toRect.midX - fromRect.midX, y: toRect.midY - fromRect.midY)
        return CGAffineTransform(translationX: translate.x, y: translate.y)
    }
        
}
