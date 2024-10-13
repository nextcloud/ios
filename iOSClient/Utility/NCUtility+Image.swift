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
    func loadImage(named imageName: String, colors: [UIColor]? = nil, size: CGFloat? = nil, useTypeIconFile: Bool = false, account: String? = nil) -> UIImage {
        var image: UIImage?

        if useTypeIconFile {
            switch imageName {
            case NKCommon.TypeIconFile.audio.rawValue: image = UIImage(systemName: "waveform", withConfiguration: UIImage.SymbolConfiguration(weight: .thin))?.applyingSymbolConfiguration(UIImage.SymbolConfiguration(paletteColors: [NCBrandColor.shared.iconImageColor2]))
            case NKCommon.TypeIconFile.code.rawValue: image = UIImage(systemName: "ellipsis.curlybraces", withConfiguration: UIImage.SymbolConfiguration(weight: .thin))?.applyingSymbolConfiguration(UIImage.SymbolConfiguration(paletteColors: [NCBrandColor.shared.iconImageColor2]))
            case NKCommon.TypeIconFile.compress.rawValue: image = UIImage(systemName: "doc.zipper", withConfiguration: UIImage.SymbolConfiguration(weight: .thin))?.applyingSymbolConfiguration(UIImage.SymbolConfiguration(paletteColors: [NCBrandColor.shared.iconImageColor2]))
            case NKCommon.TypeIconFile.directory.rawValue: image = UIImage(named: "folder")! .image(color: NCBrandColor.shared.getElement(account: account), size: UIScreen.main.bounds.width / 2)
            case NKCommon.TypeIconFile.document.rawValue: image = UIImage(systemName: "doc.richtext", withConfiguration: UIImage.SymbolConfiguration(weight: .thin))?.applyingSymbolConfiguration(UIImage.SymbolConfiguration(paletteColors: [NCBrandColor.shared.documentIconColor]))
            case NKCommon.TypeIconFile.image.rawValue: image = UIImage(systemName: "photo", withConfiguration: UIImage.SymbolConfiguration(weight: .thin))?.applyingSymbolConfiguration(UIImage.SymbolConfiguration(paletteColors: [NCBrandColor.shared.iconImageColor2]))
            case NKCommon.TypeIconFile.movie.rawValue: image = UIImage(systemName: "video", withConfiguration: UIImage.SymbolConfiguration(weight: .thin))?.applyingSymbolConfiguration(UIImage.SymbolConfiguration(paletteColors: [NCBrandColor.shared.iconImageColor2]))
            case NKCommon.TypeIconFile.pdf.rawValue: image = UIImage(named: "file_pdf")!
            case NKCommon.TypeIconFile.ppt.rawValue: image = UIImage(systemName: "play.rectangle", withConfiguration: UIImage.SymbolConfiguration(weight: .thin))?.applyingSymbolConfiguration(UIImage.SymbolConfiguration(paletteColors: [NCBrandColor.shared.presentationIconColor]))
            case NKCommon.TypeIconFile.txt.rawValue: image = UIImage(systemName: "doc.text", withConfiguration: UIImage.SymbolConfiguration(weight: .thin))?.applyingSymbolConfiguration(UIImage.SymbolConfiguration(paletteColors: [NCBrandColor.shared.iconImageColor2]))
            case NKCommon.TypeIconFile.url.rawValue: image = UIImage(systemName: "network", withConfiguration: UIImage.SymbolConfiguration(weight: .thin))?.applyingSymbolConfiguration(UIImage.SymbolConfiguration(paletteColors: [NCBrandColor.shared.iconImageColor2]))
            case NKCommon.TypeIconFile.xls.rawValue: image = UIImage(systemName: "tablecells", withConfiguration: UIImage.SymbolConfiguration(weight: .thin))?.applyingSymbolConfiguration(UIImage.SymbolConfiguration(paletteColors: [NCBrandColor.shared.spreadsheetIconColor]))
            default: image = UIImage(systemName: "doc", withConfiguration: UIImage.SymbolConfiguration(weight: .thin))?.applyingSymbolConfiguration(UIImage.SymbolConfiguration(paletteColors: [NCBrandColor.shared.iconImageColor2]))
            }
        }

        if let image { return image }

        // SF IMAGE
        if let colors {
            image = UIImage(systemName: imageName, withConfiguration: UIImage.SymbolConfiguration(weight: .light))?.applyingSymbolConfiguration(UIImage.SymbolConfiguration(paletteColors: colors))
        } else {
            image = UIImage(systemName: imageName, withConfiguration: UIImage.SymbolConfiguration(weight: .light))
        }

        if let image { return image }

        // IMAGES
        if let color = colors?.first, let size {
            image = UIImage(named: imageName)?.image(color: color, size: size)
        } else if let color = colors?.first, size == nil {
            image = UIImage(named: imageName)?.image(color: color, size: 50)
        } else if colors == nil, size == nil {
            image = UIImage(named: imageName)?.resizeImage(size: CGSize(width: 50, height: 50))
        } else if colors == nil, let size {
            image = UIImage(named: imageName)?.resizeImage(size: CGSize(width: size, height: size))
        }
        if let image { return image }

        // NO IMAGES FOUND
        if let color = colors?.first, let size {
            return UIImage(systemName: "doc")!.image(color: color, size: size)
        } else {
            return UIImage(systemName: "doc")!
        }
    }

    func loadUserImage(for user: String, displayName: String?, urlBase: String) -> UIImage {
        let fileName = NCSession.shared.getFileName(urlBase: urlBase, user: user)
        let localFilePath = utilityFileSystem.directoryUserData + "/" + fileName

        if var localImage = UIImage(contentsOfFile: localFilePath) {
            let rect = CGRect(x: 0, y: 0, width: 30, height: 30)
            UIGraphicsBeginImageContextWithOptions(rect.size, false, 3.0)
            UIBezierPath(roundedRect: rect, cornerRadius: rect.size.height).addClip()
            localImage.draw(in: rect)
            localImage = UIGraphicsGetImageFromCurrentImageContext() ?? localImage
            UIGraphicsEndImageContext()
            return localImage
        } else if let image = NCManageDatabase.shared.getImageAvatarLoaded(fileName: fileName).image {
            return image
        } else if let displayName = displayName, !displayName.isEmpty, let avatarImg = createAvatar(displayName: displayName, size: 30) {
            return avatarImg
        } else {
            return loadImage(named: "person.crop.circle", colors: [NCBrandColor.shared.iconImageColor])
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

    func createImageFileFrom(metadata: tableMetadata) {
        if metadata.classFile != NKCommon.TypeClassFile.image.rawValue, metadata.classFile != NKCommon.TypeClassFile.video.rawValue { return }
        var image: UIImage?
        let fileNamePath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)

        if image == nil {
            if metadata.classFile == NKCommon.TypeClassFile.image.rawValue {
                image = UIImage(contentsOfFile: fileNamePath)
            } else if metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
                let videoPath = NSTemporaryDirectory() + "tempvideo.mp4"
                utilityFileSystem.linkItem(atPath: fileNamePath, toPath: videoPath)
                image = imageFromVideo(url: URL(fileURLWithPath: videoPath), at: 0)
            }
        }

        guard let image else { return }

        createImageStandard(ocId: metadata.ocId, etag: metadata.etag, image: image)
    }

    func createImageFileFrom(data: Data, metadata: tableMetadata) {
        createImageFileFrom( data: data, ocId: metadata.ocId, etag: metadata.etag)
    }

    func createImageFileFrom(data: Data, ocId: String, etag: String) {
        guard let image = UIImage(data: data) else { return }
        let fileNamePath1024 = self.utilityFileSystem.getDirectoryProviderStorageImageOcId(ocId, etag: etag, ext: global.previewExt1024)

        do {
            try data.write(to: URL(fileURLWithPath: fileNamePath1024), options: .atomic)
        } catch { }

        createImageStandard(ocId: ocId, etag: etag, image: image)
    }

    private func createImageStandard(ocId: String, etag: String, image: UIImage) {
        let ext = [global.previewExt1024, global.previewExt512, global.previewExt256]
        let size = [global.size1024, global.size512, global.size256]
        let compressionQuality = [0.5, 0.6, 0.7]

        for i in 0..<ext.count {
            if !utilityFileSystem.fileProviderStorageImageExists(ocId, etag: etag, ext: ext[i]),
               let image = image.resizeImage(size: size[i]),
               let data = image.jpegData(compressionQuality: compressionQuality[i]) {
                do {
                    let fileNamePath = utilityFileSystem.getDirectoryProviderStorageImageOcId(ocId, etag: etag, ext: ext[i])
                    try data.write(to: URL(fileURLWithPath: fileNamePath))
                } catch { }
            }
        }
    }

    func getImage(ocId: String, etag: String, ext: String) -> UIImage? {
        return UIImage(contentsOfFile: self.utilityFileSystem.getDirectoryProviderStorageImageOcId(ocId, etag: etag, ext: ext))
    }

    func existsImage(ocId: String, etag: String, ext: String) -> Bool {
        return FileManager().fileExists(atPath: self.utilityFileSystem.getDirectoryProviderStorageImageOcId(ocId, etag: etag, ext: ext))
    }

    func imageFromVideo(url: URL, at time: TimeInterval, completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global(qos: .userInteractive).async {
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

    func pdfThumbnail(url: URL, width: CGFloat = 240) -> UIImage? {
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
        func usernameToColor(_ username: String) -> CGColor {
            // Normalize hash
            let lowerUsername = username.lowercased()
            var hash: String
            // swiftlint:disable force_try
            let regex = try! NSRegularExpression(pattern: "^([0-9a-f]{4}-?){8}$")
            // swiftlint:enable force_try
            let matches = regex.matches(
                in: username,
                range: NSRange(username.startIndex..., in: username))

            if !matches.isEmpty {
                // Already a md5 hash?
                // done, use as is.
                hash = lowerUsername
            } else {
                hash = lowerUsername.md5()
            }

            hash = hash.replacingOccurrences(of: "[^0-9a-f]", with: "", options: .regularExpression)

            // userColors has 18 colors by default
            let result = hash.compactMap(\.hexDigitValue)
            let userColorIx = result.reduce(0, { $0 + $1 }) % 18

            return NCBrandColor.shared.userColors[userColorIx]
        }

        guard let initials = displayName.uppercaseInitials else {
            return nil
        }
        let userColor = usernameToColor(displayName)
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
            NextcloudKit.shared.downloadContent(serverUrl: iconURL.absoluteString, account: account) { _, responseData, error in
                if error == .success, let data = responseData?.data {
                    if let image = UIImage(data: data) {
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

    func getUserStatus(userIcon: String?, userStatus: String?, userMessage: String?) -> (statusImage: UIImage?, statusMessage: String, descriptionMessage: String) {
        var statusImage: UIImage?
        var statusMessage: String = ""
        var descriptionMessage: String = ""
        var messageUserDefined: String = ""

        if userStatus?.lowercased() == "online" {
            statusImage = loadImage(named: "circle_fill", colors: [UIColor(red: 103.0 / 255.0, green: 176.0 / 255.0, blue: 134.0 / 255.0, alpha: 1.0)])
            messageUserDefined = NSLocalizedString("_online_", comment: "")
        }
        if userStatus?.lowercased() == "away" {
            statusImage = loadImage(named: "userStatusAway", colors: [UIColor(red: 233.0 / 255.0, green: 166.0 / 255.0, blue: 75.0 / 255.0, alpha: 1.0)])
            messageUserDefined = NSLocalizedString("_away_", comment: "")
        }
        if userStatus?.lowercased() == "dnd" {
            statusImage = loadImage(named: "userStatusDnd")
            messageUserDefined = NSLocalizedString("_dnd_", comment: "")
            descriptionMessage = NSLocalizedString("_dnd_description_", comment: "")
        }
        if userStatus?.lowercased() == "offline" || userStatus?.lowercased() == "invisible" {
            statusImage = UIImage(named: "userStatusOffline")!.withTintColor(.init(named: "SystemBackgroundInverted")!)
            messageUserDefined = NSLocalizedString("_invisible_", comment: "")
            descriptionMessage = NSLocalizedString("_invisible_description_", comment: "")
        }

        if let userIcon = userIcon {
            statusMessage = userIcon + " "
        }
        if let userMessage = userMessage {
            statusMessage += userMessage
        }
        statusMessage = statusMessage.trimmingCharacters(in: .whitespaces)
        if statusMessage.isEmpty {
            statusMessage = messageUserDefined
        }

        return(statusImage, statusMessage, descriptionMessage)
    }

    func memorySizeOfImage(_ image: UIImage) -> Int {
        guard let imageData = image.pngData() else { return 0 }
        return imageData.count
    }
}
