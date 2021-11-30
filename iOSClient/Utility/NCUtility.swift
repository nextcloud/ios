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
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import SVGKit
import KTVHTTPCache
import NCCommunication
import PDFKit
import Accelerate
import CoreMedia

// MARK: - NCUtility

class NCUtility: NSObject {
    @objc static let shared: NCUtility = {
        let instance = NCUtility()
        return instance
    }()

    private var activityIndicator: UIActivityIndicatorView?
    private var viewActivityIndicator: UIView?
    private var viewBackgroundActivityIndicator: UIView?

    func setLayoutForView(key: String, serverUrl: String, layoutForView: NCGlobal.layoutForViewType) {

        let string =  layoutForView.layout + "|" + layoutForView.sort + "|" + "\(layoutForView.ascending)" + "|" + layoutForView.groupBy + "|" + "\(layoutForView.directoryOnTop)" + "|" + layoutForView.titleButtonHeader + "|" + "\(layoutForView.itemForLine)" + "|" + layoutForView.imageBackgroud + "|" + layoutForView.imageBackgroudContentMode
        var keyStore = key

        if serverUrl != "" {
            keyStore = serverUrl
        }

        UICKeyChainStore.setString(string, forKey: keyStore, service: NCGlobal.shared.serviceShareKeyChain)
    }

    func setLayoutForView(key: String, serverUrl: String, layout: String?) {

        var layoutForView: NCGlobal.layoutForViewType = NCUtility.shared.getLayoutForView(key: key, serverUrl: serverUrl)

        if let layout = layout {
            layoutForView.layout = layout
            setLayoutForView(key: key, serverUrl: serverUrl, layoutForView: layoutForView)
        }
    }

    func setBackgroundImageForView(key: String, serverUrl: String, imageBackgroud: String, imageBackgroudContentMode: String) {

        var layoutForView: NCGlobal.layoutForViewType = NCUtility.shared.getLayoutForView(key: key, serverUrl: serverUrl)

        layoutForView.imageBackgroud = imageBackgroud
        layoutForView.imageBackgroudContentMode = imageBackgroudContentMode

        setLayoutForView(key: key, serverUrl: serverUrl, layoutForView: layoutForView)
    }

    func getLayoutForView(key: String, serverUrl: String, sort: String = "fileName", ascending: Bool = true, titleButtonHeader: String = "_sorted_by_name_a_z_") -> (NCGlobal.layoutForViewType) {

        var keyStore = key
        var layoutForView: NCGlobal.layoutForViewType = NCGlobal.layoutForViewType(layout: NCGlobal.shared.layoutList, sort: sort, ascending: ascending, groupBy: "none", directoryOnTop: true, titleButtonHeader: titleButtonHeader, itemForLine: 3, imageBackgroud: "", imageBackgroudContentMode: "")

        if serverUrl != "" {
            keyStore = serverUrl
        }

        guard let string = UICKeyChainStore.string(forKey: keyStore, service: NCGlobal.shared.serviceShareKeyChain) else {
            setLayoutForView(key: key, serverUrl: serverUrl, layoutForView: layoutForView)
            return layoutForView
        }

        let array = string.components(separatedBy: "|")
        if array.count >= 7 {
            // version 1
            layoutForView.layout = array[0]
            layoutForView.sort = array[1]
            layoutForView.ascending = NSString(string: array[2]).boolValue
            layoutForView.groupBy = array[3]
            layoutForView.directoryOnTop = NSString(string: array[4]).boolValue
            layoutForView.titleButtonHeader = array[5]
            layoutForView.itemForLine = Int(NSString(string: array[6]).intValue)
            // version 2
            if array.count > 8 {
                layoutForView.imageBackgroud = array[7]
                layoutForView.imageBackgroudContentMode = array[8]
                // layoutForView.lightColorBackground = array[9] WAS STRING
                // layoutForView.darkColorBackground = array[10] WAS STRING
            }
        }

        return layoutForView
    }

    func convertSVGtoPNGWriteToUserData(svgUrlString: String, fileName: String?, width: CGFloat?, rewrite: Bool, account: String, closure: @escaping (String?) -> Void) {

        var fileNamePNG = ""

        guard let svgUrlString = svgUrlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let iconURL = URL(string: svgUrlString) else {
            return closure(nil)
        }

        if let fileName = fileName {
            fileNamePNG = fileName
        } else {
            fileNamePNG = iconURL.deletingPathExtension().lastPathComponent + ".png"
        }

        let imageNamePath = CCUtility.getDirectoryUserData() + "/" + fileNamePNG

        if !FileManager.default.fileExists(atPath: imageNamePath) || rewrite == true {

            NCCommunication.shared.downloadContent(serverUrl: iconURL.absoluteString) { _, data, errorCode, _ in

                if errorCode == 0 && data != nil {

                    if let image = UIImage(data: data!) {

                        var newImage: UIImage = image

                        if width != nil {

                            let ratio = image.size.height / image.size.width
                            let newSize = CGSize(width: width!, height: width! * ratio)

                            let renderFormat = UIGraphicsImageRendererFormat.default()
                            renderFormat.opaque = false
                            let renderer = UIGraphicsImageRenderer(size: CGSize(width: newSize.width, height: newSize.height), format: renderFormat)
                            newImage = renderer.image {
                                _ in
                                image.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
                            }
                        }

                        guard let pngImageData = newImage.pngData() else {
                            return closure(nil)
                        }

                        try? pngImageData.write(to: URL(fileURLWithPath: imageNamePath))

                        return closure(imageNamePath)

                    } else {

                        guard let svgImage: SVGKImage = SVGKImage(data: data) else {
                            return closure(nil)
                        }

                        if width != nil {
                            let scale = svgImage.size.height / svgImage.size.width
                            svgImage.size = CGSize(width: width!, height: width! * scale)
                        }

                        guard let image: UIImage = svgImage.uiImage else {
                            return closure(nil)
                        }
                        guard let pngImageData = image.pngData() else {
                            return closure(nil)
                        }

                        try? pngImageData.write(to: URL(fileURLWithPath: imageNamePath))

                        return closure(imageNamePath)
                    }
                } else {
                    return closure(nil)
                }
            }

        } else {
            return closure(imageNamePath)
        }
    }

    @objc func isSimulatorOrTestFlight() -> Bool {
        guard let path = Bundle.main.appStoreReceiptURL?.path else {
            return false
        }
        return path.contains("CoreSimulator") || path.contains("sandboxReceipt")
    }

    @objc func isSimulator() -> Bool {
        guard let path = Bundle.main.appStoreReceiptURL?.path else {
            return false
        }
        return path.contains("CoreSimulator")
    }

    @objc func isRichDocument(_ metadata: tableMetadata) -> Bool {

        guard let mimeType = CCUtility.getMimeType(metadata.fileNameView) else {
            return false
        }

        guard let richdocumentsMimetypes = NCManageDatabase.shared.getCapabilitiesServerArray(account: metadata.account, elements: NCElementsJSON.shared.capabilitiesRichdocumentsMimetypes) else {
            return false
        }

        // contentype
        for richdocumentMimetype: String in richdocumentsMimetypes {
            if richdocumentMimetype.contains(metadata.contentType) || metadata.contentType == "text/plain" {
                return true
            }
        }

        // mimetype
        if richdocumentsMimetypes.count > 0 && mimeType.components(separatedBy: ".").count > 2 {

            let mimeTypeArray = mimeType.components(separatedBy: ".")
            let mimeType = mimeTypeArray[mimeTypeArray.count - 2] + "." + mimeTypeArray[mimeTypeArray.count - 1]

            for richdocumentMimetype: String in richdocumentsMimetypes {
                if richdocumentMimetype.contains(mimeType) {
                    return true
                }
            }
        }

        return false
    }

    @objc func isDirectEditing(account: String, contentType: String) -> [String] {

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

        // HARDCODE
        // if editor.count == 0 {
        //    editor.append(NCGlobal.shared.editorText)
        // }

        return Array(Set(editor))
    }

    @objc func removeAllSettings() {

        URLCache.shared.memoryCapacity = 0
        URLCache.shared.diskCapacity = 0
        KTVHTTPCache.cacheDeleteAllCaches()

        NCManageDatabase.shared.clearDatabase(account: nil, removeAccount: true)

        CCUtility.removeGroupDirectoryProviderStorage()
        CCUtility.removeGroupLibraryDirectory()

        CCUtility.removeDocumentsDirectory()
        CCUtility.removeTemporaryDirectory()

        CCUtility.createDirectoryStandard()

        CCUtility.deleteAllChainStore()
    }

    @objc func permissionsContainsString(_ metadataPermissions: String, permissions: String) -> Bool {

        for char in permissions {
            if metadataPermissions.contains(char) == false {
                return false
            }
        }
        return true
    }

    @objc func getCustomUserAgentOnlyOffice() -> String {

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
            onlineStatus = UIImage(named: "userStatusOnline")!.image(color: UIColor(red: 103.0/255.0, green: 176.0/255.0, blue: 134.0/255.0, alpha: 1.0), size: 50)
            messageUserDefined = NSLocalizedString("_online_", comment: "")
        }
        if userStatus?.lowercased() == "away" {
            onlineStatus = UIImage(named: "userStatusAway")!.image(color: UIColor(red: 233.0/255.0, green: 166.0/255.0, blue: 75.0/255.0, alpha: 1.0), size: 50)
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
        if statusMessage == "" {
            statusMessage = messageUserDefined
        }

        return(onlineStatus, statusMessage, descriptionMessage)
    }

    // MARK: -

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
        DispatchQueue.global(qos: .background).async {

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

    func createImageFrom(fileName: String, ocId: String, etag: String, classFile: String) {

        var originalImage, scaleImagePreview, scaleImageIcon: UIImage?

        let fileNamePath = CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileName)!
        let fileNamePathPreview = CCUtility.getDirectoryProviderStoragePreviewOcId(ocId, etag: etag)!
        let fileNamePathIcon = CCUtility.getDirectoryProviderStorageIconOcId(ocId, etag: etag)!

        if FileManager().fileExists(atPath: fileNamePathPreview) && FileManager().fileExists(atPath: fileNamePathIcon) { return }
        if !CCUtility.fileProviderStorageExists(ocId, fileNameView: fileName) { return }
        if classFile != NCCommunicationCommon.typeClassFile.image.rawValue && classFile != NCCommunicationCommon.typeClassFile.video.rawValue { return }

        if classFile == NCCommunicationCommon.typeClassFile.image.rawValue {

            originalImage = UIImage(contentsOfFile: fileNamePath)

            scaleImagePreview = originalImage?.resizeImage(size: CGSize(width: NCGlobal.shared.sizePreview, height: NCGlobal.shared.sizePreview), isAspectRation: false)
            scaleImageIcon = originalImage?.resizeImage(size: CGSize(width: NCGlobal.shared.sizeIcon, height: NCGlobal.shared.sizeIcon), isAspectRation: false)

            try? scaleImagePreview?.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: fileNamePathPreview))
            try? scaleImageIcon?.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: fileNamePathIcon))

        } else if classFile == NCCommunicationCommon.typeClassFile.video.rawValue {

            let videoPath = NSTemporaryDirectory()+"tempvideo.mp4"
            NCUtilityFileSystem.shared.linkItem(atPath: fileNamePath, toPath: videoPath)

            originalImage = imageFromVideo(url: URL(fileURLWithPath: videoPath), at: 0)

            try? originalImage?.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: fileNamePathPreview))
            try? originalImage?.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: fileNamePathIcon))
        }
    }

    @objc func getVersionApp() -> String {
        if let dictionary = Bundle.main.infoDictionary {
            if let version = dictionary["CFBundleShortVersionString"], let build = dictionary["CFBundleVersion"] {
                return "\(version).\(build)"
            }
        }
        return ""
    }

    func loadImage(named: String, color: UIColor = NCBrandColor.shared.gray, size: CGFloat = 50, symbolConfiguration: Any? = nil) -> UIImage {

        var image: UIImage?

        if #available(iOS 13.0, *) {
            if let symbolConfiguration = symbolConfiguration {
                image = UIImage(systemName: named, withConfiguration: symbolConfiguration as? UIImage.Configuration)?.imageColor(color)
            } else {
                image = UIImage(systemName: named)?.imageColor(color)
            }
            if image == nil {
                image = UIImage(named: named)?.image(color: color, size: size)
            }
        } else {
            image = UIImage(named: named)?.image(color: color, size: size)
        }

        if image != nil {
            return image!
        }

        return  UIImage(named: "file")!.image(color: color, size: size)
    }

    @objc func loadUserImage(for user: String, displayName: String?, userBaseUrl: NCUserBaseUrl) -> UIImage {

        let fileName = userBaseUrl.userBaseUrl + "-" + user + ".png"
        let localFilePath = String(CCUtility.getDirectoryUserData()) + "/" + fileName

        if let localImage = UIImage(contentsOfFile: localFilePath) {
            return createAvatar(image: localImage, size: 30)
        } else if let loadedAvatar = NCManageDatabase.shared.getImageAvatarLoaded(fileName: fileName) {
            return loadedAvatar
        } else if let displayName = displayName, !displayName.isEmpty, let avatarImg = createAvatar(displayName: displayName, size: 30) {
            return avatarImg
        } else { return getDefaultUserIcon() }
    }

    func getDefaultUserIcon() -> UIImage {
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: 30)
            return NCUtility.shared.loadImage(named: "person.crop.circle", symbolConfiguration: config)
        } else {
            return NCUtility.shared.loadImage(named: "person.crop.circle", size: 30)
        }
    }

    @objc func createAvatar(image: UIImage, size: CGFloat) -> UIImage {

        var avatarImage = image
        let rect = CGRect(x: 0, y: 0, width: size, height: size)

        UIGraphicsBeginImageContextWithOptions(rect.size, false, 3.0)
        UIBezierPath(roundedRect: rect, cornerRadius: rect.size.height).addClip()
        avatarImage.draw(in: rect)
        avatarImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()

        return avatarImage
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

    // MARK: -

    @objc func startActivityIndicator(backgroundView: UIView?, blurEffect: Bool, bottom: CGFloat = 0, style: UIActivityIndicatorView.Style = .whiteLarge) {

        if self.activityIndicator != nil {
            stopActivityIndicator()
        }

        DispatchQueue.main.async {

            self.activityIndicator = UIActivityIndicatorView(style: style)
            guard let activityIndicator = self.activityIndicator else { return }
            if self.viewBackgroundActivityIndicator != nil { return }

            activityIndicator.color = NCBrandColor.shared.label
            activityIndicator.hidesWhenStopped = true
            activityIndicator.translatesAutoresizingMaskIntoConstraints = false

            let sizeActivityIndicator = activityIndicator.frame.height + 50

            self.viewActivityIndicator = UIView(frame: CGRect(x: 0, y: 0, width: sizeActivityIndicator, height: sizeActivityIndicator))
            self.viewActivityIndicator?.translatesAutoresizingMaskIntoConstraints = false
            self.viewActivityIndicator?.layer.cornerRadius = 10
            self.viewActivityIndicator?.layer.masksToBounds = true
            self.viewActivityIndicator?.backgroundColor = .clear

            #if !EXTENSION
            if backgroundView == nil {
                if let window = UIApplication.shared.keyWindow {
                    self.viewBackgroundActivityIndicator?.removeFromSuperview()
                    self.viewBackgroundActivityIndicator = NCViewActivityIndicator(frame: window.bounds)
                    window.addSubview(self.viewBackgroundActivityIndicator!)
                    self.viewBackgroundActivityIndicator?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    self.viewBackgroundActivityIndicator?.backgroundColor = .clear
                }
            } else {
                self.viewBackgroundActivityIndicator = backgroundView
            }
            #else
            self.viewBackgroundActivityIndicator = backgroundView
            #endif

            // VIEW ACTIVITY INDICATOR

            guard let viewActivityIndicator = self.viewActivityIndicator else { return }
            viewActivityIndicator.addSubview(activityIndicator)

            if blurEffect {
                let blurEffect = UIBlurEffect(style: .regular)
                let blurEffectView = UIVisualEffectView(effect: blurEffect)
                blurEffectView.frame = viewActivityIndicator.frame
                viewActivityIndicator.insertSubview(blurEffectView, at: 0)
            }

            NSLayoutConstraint.activate([
                viewActivityIndicator.widthAnchor.constraint(equalToConstant: sizeActivityIndicator),
                viewActivityIndicator.heightAnchor.constraint(equalToConstant: sizeActivityIndicator),
                activityIndicator.centerXAnchor.constraint(equalTo: viewActivityIndicator.centerXAnchor),
                activityIndicator.centerYAnchor.constraint(equalTo: viewActivityIndicator.centerYAnchor)
            ])

            // BACKGROUD VIEW ACTIVITY INDICATOR

            guard let viewBackgroundActivityIndicator = self.viewBackgroundActivityIndicator else { return }
            viewBackgroundActivityIndicator.addSubview(viewActivityIndicator)

            var verticalConstant: CGFloat = 0
            if bottom > 0 {
                verticalConstant = (viewBackgroundActivityIndicator.frame.size.height / 2) - bottom
            }

            NSLayoutConstraint.activate([
                viewActivityIndicator.centerXAnchor.constraint(equalTo: viewBackgroundActivityIndicator.centerXAnchor),
                viewActivityIndicator.centerYAnchor.constraint(equalTo: viewBackgroundActivityIndicator.centerYAnchor, constant: verticalConstant)
            ])

            activityIndicator.startAnimating()
        }
    }

    @objc func stopActivityIndicator() {

        DispatchQueue.main.async {

            self.activityIndicator?.stopAnimating()
            self.activityIndicator?.removeFromSuperview()
            self.activityIndicator = nil

            self.viewActivityIndicator?.removeFromSuperview()
            self.viewActivityIndicator = nil

            if self.viewBackgroundActivityIndicator is NCViewActivityIndicator {
                self.viewBackgroundActivityIndicator?.removeFromSuperview()
            }
            self.viewBackgroundActivityIndicator = nil
        }
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

    func stringFromTime(_ time: CMTime) -> String {

        let interval = Int(CMTimeGetSeconds(time))

        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    func colorNavigationController(_ navigationController: UINavigationController?, backgroundColor: UIColor, titleColor: UIColor, tintColor: UIColor?, withoutShadow: Bool) {

        if #available(iOS 13.0, *) {

            // iOS 14, 15
            let appearance = UINavigationBarAppearance()
            appearance.titleTextAttributes = [.foregroundColor: titleColor]
            appearance.largeTitleTextAttributes = [.foregroundColor: titleColor]

            if withoutShadow {
                appearance.shadowColor = .clear
                appearance.shadowImage = UIImage()
            }

            if let tintColor = tintColor {
                navigationController?.navigationBar.tintColor = tintColor
            }

            navigationController?.view.backgroundColor = backgroundColor
            navigationController?.navigationBar.barTintColor = titleColor
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.compactAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance

        } else {

            navigationController?.navigationBar.isTranslucent = true
            navigationController?.navigationBar.barTintColor = backgroundColor

            if withoutShadow {
                navigationController?.navigationBar.shadowImage = UIImage()
                navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
            }

            let titleDict: NSDictionary = [NSAttributedString.Key.foregroundColor: titleColor]
            navigationController?.navigationBar.titleTextAttributes = titleDict as? [NSAttributedString.Key: Any]
            if let tintColor = tintColor {
                navigationController?.navigationBar.tintColor = tintColor
            }
        }
    }
}

// MARK: -

class NCViewActivityIndicator: UIView {

    // MARK: - View Life Cycle

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
