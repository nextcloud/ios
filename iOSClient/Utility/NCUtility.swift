//
//  NCUtility.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 25/06/18.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY without even the implied warranty of
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
import Alamofire

#if !EXTENSION
import SVGKit
#endif

class NCUtility: NSObject {

    let utilityFileSystem = NCUtilityFileSystem()

#if !EXTENSION
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
#endif

    @objc func isSimulatorOrTestFlight() -> Bool {
        guard let path = Bundle.main.appStoreReceiptURL?.path else {
            return false
        }
        return path.contains("CoreSimulator") || path.contains("sandboxReceipt")
    }

    func isSimulator() -> Bool {
        guard let path = Bundle.main.appStoreReceiptURL?.path else {
            return false
        }
        return path.contains("CoreSimulator")
    }

    func isRichDocument(_ metadata: tableMetadata) -> Bool {

        guard let mimeType = CCUtility.getMimeType(metadata.fileNameView) else {
            return false
        }

        // contentype
        for richdocumentMimetype: String in NCGlobal.shared.capabilityRichdocumentsMimetypes {
            if richdocumentMimetype.contains(metadata.contentType) || metadata.contentType == "text/plain" {
                return true
            }
        }

        // mimetype
        if !NCGlobal.shared.capabilityRichdocumentsMimetypes.isEmpty && mimeType.components(separatedBy: ".").count > 2 {

            let mimeTypeArray = mimeType.components(separatedBy: ".")
            let mimeType = mimeTypeArray[mimeTypeArray.count - 2] + "." + mimeTypeArray[mimeTypeArray.count - 1]

            for richdocumentMimetype: String in NCGlobal.shared.capabilityRichdocumentsMimetypes {
                if richdocumentMimetype.contains(mimeType) {
                    return true
                }
            }
        }

        return false
    }

    func isDirectEditing(account: String, contentType: String) -> [String] {

        var editor: [String] = []

        guard let results = NCManageDatabase.shared.getDirectEditingEditors(account: account) else {
            return editor
        }

        for result: tableDirectEditingEditors in results {
            for mimetype in result.mimetypes {
                if mimetype == contentType {
                    editor.append(result.editor)
                }

                // HARDCODE
                // https://github.com/nextcloud/text/issues/913

                if mimetype == "text/markdown" && contentType == "text/x-markdown" {
                    editor.append(result.editor)
                }
                if contentType == "text/html" {
                    editor.append(result.editor)
                }
            }
            for mimetype in result.optionalMimetypes {
                if mimetype == contentType {
                    editor.append(result.editor)
                }
            }
        }

        return Array(Set(editor))
    }

#if !EXTENSION
    @objc func removeAllSettings() {

        URLCache.shared.memoryCapacity = 0
        URLCache.shared.diskCapacity = 0

        NCManageDatabase.shared.clearDatabase(account: nil, removeAccount: true)

        utilityFileSystem.removeGroupDirectoryProviderStorage()
        utilityFileSystem.removeGroupLibraryDirectory()

        utilityFileSystem.removeDocumentsDirectory()
        utilityFileSystem.removeTemporaryDirectory()

        utilityFileSystem.createDirectoryStandard()

        NCKeychain().removeAll()
    }
#endif

    func permissionsContainsString(_ metadataPermissions: String, permissions: String) -> Bool {

        for char in permissions {
            if metadataPermissions.contains(char) == false {
                return false
            }
        }
        return true
    }

    func getCustomUserAgentNCText() -> String {
        if UIDevice.current.userInterfaceIdiom == .phone {
            // NOTE: Hardcoded (May 2022)
            // Tested for iPhone SE (1st), iOS 12 iPhone Pro Max, iOS 15.4
            // 605.1.15 = WebKit build version
            // 15E148 = frozen iOS build number according to: https://chromestatus.com/feature/4558585463832576
            return userAgent + " " + "AppleWebKit/605.1.15 Mobile/15E148"
        } else {
            return userAgent
        }
    }

    func getCustomUserAgentOnlyOffice() -> String {

        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")!
        if UIDevice.current.userInterfaceIdiom == .pad {
            return "Mozilla/5.0 (iPad) Nextcloud-iOS/\(appVersion)"
        } else {
            return "Mozilla/5.0 (iPhone) Mobile Nextcloud-iOS/\(appVersion)"
        }
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

    @objc func isQuickLookDisplayable(metadata: tableMetadata) -> Bool {
        return true
    }

    @objc func ocIdToFileId(ocId: String?) -> String? {

        guard let ocId = ocId else { return nil }

        let items = ocId.components(separatedBy: "oc")
        if items.count < 2 { return nil }
        guard let intFileId = Int(items[0]) else { return nil }
        return String(intFileId)
    }

    func getUserStatus(userIcon: String?, userStatus: String?, userMessage: String?) -> (onlineStatus: UIImage?, statusMessage: String, descriptionMessage: String) {

        var onlineStatus: UIImage?
        var statusMessage: String = ""
        var descriptionMessage: String = ""
        var messageUserDefined: String = ""

        if userStatus?.lowercased() == "online" {
            onlineStatus = UIImage(named: "circle_fill")!.image(color: UIColor(red: 103.0 / 255.0, green: 176.0 / 255.0, blue: 134.0 / 255.0, alpha: 1.0), size: 50)
            messageUserDefined = NSLocalizedString("_online_", comment: "")
        }
        if userStatus?.lowercased() == "away" {
            onlineStatus = UIImage(named: "userStatusAway")!.image(color: UIColor(red: 233.0 / 255.0, green: 166.0 / 255.0, blue: 75.0 / 255.0, alpha: 1.0), size: 50)
            messageUserDefined = NSLocalizedString("_away_", comment: "")
        }
        if userStatus?.lowercased() == "dnd" {
            onlineStatus = UIImage(named: "userStatusDnd")?.resizeImage(size: CGSize(width: 100, height: 100), isAspectRation: false)
            messageUserDefined = NSLocalizedString("_dnd_", comment: "")
            descriptionMessage = NSLocalizedString("_dnd_description_", comment: "")
        }
        if userStatus?.lowercased() == "offline" || userStatus?.lowercased() == "invisible" {
            onlineStatus = UIImage(named: "userStatusOffline")!.image(color: .black, size: 50)
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

        return(onlineStatus, statusMessage, descriptionMessage)
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

    @objc func getVersionApp(withBuild: Bool = true) -> String {
        if let dictionary = Bundle.main.infoDictionary {
            if let version = dictionary["CFBundleShortVersionString"], let build = dictionary["CFBundleVersion"] {
                if withBuild {
                    return "\(version).\(build)"
                } else {
                    return "\(version)"
                }
            }
        }
        return ""
    }

    func loadImage(named imageName: String, color: UIColor = UIColor.systemGray, size: CGFloat = 50, symbolConfiguration: Any? = nil, renderingMode: UIImage.RenderingMode = .alwaysOriginal) -> UIImage {

        var image: UIImage?

        // see https://stackoverflow.com/questions/71764255
        let sfSymbolName = imageName.replacingOccurrences(of: "_", with: ".")
        if let symbolConfiguration = symbolConfiguration {
            image = UIImage(systemName: sfSymbolName, withConfiguration: symbolConfiguration as? UIImage.Configuration)?.withTintColor(color, renderingMode: renderingMode)
        } else {
            image = UIImage(systemName: sfSymbolName)?.withTintColor(color, renderingMode: renderingMode)
        }
        if image == nil {
            image = UIImage(named: imageName)?.image(color: color, size: size)
        }
        if let image = image {
            return image
        }

        return  UIImage(named: "file")!.image(color: color, size: size)
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

    /*
     Facebook's comparison algorithm:
     */

    func compare(tolerance: Float, expected: Data, observed: Data) throws -> Bool {

        enum customError: Error {
            case unableToGetUIImageFromData
            case unableToGetCGImageFromData
            case unableToGetColorSpaceFromCGImage
            case imagesHasDifferentSizes
            case unableToInitializeContext
        }

        guard let expectedUIImage = UIImage(data: expected), let observedUIImage = UIImage(data: observed) else {
            throw customError.unableToGetUIImageFromData
        }
        guard let expectedCGImage = expectedUIImage.cgImage, let observedCGImage = observedUIImage.cgImage else {
            throw customError.unableToGetCGImageFromData
        }
        guard let expectedColorSpace = expectedCGImage.colorSpace, let observedColorSpace = observedCGImage.colorSpace else {
            throw customError.unableToGetColorSpaceFromCGImage
        }
        if expectedCGImage.width != observedCGImage.width || expectedCGImage.height != observedCGImage.height {
            throw customError.imagesHasDifferentSizes
        }
        let imageSize = CGSize(width: expectedCGImage.width, height: expectedCGImage.height)
        let numberOfPixels = Int(imageSize.width * imageSize.height)

        // Checking that our `UInt32` buffer has same number of bytes as image has.
        let bytesPerRow = min(expectedCGImage.bytesPerRow, observedCGImage.bytesPerRow)
        assert(MemoryLayout<UInt32>.stride == bytesPerRow / Int(imageSize.width))

        let expectedPixels = UnsafeMutablePointer<UInt32>.allocate(capacity: numberOfPixels)
        let observedPixels = UnsafeMutablePointer<UInt32>.allocate(capacity: numberOfPixels)

        let expectedPixelsRaw = UnsafeMutableRawPointer(expectedPixels)
        let observedPixelsRaw = UnsafeMutableRawPointer(observedPixels)

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let expectedContext = CGContext(data: expectedPixelsRaw, width: Int(imageSize.width), height: Int(imageSize.height),
                                              bitsPerComponent: expectedCGImage.bitsPerComponent, bytesPerRow: bytesPerRow,
                                              space: expectedColorSpace, bitmapInfo: bitmapInfo.rawValue) else {
            expectedPixels.deallocate()
            observedPixels.deallocate()
            throw customError.unableToInitializeContext
        }
        guard let observedContext = CGContext(data: observedPixelsRaw, width: Int(imageSize.width), height: Int(imageSize.height),
                                              bitsPerComponent: observedCGImage.bitsPerComponent, bytesPerRow: bytesPerRow,
                                              space: observedColorSpace, bitmapInfo: bitmapInfo.rawValue) else {
            expectedPixels.deallocate()
            observedPixels.deallocate()
            throw customError.unableToInitializeContext
        }

        expectedContext.draw(expectedCGImage, in: CGRect(origin: .zero, size: imageSize))
        observedContext.draw(observedCGImage, in: CGRect(origin: .zero, size: imageSize))

        let expectedBuffer = UnsafeBufferPointer(start: expectedPixels, count: numberOfPixels)
        let observedBuffer = UnsafeBufferPointer(start: observedPixels, count: numberOfPixels)

        var isEqual = true
        if tolerance == 0 {
            isEqual = expectedBuffer.elementsEqual(observedBuffer)
        } else {
            // Go through each pixel in turn and see if it is different
            var numDiffPixels = 0
            for pixel in 0 ..< numberOfPixels where expectedBuffer[pixel] != observedBuffer[pixel] {
                // If this pixel is different, increment the pixel diff count and see if we have hit our limit.
                numDiffPixels += 1
                let percentage = 100 * Float(numDiffPixels) / Float(numberOfPixels)
                if percentage > tolerance {
                    isEqual = false
                    break
                }
            }
        }

        expectedPixels.deallocate()
        observedPixels.deallocate()

        return isEqual
    }

    func createFilePreviewImage(ocId: String, etag: String, fileNameView: String, classFile: String, status: Int, createPreviewMedia: Bool) -> UIImage? {

        var imagePreview: UIImage?
        let filePath = utilityFileSystem.getDirectoryProviderStorageOcId(ocId, fileNameView: fileNameView)
        let iconImagePath = utilityFileSystem.getDirectoryProviderStorageIconOcId(ocId, etag: etag)

        if FileManager().fileExists(atPath: iconImagePath) {
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

    func getLocation(latitude: Double, longitude: Double, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        let llocation = CLLocation(latitude: latitude, longitude: longitude)

        if let location = NCManageDatabase.shared.getLocationFromLatAndLong(latitude: latitude, longitude: longitude) {
            completion(location)
        } else {
            geocoder.reverseGeocodeLocation(llocation) { placemarks, error in
                if error == nil, let placemark = placemarks?.first {
                    let locationComponents: [String] = [placemark.name, placemark.locality, placemark.country]
                        .compactMap {$0}

                    let location = locationComponents.joined(separator: ", ")

                    NCManageDatabase.shared.addGeocoderLocation(location, latitude: latitude, longitude: longitude)
                    completion(location)
                }
            }
        }
    }

    // https://stackoverflow.com/questions/5887248/ios-app-maximum-memory-budget/19692719#19692719
    // https://stackoverflow.com/questions/27556807/swift-pointer-problems-with-mach-task-basic-info/27559770#27559770

    func getMemoryUsedAndDeviceTotalInMegabytes() -> (Float, Float) {

        var usedmegabytes: Float = 0

        let totalbytes = Float(ProcessInfo.processInfo.physicalMemory)
        let totalmegabytes = totalbytes / 1024.0 / 1024.0

        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        if kerr == KERN_SUCCESS {
            let usedbytes: Float = Float(info.resident_size)
            usedmegabytes = usedbytes / 1024.0 / 1024.0
        }

        return (usedmegabytes, totalmegabytes)
    }

    func removeForbiddenCharacters(_ fileName: String) -> String {

        var fileName = fileName
        let arrayForbiddenCharacters = ["/"]

        for character in arrayForbiddenCharacters {
            fileName = fileName.replacingOccurrences(of: character, with: "")
        }
        return fileName
    }

}
