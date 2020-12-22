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

import Foundation
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
    
    let activityIndicator = UIActivityIndicatorView(style: .whiteLarge)
    
    func setLayoutForView(key: String, serverUrl: String, layout: String, sort: String, ascending: Bool, groupBy: String, directoryOnTop: Bool, titleButton: String, itemForLine: Int) {
        
        let string =  layout + "|" + sort + "|" + "\(ascending)" + "|" + groupBy + "|" + "\(directoryOnTop)" + "|" + titleButton + "|" + "\(itemForLine)"
        var keyStore = key
        
        if serverUrl != "" {
            keyStore = serverUrl
        }
        
        UICKeyChainStore.setString(string, forKey: keyStore, service: NCBrandGlobal.shared.serviceShareKeyChain)
    }
    
    func setLayoutForView(key: String, serverUrl: String, layout: String) {
        
        var sort: String
        var ascending: Bool
        var groupBy: String
        var directoryOnTop: Bool
        var titleButton: String
        var itemForLine: Int

        (_, sort, ascending, groupBy, directoryOnTop, titleButton, itemForLine) = NCUtility.shared.getLayoutForView(key: NCBrandGlobal.shared.layoutViewFavorite, serverUrl: serverUrl)

        setLayoutForView(key: key, serverUrl: serverUrl, layout: layout, sort: sort, ascending: ascending, groupBy: groupBy, directoryOnTop: directoryOnTop, titleButton: titleButton, itemForLine: itemForLine)
    }
    
    @objc func getLayoutForView(key: String, serverUrl: String) -> (String) {
        
        var layout: String
        (layout, _, _, _, _, _, _) = NCUtility.shared.getLayoutForView(key: key, serverUrl: serverUrl)
        return layout
    }
    
    @objc func getSortedForView(key: String, serverUrl: String) -> (String) {
        
        var sort: String
        (_, sort, _, _, _, _, _) = NCUtility.shared.getLayoutForView(key: key, serverUrl: serverUrl)
        return sort
    }
    
    @objc func getAscendingForView(key: String, serverUrl: String) -> (Bool) {
        
        var ascending: Bool
        (_, _, ascending, _, _, _, _) = NCUtility.shared.getLayoutForView(key: key, serverUrl: serverUrl)
        return ascending
    }
    
    func getLayoutForView(key: String, serverUrl: String) -> (layout: String, sort: String, ascending: Bool, groupBy: String, directoryOnTop: Bool, titleButton: String, itemForLine: Int) {
        
        var keyStore = key
        
        if serverUrl != "" {
            keyStore = serverUrl
        }
        
        guard let string = UICKeyChainStore.string(forKey: keyStore, service: NCBrandGlobal.shared.serviceShareKeyChain) else {
            setLayoutForView(key: key, serverUrl: serverUrl, layout: NCBrandGlobal.shared.layoutList, sort: "fileName", ascending: true, groupBy: "none", directoryOnTop: true, titleButton: "_sorted_by_name_a_z_", itemForLine: 3)
            return (NCBrandGlobal.shared.layoutList, "fileName", true, "none", true, "_sorted_by_name_a_z_", 3)
        }

        let array = string.components(separatedBy: "|")
        if array.count == 7 {
            let sort = NSString(string: array[2])
            let directoryOnTop = NSString(string: array[4])
            let itemForLine = NSString(string: array[6])

            return (array[0], array[1], sort.boolValue, array[3], directoryOnTop.boolValue, array[5], Int(itemForLine.intValue))
        }
        
        setLayoutForView(key: key, serverUrl: serverUrl, layout: NCBrandGlobal.shared.layoutList, sort: "fileName", ascending: true, groupBy: "none", directoryOnTop: true, titleButton: "_sorted_by_name_a_z_", itemForLine: 3)
        
        return (NCBrandGlobal.shared.layoutList, "fileName", true, "none", true, "_sorted_by_name_a_z_", 3)
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
    
    @objc func startActivityIndicator(view: UIView?, bottom: CGFloat = 0) {
    
        guard let view = view else { return }
        
        activityIndicator.color = .gray
        activityIndicator.hidesWhenStopped = true
            
        view.addSubview(activityIndicator)
            
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
            
        let horizontalConstraint = NSLayoutConstraint(item: activityIndicator, attribute: NSLayoutConstraint.Attribute.centerX, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.centerX, multiplier: 1, constant: 0)
        view.addConstraint(horizontalConstraint)
        
        var verticalConstant: CGFloat = 0
        if bottom > 0 {
            verticalConstant = (view.frame.size.height / 2) - bottom
        }
        
        let verticalConstraint = NSLayoutConstraint(item: activityIndicator, attribute: NSLayoutConstraint.Attribute.centerY, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.centerY, multiplier: 1, constant: verticalConstant)
        view.addConstraint(verticalConstraint)

        activityIndicator.startAnimating()
    }
    
    @objc func stopActivityIndicator() {
        activityIndicator.stopAnimating()
        activityIndicator.removeFromSuperview()
    }
    
    @objc func isSimulatorOrTestFlight() -> Bool {
        guard let path = Bundle.main.appStoreReceiptURL?.path else {
            return false
        }
        return path.contains("CoreSimulator") || path.contains("sandboxReceipt")
    }

    @objc func isRichDocument(_ metadata: tableMetadata) -> Bool {
        
        guard let mimeType = CCUtility.getMimeType(metadata.fileNameView) else {
            return false
        }
        
        guard let richdocumentsMimetypes = NCManageDatabase.shared.getCapabilitiesServerArray(account: metadata.account, elements: NCElementsJSON.shared.capabilitiesRichdocumentsMimetypes) else {
            return false
        }
        
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
    
    @objc func isDirectEditing(account: String, contentType: String) -> String? {
        
        var editor: String?
        
        guard let results = NCManageDatabase.shared.getDirectEditingEditors(account: account) else {
            return editor
        }
        
        for result: tableDirectEditingEditors in results {
            for mimetype in result.mimetypes {
                if mimetype == contentType {
                    editor = result.editor
                }
                // HARDCODE
                // https://github.com/nextcloud/text/issues/913
                if mimetype == "text/markdown" && contentType == "text/x-markdown" {
                    editor = result.editor
                }
            }
            for mimetype in result.optionalMimetypes {
                if mimetype == contentType {
                    editor = result.editor
                }
            }
        }
        
        // HARDCODE
        if editor == "" {
            editor = NCBrandGlobal.shared.editorText
        }
        
        return editor
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
    
    @objc func getMetadataConflict(account: String, serverUrl: String, fileName: String) -> tableMetadata? {
        
        // verify exists conflict
        let fileNameExtension = (fileName as NSString).pathExtension.lowercased()
        let fileNameWithoutExtension = (fileName as NSString).deletingPathExtension
        var fileNameConflict = fileName
        
        if fileNameExtension == "heic" && CCUtility.getFormatCompatibility() {
            fileNameConflict = fileNameWithoutExtension + ".jpg"
        }
        return NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView == %@", account, serverUrl, fileNameConflict))
    }
    
    @objc func isQuickLookDisplayable(metadata: tableMetadata) -> Bool {
        return true
    }
        
    // Delete Asset on Photos album
    @objc func deleteAssetLocalIdentifiers(account: String, sessionSelector: String, completition: @escaping () -> ()) {
        
        if UIApplication.shared.applicationState != .active {
            completition()
            return
        }
        let metadatasSessionUpload = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND session CONTAINS[cd] %@", account, "upload"))
        if metadatasSessionUpload.count > 0 {
            completition()
            return
        }
        let localIdentifiers = NCManageDatabase.shared.getAssetLocalIdentifiersUploaded(account: account, sessionSelector: sessionSelector)
        if localIdentifiers.count == 0 {
            completition()
            return
        }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }, completionHandler: { success, error in
            DispatchQueue.main.async {
                NCManageDatabase.shared.clearAssetLocalIdentifiers(localIdentifiers, account: account)
                completition()
            }
        })
    }
    
    @objc func ocIdToFileId(ocId: String?) -> String? {
    
        guard let ocId = ocId else { return nil }
        
        let items = ocId.components(separatedBy: "oc")
        if items.count < 2 { return nil }
        guard let intFileId = Int(items[0]) else { return nil }
        return String(intFileId)
    }
    
    func getUserStatus(userIcon: String?, userStatus: String?, userMessage: String?) -> (onlineStatus: UIImage?, statusMessage: String) {
        
        var onlineStatus: UIImage?
        var statusMessage: String = ""
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
        }
        if userStatus?.lowercased() == "offline" || userStatus?.lowercased() == "invisible"  {
            onlineStatus = UIImage.init(named: "userStatusOffline")!.image(color: .black, size: 50) 
            messageUserDefined = NSLocalizedString("_invisible_", comment: "")
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
                
        return(onlineStatus, statusMessage)
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
    
    func createImageFrom(fileName: String, ocId: String, etag: String, typeFile: String) {
        
        var originalImage, scaleImagePreview, scaleImageIcon: UIImage?
        
        let fileNamePath = CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileName)!
        let fileNamePathPreview = CCUtility.getDirectoryProviderStoragePreviewOcId(ocId, etag: etag)!
        let fileNamePathIcon = CCUtility.getDirectoryProviderStorageIconOcId(ocId, etag: etag)!
        
        if FileManager().fileExists(atPath: fileNamePathPreview) && FileManager().fileExists(atPath: fileNamePathIcon) { return }
        if !CCUtility.fileProviderStorageExists(ocId, fileNameView: fileName) { return }
        if typeFile != NCBrandGlobal.shared.metadataTypeFileImage && typeFile != NCBrandGlobal.shared.metadataTypeFileVideo { return }
        
        if typeFile == NCBrandGlobal.shared.metadataTypeFileImage {
            
            originalImage = UIImage.init(contentsOfFile: fileNamePath)
            
            scaleImagePreview = originalImage?.resizeImage(size: CGSize(width: NCBrandGlobal.shared.sizePreview, height: NCBrandGlobal.shared.sizePreview), isAspectRation: false)
            scaleImageIcon = originalImage?.resizeImage(size: CGSize(width: NCBrandGlobal.shared.sizeIcon, height: NCBrandGlobal.shared.sizeIcon), isAspectRation: false)
            
            try? scaleImagePreview?.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: fileNamePathPreview))
            try? scaleImageIcon?.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: fileNamePathIcon))
            
        } else if typeFile == NCBrandGlobal.shared.metadataTypeFileVideo {
            
            let videoPath = NSTemporaryDirectory()+"tempvideo.mp4"
            NCUtilityFileSystem.shared.linkItem(atPath: fileNamePath, toPath: videoPath)
            
            originalImage = imageFromVideo(url: URL(fileURLWithPath: videoPath), at: 0)
            
            try? originalImage?.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: fileNamePathPreview))
            try? originalImage?.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: fileNamePathIcon))
        }
    }
}

