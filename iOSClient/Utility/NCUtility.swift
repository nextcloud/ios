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
                //layoutForView.lightColorBackground = array[9] WAS STRING
                //layoutForView.darkColorBackground = array[10] WAS STRING
            }
        }
        
        return layoutForView
    }
        
    func convertSVGtoPNGWriteToUserData(svgUrlString: String, fileName: String?, width: CGFloat?, rewrite: Bool, account: String, closure: @escaping (String?) -> ()) {
        
        var fileNamePNG = ""
        
        guard let svgUrlString = svgUrlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return closure(nil)
        }
        guard let iconURL = URL(string: svgUrlString) else {
            return closure(nil)
        }
        
        if fileName == nil {
            fileNamePNG = iconURL.deletingPathExtension().lastPathComponent + ".png"
        } else {
            fileNamePNG = fileName!
        }
        
        let imageNamePath = CCUtility.getDirectoryUserData() + "/" + fileNamePNG
        
        if !FileManager.default.fileExists(atPath: imageNamePath) || rewrite == true {
            
            NCCommunication.shared.downloadContent(serverUrl: iconURL.absoluteString) { (account, data, errorCode, errorMessage) in
               
                if errorCode == 0 && data != nil {
                
                    if let image = UIImage.init(data: data!) {
                        
                        var newImage: UIImage = image
                        
                        if width != nil {
                            
                            let ratio = image.size.height / image.size.width
                            let newSize = CGSize(width: width!, height: width! * ratio)
                            
                            let renderFormat = UIGraphicsImageRendererFormat.default()
                            renderFormat.opaque = false
                            let renderer = UIGraphicsImageRenderer(size: CGSize(width: newSize.width, height: newSize.height), format: renderFormat)
                            newImage = renderer.image {
                                (context) in
                                image.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
                            }
                        }
                        
                        guard let pngImageData = newImage.pngData() else {
                            return closure(nil)
                        }
                        
                        try? pngImageData.write(to: URL(fileURLWithPath:imageNamePath))
                        
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
                            
                        try? pngImageData.write(to: URL(fileURLWithPath:imageNamePath))
                                                    
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
        //if editor.count == 0 {
        //    editor.append(NCGlobal.shared.editorText)
        //}
                
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
        }else{
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
            onlineStatus = UIImage.init(named: "userStatusOnline")!.image(color: UIColor(red: 103.0/255.0, green: 176.0/255.0, blue: 134.0/255.0, alpha: 1.0), size: 50)
            messageUserDefined = NSLocalizedString("_online_", comment: "")
        }
        if userStatus?.lowercased() == "away" {
            onlineStatus = UIImage.init(named: "userStatusAway")!.image(color: UIColor(red: 233.0/255.0, green: 166.0/255.0, blue: 75.0/255.0, alpha: 1.0), size: 50)
            messageUserDefined = NSLocalizedString("_away_", comment: "")
        }
        if userStatus?.lowercased() == "dnd" {
            onlineStatus = UIImage.init(named: "userStatusDnd")?.resizeImage(size: CGSize(width: 100, height: 100), isAspectRation: false)
            messageUserDefined = NSLocalizedString("_dnd_", comment: "")
            descriptionMessage = NSLocalizedString("_dnd_description_", comment: "")
        }
        if userStatus?.lowercased() == "offline" || userStatus?.lowercased() == "invisible"  {
            onlineStatus = UIImage.init(named: "userStatusOffline")!.image(color: .black, size: 50) 
            messageUserDefined = NSLocalizedString("_invisible_", comment: "")
            descriptionMessage = NSLocalizedString("_invisible_description_", comment: "")
        }
        
        if let userIcon = userIcon {
            statusMessage = userIcon + " "
        }
        if let userMessage = userMessage {
            statusMessage = statusMessage + userMessage
        }
        statusMessage = statusMessage.trimmingCharacters(in: .whitespaces)
        if statusMessage == "" {
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
        if classFile != NCGlobal.shared.metadataClassImage && classFile != NCGlobal.shared.metadataClassVideo { return }
        
        if classFile == NCGlobal.shared.metadataClassImage {
            
            originalImage = UIImage.init(contentsOfFile: fileNamePath)
            
            scaleImagePreview = originalImage?.resizeImage(size: CGSize(width: NCGlobal.shared.sizePreview, height: NCGlobal.shared.sizePreview), isAspectRation: false)
            scaleImageIcon = originalImage?.resizeImage(size: CGSize(width: NCGlobal.shared.sizeIcon, height: NCGlobal.shared.sizeIcon), isAspectRation: false)
            
            try? scaleImagePreview?.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: fileNamePathPreview))
            try? scaleImageIcon?.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: fileNamePathIcon))
            
        } else if classFile == NCGlobal.shared.metadataClassVideo {
            
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
    
    @objc func createAvatar(image: UIImage, size: CGFloat) -> UIImage {
        
        var avatarImage = image
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 3.0)
        UIBezierPath.init(roundedRect: rect, cornerRadius: rect.size.height).addClip()
        avatarImage.draw(in: rect)
        avatarImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        return avatarImage
    }
    
    // MARK: -

    @objc func startActivityIndicator(backgroundView: UIView?, blurEffect: Bool, bottom: CGFloat = 0, style: UIActivityIndicatorView.Style = .whiteLarge) {
        
        if self.activityIndicator != nil {
            stopActivityIndicator()
        }
        
        self.activityIndicator = UIActivityIndicatorView(style: style)
        guard let activityIndicator = self.activityIndicator else { return }
        
        DispatchQueue.main.async {
            
            if self.viewBackgroundActivityIndicator != nil { return }
            
            activityIndicator.color = NCBrandColor.shared.label
            activityIndicator.hidesWhenStopped = true
            activityIndicator.translatesAutoresizingMaskIntoConstraints = false

            let sizeActivityIndicator = activityIndicator.frame.height + 50
            
            self.viewActivityIndicator = UIView.init(frame: CGRect(x: 0, y: 0, width: sizeActivityIndicator, height: sizeActivityIndicator))
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


