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

class NCUtility: NSObject {
    @objc static let shared: NCUtility = {
        let instance = NCUtility()
        return instance
    }()
    
    let activityIndicator = UIActivityIndicatorView(style: .whiteLarge)
    
    @objc func getWebDAV(account: String) -> String {
        return NCManageDatabase.sharedInstance.getCapabilitiesServerString(account: account, elements: NCElementsJSON.shared.capabilitiesWebDavRoot) ?? "remote.php/webdav"
    }
    
    @objc func getDAV() -> String {
        return "remote.php/dav"
    }
    
    @objc func getHomeServer(urlBase: String, account: String) -> String {
        return urlBase + "/" + self.getWebDAV(account: account)
    }
    
    @objc func createFileName(_ fileName: String, serverUrl: String, account: String) -> String {
        
        var resultFileName = fileName
        var exitLoop = false
            
            while exitLoop == false {
                
                if NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "fileNameView == %@ AND serverUrl == %@ AND account == %@", resultFileName, serverUrl, account)) != nil {
                    
                    var name = NSString(string: resultFileName).deletingPathExtension
                    let ext = NSString(string: resultFileName).pathExtension
                    let characters = Array(name)
                    
                    if characters.count < 2 {
                        if ext == "" {
                            resultFileName = name + " " + "1"
                        } else {
                            resultFileName = name + " " + "1" + "." + ext
                        }
                    } else {
                        let space = characters[characters.count-2]
                        let numChar = characters[characters.count-1]
                        var num = Int(String(numChar))
                        if (space == " " && num != nil) {
                            name = String(name.dropLast())
                            num = num! + 1
                            if ext == "" {
                                resultFileName = name + "\(num!)"
                            } else {
                                resultFileName = name + "\(num!)" + "." + ext
                            }
                        } else {
                            if ext == "" {
                                resultFileName = name + " " + "1"
                            } else {
                                resultFileName = name + " " + "1" + "." + ext
                            }
                        }
                    }
                    
                } else {
                    exitLoop = true
                }
        }
        
        return resultFileName
    }
    
    @objc func isEncryptedMetadata(_ metadata: tableMetadata) -> Bool {
        
        if metadata.fileName != metadata.fileNameView && metadata.fileName.count == 32 && metadata.fileName.contains(".") == false {
            return true
        }
        
        return false
    }
    
    @objc func resizeImage(image: UIImage, toHeight: CGFloat) -> UIImage {
        return autoreleasepool { () -> UIImage in
            let toWidth = image.size.width * (toHeight/image.size.height)
            let targetSize = CGSize(width: toWidth, height: toHeight)
            let size = image.size
        
            let widthRatio  = targetSize.width  / size.width
            let heightRatio = targetSize.height / size.height
        
            // Orientation detection
            var newSize: CGSize
            if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
            } else {
            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
            }
        
            // Calculated rect
            let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
            // Resize
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: rect)
        
            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
        
            return newImage!
        }
    }
    
    func cellBlurEffect(with frame: CGRect) -> UIView {
        
        let blurEffect = UIBlurEffect(style: .extraLight)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        
        blurEffectView.frame = frame
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurEffectView.backgroundColor = NCBrandColor.sharedInstance.brandElement.withAlphaComponent(0.2)
        
        return blurEffectView
    }
    
    func setLayoutForView(key: String, layout: String, sort: String, ascending: Bool, groupBy: String, directoryOnTop: Bool, titleButton: String, itemForLine: Int) {
        
        let string =  layout + "|" + sort + "|" + "\(ascending)" + "|" + groupBy + "|" + "\(directoryOnTop)" + "|" + titleButton + "|" + "\(itemForLine)"
        
        UICKeyChainStore.setString(string, forKey: key, service: k_serviceShareKeyChain)
    }
    
    func setLayoutForView(key: String, layout: String) {
        
        var sort: String
        var ascending: Bool
        var groupBy: String
        var directoryOnTop: Bool
        var titleButton: String
        var itemForLine: Int

        (_, sort, ascending, groupBy, directoryOnTop, titleButton, itemForLine) = NCUtility.shared.getLayoutForView(key: k_layout_view_favorite)

        setLayoutForView(key: key, layout: layout, sort: sort, ascending: ascending, groupBy: groupBy, directoryOnTop: directoryOnTop, titleButton: titleButton, itemForLine: itemForLine)
    }
    
    @objc func getLayoutForView(key: String) -> (String) {
        
        var layout: String
        (layout, _, _, _, _, _, _) = NCUtility.shared.getLayoutForView(key: key)
        return layout
    }
    
    @objc func getSortedForView(key: String) -> (String) {
        
        var sort: String
        (_, sort, _, _, _, _, _) = NCUtility.shared.getLayoutForView(key: key)
        return sort
    }
    
    @objc func getAscendingForView(key: String) -> (Bool) {
        
        var ascending: Bool
        (_, _, ascending, _, _, _, _) = NCUtility.shared.getLayoutForView(key: key)
        return ascending
    }
    
    @objc func getGroupByForView(key: String) -> (String) {
        
        var groupBy: String
        (_, _, _, groupBy, _, _, _) = NCUtility.shared.getLayoutForView(key: key)
        return groupBy
    }
    
    @objc func getDirectoryOnTopForView(key: String) -> (Bool) {
        
        var directoryOnTop: Bool
        (_, _, _, _, directoryOnTop, _, _) = NCUtility.shared.getLayoutForView(key: key)
        return directoryOnTop
    }
    
    @objc func getTitleButtonForView(key: String) -> (String) {
        
        var titleButton: String
        (_, _, _, _, _, titleButton, _) = NCUtility.shared.getLayoutForView(key: key)
        return titleButton
    }
    
    func getLayoutForView(key: String) -> (layout: String, sort: String, ascending: Bool, groupBy: String, directoryOnTop: Bool, titleButton: String, itemForLine: Int) {
        
        guard let string = UICKeyChainStore.string(forKey: key, service: k_serviceShareKeyChain) else {
            setLayoutForView(key: key, layout: k_layout_list, sort: "fileName", ascending: true, groupBy: "none", directoryOnTop: true, titleButton: "_sorted_by_name_a_z_", itemForLine: 3)
            return (k_layout_list, "fileName", true, "none", true, "_sorted_by_name_a_z_", 3)
        }

        let array = string.components(separatedBy: "|")
        if array.count == 7 {
            let sort = NSString(string: array[2])
            let directoryOnTop = NSString(string: array[4])
            let itemForLine = NSString(string: array[6])

            return (array[0], array[1], sort.boolValue, array[3], directoryOnTop.boolValue, array[5], Int(itemForLine.intValue))
        }
        
        setLayoutForView(key: key, layout: k_layout_list, sort: "fileName", ascending: true, groupBy: "none", directoryOnTop: true, titleButton: "_sorted_by_name_a_z_", itemForLine: 3)
        return (k_layout_list, "fileName", true, "none", true, "_sorted_by_name_a_z_", 3)
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
                        
                        CCUtility.write(pngImageData, fileNamePath: imageNamePath)
                        
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
                            
                        CCUtility.write(pngImageData, fileNamePath: imageNamePath)
                            
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
        
        activityIndicator.color = NCBrandColor.sharedInstance.brandElement
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

    @objc func formatSecondsToString(_ seconds: TimeInterval) -> String {
        if seconds.isNaN {
            return "00:00:00"
        }
        let sec = Int(seconds.truncatingRemainder(dividingBy: 60))
        let min = Int(seconds.truncatingRemainder(dividingBy: 3600) / 60)
        let hour = Int(seconds / 3600)
        return String(format: "%02d:%02d:%02d", hour, min, sec)
    }
    
    @objc func blink(cell: AnyObject?) {
        DispatchQueue.main.async {
            if let cell = cell as? UITableViewCell {
                cell.backgroundColor = NCBrandColor.sharedInstance.brandElement.withAlphaComponent(0.3)
                UIView.animate(withDuration: 2) {
                    cell.backgroundColor = .clear
                }
            } else if let cell = cell as? UICollectionViewCell {
                cell.backgroundColor = NCBrandColor.sharedInstance.brandElement.withAlphaComponent(0.3)
                UIView.animate(withDuration: 2) {
                    cell.backgroundColor = .clear
                }
            }
        }
    }
        
    @objc func isRichDocument(_ metadata: tableMetadata) -> Bool {
        
        guard let mimeType = CCUtility.getMimeType(metadata.fileNameView) else {
            return false
        }
        
        guard let richdocumentsMimetypes = NCManageDatabase.sharedInstance.getCapabilitiesServerArray(account: metadata.account, elements: NCElementsJSON.shared.capabilitiesRichdocumentsMimetypes) else {
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
        
        guard let results = NCManageDatabase.sharedInstance.getDirectEditingEditors(account: account) else {
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
            editor = k_editor_text
        }
        
        return editor
    }
    
    @objc func removeAllSettings() {
        
        URLCache.shared.memoryCapacity = 0
        URLCache.shared.diskCapacity = 0
        KTVHTTPCache.cacheDeleteAllCaches()
        
        NCManageDatabase.sharedInstance.clearDatabase(account: nil, removeAccount: true)
        
        CCUtility.removeGroupDirectoryProviderStorage()
        CCUtility.removeGroupLibraryDirectory()
        
        CCUtility.removeDocumentsDirectory()
        CCUtility.removeTemporaryDirectory()
        
        CCUtility.createDirectoryStandard()
        
        CCUtility.deleteAllChainStore()
    }
    
    #if !EXTENSION
    @objc func createAvatar(fileNameSource: String, fileNameSourceAvatar: String) -> UIImage? {
        
        guard let imageSource = UIImage(contentsOfFile: fileNameSource) else { return nil }
        let size = Int(k_avatar_size)
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: size, height: size), false, UIScreen.main.scale)
        imageSource.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        UIGraphicsBeginImageContextWithOptions(CGSize(width: size, height: size), false, UIScreen.main.scale)
        let avatarImageView = CCAvatar.init(image: image, borderColor: .lightGray, borderWidth: Float(1 * UIScreen.main.scale))
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        avatarImageView?.layer.render(in: context)
        guard let imageAvatar = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
        UIGraphicsEndImageContext()
        
        guard let data = imageAvatar.pngData() else {
            return nil
        }
        do {
            try data.write(to: NSURL(fileURLWithPath: fileNameSourceAvatar) as URL, options: .atomic)
        } catch { }
        
        return imageAvatar
    }
    #endif
    
    @objc func UIColorFromRGB(rgbValue: UInt32) -> UIColor {
        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
    
    @objc func RGBFromUIColor(uicolorValue: UIColor) -> UInt32 {
        
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0

        if uicolorValue.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {

            var colorAsUInt : UInt32 = 0

            colorAsUInt += UInt32(red * 255.0) << 16 +
                           UInt32(green * 255.0) << 8 +
                           UInt32(blue * 255.0)

            return colorAsUInt
        }
        
        return 0
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
        return NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView == %@", account, serverUrl, fileNameConflict))
    }
    
    @objc func isQuickLookDisplayable(metadata: tableMetadata) -> Bool {
        return true
    }
    
    @objc func fromColor(color: UIColor) -> UIImage {
        
        let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        
        UIGraphicsBeginImageContext(rect.size)
        let context: CGContext? = UIGraphicsGetCurrentContext()
        context?.setFillColor(color.cgColor)
        context?.fill(rect)
        let image: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image ?? UIImage()
    }
    
    // Delete Asset on Photos album
    @objc func deleteAssetLocalIdentifiers(account: String, sessionSelector: String, completition: @escaping () -> ()) {
        
        if UIApplication.shared.applicationState != .active {
            completition()
            return
        }
        let metadatasSessionUpload = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND session CONTAINS[cd] %@", account, "upload"))
        if metadatasSessionUpload.count > 0 {
            completition()
            return
        }
        let localIdentifiers = NCManageDatabase.sharedInstance.getAssetLocalIdentifiersUploaded(account: account, sessionSelector: sessionSelector)
        if localIdentifiers.count == 0 {
            completition()
            return
        }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }, completionHandler: { success, error in
            DispatchQueue.main.async {
                NCManageDatabase.sharedInstance.clearAssetLocalIdentifiers(localIdentifiers, account: account)
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
}

