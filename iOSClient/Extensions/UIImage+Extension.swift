//
//  UIImage+Extensions.swift
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

import Foundation
import UIKit
import Accelerate

extension UIImage {

    @objc func resizeImage(size: CGSize, isAspectRation: Bool = true) -> UIImage? {

        let originRatio = self.size.width / self.size.height
        let newRatio = size.width / size.height
        var newSize = size

        if isAspectRation {
            if originRatio < newRatio {
                newSize.height = size.height
                newSize.width = size.height * originRatio
            } else {
                newSize.width = size.width
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

        guard let colorSpace = cgImage.colorSpace,
              let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: cgImage.bitsPerComponent, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
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
        }

        guard let newCGImage = ctx.makeImage() else { return nil }
        return UIImage(cgImage: newCGImage, scale: 1, orientation: .up)
    }

    @objc func image(color: UIColor, size: CGFloat) -> UIImage {
        return image(color: color, width: size, height: size)
    }

    @objc func image(color: UIColor, width: CGFloat, height: CGFloat) -> UIImage {

        let size = CGSize(width: width, height: height)

        UIGraphicsBeginImageContextWithOptions(.init(width: width, height: height), false, self.scale)
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
    
    func isEqualToImage(image: UIImage?) -> Bool {
        if image == nil { return false }
        let data1: NSData = self.pngData()! as NSData
        let data2: NSData = image!.pngData()! as NSData
        return data1.isEqual(data2)
    }

    class func imageWithView(_ view: UIView) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.isOpaque, 0)
        defer { UIGraphicsEndImageContext() }
        view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }

    func image(alpha: CGFloat) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(at: .zero, blendMode: .normal, alpha: alpha)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }

    /// Downsamles a image using ImageIO. Has better memory perfomance than redrawing using UIKit
    ///
    /// - [Source](https://swiftsenpai.com/development/reduce-uiimage-memory-footprint/)
    /// - [Original Source, WWDC18](https://developer.apple.com/videos/play/wwdc2018/416/?time=1352)
    /// - Parameters:
    ///   - imageURL: The URL path of the image
    ///   - pointSize: The target point size
    ///   - scale: The point to pixel scale (Pixeld per point)
    /// - Returns: The downsampled image, if successful
    static func downsample(imageAt imageURL: URL, to pointSize: CGSize, scale: CGFloat = UIScreen.main.scale) -> UIImage? {

        // Create an CGImageSource that represent an image
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, imageSourceOptions) else { return nil }

        // Calculate the desired dimension
        let maxDimensionInPixels = max(pointSize.width, pointSize.height) * scale

        // Perform downsampling
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else { return nil }

        // Return the downsampled image as UIImage
        return UIImage(cgImage: downsampledImage)
    }

    // Source:
    // https://stackoverflow.com/questions/27092354/rotating-uiimage-in-swift/47402811#47402811

    func rotate(radians: Float) -> UIImage? {
        var newSize = CGRect(origin: CGPoint.zero, size: self.size).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, true, self.scale)
        let context = UIGraphicsGetCurrentContext()!

        // Move origin to middle
        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians))
        // Draw the image at its center
        self.draw(in: CGRect(x: -self.size.width / 2, y: -self.size.height / 2, width: self.size.width, height: self.size.height))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }

    func colorizeFolder(metadata: tableMetadata, tableDirectory: tableDirectory? = nil) -> UIImage {
        let serverUrl = metadata.serverUrl + "/" + metadata.fileName
        var image = self
        if let tableDirectory = tableDirectory {
            if let hex = tableDirectory.colorFolder, let color = UIColor(hex: hex) {
                image = self.withTintColor(color, renderingMode: .alwaysOriginal)
            }
        } else if let tableDirectory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, serverUrl)), let hex = tableDirectory.colorFolder, let color = UIColor(hex: hex) {
            image = self.withTintColor(color, renderingMode: .alwaysOriginal)
        }
        return image
    }
}
