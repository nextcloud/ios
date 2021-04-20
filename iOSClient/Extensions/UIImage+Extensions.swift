//
//  UIColor+fixedOrientation.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 27/11/2019.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
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

import UIKit
import Accelerate

extension UIImage {
    
    @objc func resizeImage(size: CGSize, isAspectRation: Bool) -> UIImage? {
        
        let originRatio = self.size.width / self.size.height
        let newRatio = size.width / size.height
        var newSize = size

        if isAspectRation {
            if originRatio < newRatio {
                newSize.height = size.height
                newSize.width = size.height * originRatio
            } else {
                newSize.width = size.width;
                newSize.height = size.width / originRatio
            }
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        self.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        if let image = newImage {
            return image
        }
        return self
    }
    
    func fixedOrientation() -> UIImage? {
        
        guard imageOrientation != UIImage.Orientation.up else {
            // This is default orientation, don't need to do anything
            return self.copy() as? UIImage
        }
        
        guard let cgImage = self.cgImage else {
            // CGImage is not available
            return nil
        }
        
        guard let colorSpace = cgImage.colorSpace, let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: cgImage.bitsPerComponent, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil // Not able to create CGContext
        }
        
        var transform: CGAffineTransform = CGAffineTransform.identity
        
        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: CGFloat.pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: CGFloat.pi / 2.0)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: CGFloat.pi / -2.0)
        case .up, .upMirrored:
            break
        @unknown default:
            break
        }
        
        // Flip image one more time if needed to, this is to prevent flipped image
        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .up, .down, .left, .right:
            break
        @unknown default:
            break
        }
        
        ctx.concatenate(transform)
        
        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
        default:
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            break
        }
        
        guard let newCGImage = ctx.makeImage() else { return nil }
        return UIImage.init(cgImage: newCGImage, scale: 1, orientation: .up)
    }
    
    @objc func image(color: UIColor, size: CGFloat) -> UIImage {
        
        let size = CGSize(width: size, height: size)
        
        UIGraphicsBeginImageContextWithOptions(size, false, self.scale)
        color.setFill()

        let context = UIGraphicsGetCurrentContext()
        context?.translateBy(x: 0, y: size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        context?.setBlendMode(CGBlendMode.normal)

        let rect = CGRect(origin: .zero, size: size)
        guard let cgImage = self.cgImage else { return self }
        context?.clip(to: rect, mask: cgImage)
        context?.fill(rect)

        let newImage = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    func imageColor(_ color: UIColor) -> UIImage {
                
        if #available(iOS 13.0, *) {
            return self.withTintColor(color, renderingMode: .alwaysOriginal)
        } else {
            return UIGraphicsImageRenderer(size: size, format: imageRendererFormat).image { _ in
                color.set()
                withRenderingMode(.alwaysTemplate).draw(at: .zero)
            }
        }
    }
}
