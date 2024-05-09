//
//  NCUtility+Image.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/11/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
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
import NextcloudKit
import PDFKit
import Accelerate
import CoreMedia
import Photos
import SVGKit

extension NCUtility {

    func loadImage(named imageName: String, color: UIColor = NCBrandColor.shared.iconImageColor, size: CGFloat = 50, symbolConfiguration: Any? = nil, renderingMode: UIImage.RenderingMode = .alwaysOriginal) -> UIImage {

        var image: UIImage?

        // see https://stackoverflow.com/questions/71764255
        let sfSymbolName = imageName.replacingOccurrences(of: "_", with: ".")
        if let symbolConfiguration {
            image = UIImage(systemName: sfSymbolName, withConfiguration: symbolConfiguration as? UIImage.Configuration)?.withTintColor(color, renderingMode: renderingMode)
        } else {
            image = UIImage(systemName: sfSymbolName)?.withTintColor(color, renderingMode: renderingMode)
        }
        if image == nil {
            image = UIImage(named: imageName)?.image(color: color, size: size)
        }
        if let image {
            return image
        }

        return  UIImage(systemName: "doc")!.image(color: color, size: size)
    }

    @objc func loadUserImage(for user: String, displayName: String?, userBaseUrl: NCUserBaseUrl) -> UIImage {

        let fileName = userBaseUrl.userBaseUrl + "-" + user + ".png"
        let localFilePath = utilityFileSystem.directoryUserData + "/" + fileName

        if var localImage = UIImage(contentsOfFile: localFilePath) {
            let rect = CGRect(x: 0, y: 0, width: 30, height: 30)
            UIGraphicsBeginImageContextWithOptions(rect.size, false, 3.0)
            UIBezierPath(roundedRect: rect, cornerRadius: rect.size.height).addClip()
            localImage.draw(in: rect)
            localImage = UIGraphicsGetImageFromCurrentImageContext() ?? localImage
            UIGraphicsEndImageContext()
            return localImage
        } else if let loadedAvatar = NCManageDatabase.shared.getImageAvatarLoaded(fileName: fileName) {
            return loadedAvatar
        } else if let displayName = displayName, !displayName.isEmpty, let avatarImg = createAvatar(displayName: displayName, size: 30) {
            return avatarImg
        } else {
            let config = UIImage.SymbolConfiguration(pointSize: 30)
            return loadImage(named: "person.crop.circle", symbolConfiguration: config)
        }
    }

    func imageFromVideo(url: URL, at time: TimeInterval) -> UIImage? {

        let asset = AVURLAsset(url: url)
        let assetIG = AVAssetImageGenerator(asset: asset)

        assetIG.appliesPreferredTrackTransform = true
        assetIG.apertureMode = AVAssetImageGenerator.ApertureMode.encodedPixels

        let cmTime = CMTime(seconds: time, preferredTimescale: 60)
        let thumbnailImageRef: CGImage
        do {
            thumbnailImageRef = try assetIG.copyCGImage(at: cmTime, actualTime: nil)
        } catch let error {
            print("Error: \(error)")
            return nil
        }

        return UIImage(cgImage: thumbnailImageRef)
    }

    func createImageFrom(fileNameView: String, ocId: String, etag: String, classFile: String) {

        var originalImage, scaleImagePreview, scaleImageIcon: UIImage?

        let fileNamePath = utilityFileSystem.getDirectoryProviderStorageOcId(ocId, fileNameView: fileNameView)
        let fileNamePathPreview = utilityFileSystem.getDirectoryProviderStoragePreviewOcId(ocId, etag: etag)
        let fileNamePathIcon = utilityFileSystem.getDirectoryProviderStorageIconOcId(ocId, etag: etag)

        if utilityFileSystem.fileProviderStorageSize(ocId, fileNameView: fileNameView) > 0 && FileManager().fileExists(atPath: fileNamePathPreview) && FileManager().fileExists(atPath: fileNamePathIcon) { return }
        if classFile != NKCommon.TypeClassFile.image.rawValue && classFile != NKCommon.TypeClassFile.video.rawValue { return }

        if classFile == NKCommon.TypeClassFile.image.rawValue {

            originalImage = UIImage(contentsOfFile: fileNamePath)

            scaleImagePreview = originalImage?.resizeImage(size: CGSize(width: NCGlobal.shared.sizePreview, height: NCGlobal.shared.sizePreview))
            scaleImageIcon = originalImage?.resizeImage(size: CGSize(width: NCGlobal.shared.sizeIcon, height: NCGlobal.shared.sizeIcon))

            try? scaleImagePreview?.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: fileNamePathPreview))
            try? scaleImageIcon?.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: fileNamePathIcon))

        } else if classFile == NKCommon.TypeClassFile.video.rawValue {

            let videoPath = NSTemporaryDirectory() + "tempvideo.mp4"
            utilityFileSystem.linkItem(atPath: fileNamePath, toPath: videoPath)

            originalImage = imageFromVideo(url: URL(fileURLWithPath: videoPath), at: 0)

            try? originalImage?.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: fileNamePathPreview))
            try? originalImage?.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: fileNamePathIcon))
        }
    }

    func getImageMetadata(_ metadata: tableMetadata, for size: CGFloat) -> UIImage? {

        if let image = getImage(metadata: metadata) {
            return image
        }

        if metadata.isVideo && !metadata.hasPreview {
            createImageFrom(fileNameView: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)
        }

        if utilityFileSystem.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag) {
            return UIImage(contentsOfFile: utilityFileSystem.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag))
        }

        if metadata.isVideo {
            return UIImage(named: "noPreviewVideo")?.image(color: NCBrandColor.shared.iconImageColor2, size: size)
        } else if metadata.isAudio {
            return UIImage(named: "noPreviewAudio")?.image(color: NCBrandColor.shared.iconImageColor2, size: size)
        } else {
            return UIImage(named: "noPreview")?.image(color: NCBrandColor.shared.iconImageColor2, size: size)
        }
    }

    func getImage(metadata: tableMetadata) -> UIImage? {

        let ext = (metadata.fileNameView as NSString).pathExtension.uppercased()
        var image: UIImage?

        if utilityFileSystem.fileProviderStorageExists(metadata) && metadata.isImage {

            let previewPath = utilityFileSystem.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)
            let iconPath = utilityFileSystem.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)
            let imagePath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)

            if ext == "GIF" {
                if !FileManager().fileExists(atPath: previewPath) {
                    createImageFrom(fileNameView: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)
                }
                image = UIImage.animatedImage(withAnimatedGIFURL: URL(fileURLWithPath: imagePath))
            } else if ext == "SVG" {
                if let svgImage = SVGKImage(contentsOfFile: imagePath) {
                    svgImage.size = CGSize(width: NCGlobal.shared.sizePreview, height: NCGlobal.shared.sizePreview)
                    if let image = svgImage.uiImage {
                        if !FileManager().fileExists(atPath: previewPath) {
                            do {
                                try image.pngData()?.write(to: URL(fileURLWithPath: previewPath), options: .atomic)
                                try image.pngData()?.write(to: URL(fileURLWithPath: iconPath), options: .atomic)
                            } catch { }
                        }
                        return image
                    } else {
                        return nil
                    }
                } else {
                    return nil
                }
            } else {
                createImageFrom(fileNameView: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)
                image = UIImage(contentsOfFile: imagePath)
            }
        }
        return image
    }

    func imageFromVideo(url: URL, at time: TimeInterval, completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global().async {

            let asset = AVURLAsset(url: url)
            let assetIG = AVAssetImageGenerator(asset: asset)

            assetIG.appliesPreferredTrackTransform = true
            assetIG.apertureMode = AVAssetImageGenerator.ApertureMode.encodedPixels

            let cmTime = CMTime(seconds: time, preferredTimescale: 60)
            let thumbnailImageRef: CGImage
            do {
                thumbnailImageRef = try assetIG.copyCGImage(at: cmTime, actualTime: nil)
            } catch let error {
                print("Error: \(error)")
                return completion(nil)
            }

            DispatchQueue.main.async {
                completion(UIImage(cgImage: thumbnailImageRef))
            }
        }
    }

    func createFilePreviewImage(ocId: String, etag: String, fileNameView: String, classFile: String, status: Int, createPreviewMedia: Bool) -> UIImage? {

        var imagePreview: UIImage?
        let filePath = utilityFileSystem.getDirectoryProviderStorageOcId(ocId, fileNameView: fileNameView)
        let iconImagePath = utilityFileSystem.getDirectoryProviderStorageIconOcId(ocId, etag: etag)

        if FileManager.default.fileExists(atPath: iconImagePath) {
            imagePreview = UIImage(contentsOfFile: iconImagePath)
        } else if !createPreviewMedia {
            return nil
        } else if createPreviewMedia && status >= NCGlobal.shared.metadataStatusNormal && classFile == NKCommon.TypeClassFile.image.rawValue && FileManager().fileExists(atPath: filePath) {
            if let image = UIImage(contentsOfFile: filePath), let image = image.resizeImage(size: CGSize(width: NCGlobal.shared.sizeIcon, height: NCGlobal.shared.sizeIcon)), let data = image.jpegData(compressionQuality: 0.5) {
                do {
                    try data.write(to: URL(fileURLWithPath: iconImagePath), options: .atomic)
                    imagePreview = image
                } catch { }
            }
        } else if createPreviewMedia && status >= NCGlobal.shared.metadataStatusNormal && classFile == NKCommon.TypeClassFile.video.rawValue && FileManager().fileExists(atPath: filePath) {
            if let image = imageFromVideo(url: URL(fileURLWithPath: filePath), at: 0), let image = image.resizeImage(size: CGSize(width: NCGlobal.shared.sizeIcon, height: NCGlobal.shared.sizeIcon)), let data = image.jpegData(compressionQuality: 0.5) {
                do {
                    try data.write(to: URL(fileURLWithPath: iconImagePath), options: .atomic)
                    imagePreview = image
                } catch { }
            }
        }

        return imagePreview
    }

    @objc func pdfThumbnail(url: URL, width: CGFloat = 240) -> UIImage? {

        guard let data = try? Data(contentsOf: url), let page = PDFDocument(data: data)?.page(at: 0) else {
            return nil
        }

        let pageSize = page.bounds(for: .mediaBox)
        let pdfScale = width / pageSize.width

        // Apply if you're displaying the thumbnail on screen
        let scale = UIScreen.main.scale * pdfScale
        let screenSize = CGSize(width: pageSize.width * scale, height: pageSize.height * scale)

        return page.thumbnail(of: screenSize, for: .mediaBox)
    }

    func createAvatar(displayName: String, size: CGFloat) -> UIImage? {
        guard let initials = displayName.uppercaseInitials else {
            return nil
        }
        let userColor = NCGlobal.shared.usernameToColor(displayName)
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        var avatarImage: UIImage?

        UIGraphicsBeginImageContextWithOptions(rect.size, false, 3.0)
        let context = UIGraphicsGetCurrentContext()
        UIBezierPath(roundedRect: rect, cornerRadius: rect.size.height).addClip()
        context?.setFillColor(userColor)
        context?.fill(rect)
        let textStyle = NSMutableParagraphStyle()
        textStyle.alignment = NSTextAlignment.center
        let lineHeight = UIFont.systemFont(ofSize: UIFont.systemFontSize).pointSize
        NSString(string: initials)
            .draw(
                in: CGRect(x: 0, y: (size - lineHeight) / 2, width: size, height: lineHeight),
                withAttributes: [NSAttributedString.Key.paragraphStyle: textStyle])
        avatarImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return avatarImage
    }

    func convertSVGtoPNGWriteToUserData(svgUrlString: String, fileName: String? = nil, width: CGFloat? = nil, rewrite: Bool, account: String, id: Int? = nil, completion: @escaping (_ imageNamePath: String?, _ id: Int?) -> Void) {

        var fileNamePNG = ""

        guard let svgUrlString = svgUrlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let iconURL = URL(string: svgUrlString) else {
            return completion(nil, id)
        }

        if let fileName = fileName {
            fileNamePNG = fileName
        } else {
            fileNamePNG = iconURL.deletingPathExtension().lastPathComponent + ".png"
        }

        let imageNamePath = utilityFileSystem.directoryUserData + "/" + fileNamePNG

        if !FileManager.default.fileExists(atPath: imageNamePath) || rewrite == true {

            NextcloudKit.shared.downloadContent(serverUrl: iconURL.absoluteString) { _, data, error in

                if error == .success && data != nil {

                    if let image = UIImage(data: data!) {

                        var newImage: UIImage = image

                        if width != nil {

                            let ratio = image.size.height / image.size.width
                            let newSize = CGSize(width: width!, height: width! * ratio)

                            let renderFormat = UIGraphicsImageRendererFormat.default()
                            renderFormat.opaque = false
                            let renderer = UIGraphicsImageRenderer(size: CGSize(width: newSize.width, height: newSize.height), format: renderFormat)
                            newImage = renderer.image { _ in
                                image.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
                            }
                        }

                        guard let pngImageData = newImage.pngData() else {
                            return completion(nil, id)
                        }

                        try? pngImageData.write(to: URL(fileURLWithPath: imageNamePath))

                        return completion(imageNamePath, id)

                    } else {

                        guard let svgImage: SVGKImage = SVGKImage(data: data) else {
                            return completion(nil, id)
                        }

                        if width != nil {
                            let scale = svgImage.size.height / svgImage.size.width
                            svgImage.size = CGSize(width: width!, height: width! * scale)
                        }

                        guard let image: UIImage = svgImage.uiImage else {
                            return completion(nil, id)
                        }
                        guard let pngImageData = image.pngData() else {
                            return completion(nil, id)
                        }

                        try? pngImageData.write(to: URL(fileURLWithPath: imageNamePath))

                        return completion(imageNamePath, id)
                    }
                } else {
                    return completion(nil, id)
                }
            }

        } else {
            return completion(imageNamePath, id)
        }
    }

    func getSizePreview(width: Int, height: Int) -> CGSize {
        var widthPreview: Double = Double(NCGlobal.shared.sizePreview)
        var heightPreview: Double = Double(NCGlobal.shared.sizePreview)

        if width > 0, height > 0 {
            var ratio: Double = 0
            if width >= height {
                ratio = Double(width) / Double(height)
                heightPreview = widthPreview / ratio
            } else {
                ratio = Double(height) / Double(width)
                widthPreview = heightPreview / ratio
            }
        }
        return CGSize(width: widthPreview, height: heightPreview)
    }
}
