//
//  NCUtility.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 25/06/18.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
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

class NCUtility: NSObject {

    @objc static let sharedInstance: NCUtility = {
        let instance = NCUtility()
        return instance
    }()
    
    let activityIndicator = UIActivityIndicatorView(style: .whiteLarge)
    
    @objc func createFileName(_ fileName: String, directoryID: String) -> String {
        
        var resultFileName = fileName
        var exitLoop = false
            
            while exitLoop == false {
                
                if NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "fileNameView == %@ AND directoryID == %@", resultFileName, directoryID)) != nil {
                    
                    var name = NSString(string: resultFileName).deletingPathExtension
                    let ext = NSString(string: resultFileName).pathExtension
                    
                    let characters = Array(name)
                    
                    if characters.count < 2 {
                        resultFileName = name + " " + "1" + "." + ext
                    } else {
                        let space = characters[characters.count-2]
                        let numChar = characters[characters.count-1]
                        var num = Int(String(numChar))
                        if (space == " " && num != nil) {
                            name = String(name.dropLast())
                            num = num! + 1
                            resultFileName = name + "\(num!)" + "." + ext
                        } else {
                            resultFileName = name + " " + "1" + "." + ext
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
    
    @objc func getFileSize(asset: PHAsset) -> Int64 {
        
        let resources = PHAssetResource.assetResources(for: asset)
        
        if let resource = resources.first {
            if resource.responds(to: #selector(NSDictionary.fileSize)) {
                let unsignedInt64 = resource.value(forKey: "fileSize") as! CLong
                return Int64(bitPattern: UInt64(unsignedInt64))
            }
        }
        
        return 0
    }
    
    @objc func getScreenWidthForPreview() -> CGFloat {
        
        let screenSize = UIScreen.main.bounds
        let screenWidth = screenSize.width * 0.75
        
        return screenWidth
    }
    
    @objc func getScreenHeightForPreview() -> CGFloat {
        
        let screenSize = UIScreen.main.bounds
        let screenWidth = screenSize.height * 0.75
        
        return screenWidth
    }
    
    @objc func convertFileIDClientToFileIDServer(_ fileID: NSString) -> String {
        
        let split = fileID.components(separatedBy: "oc")
        if split.count == 2 {
            let fileIDServerInt = CLongLong(split[0])
            return String(describing: fileIDServerInt ?? 0)
        }
        
        return fileID as String
    }
    
    func resizeImage(image: UIImage, newWidth: CGFloat) -> UIImage {
        
        let scale = newWidth / image.size.width
        let newHeight = image.size.height * scale
        UIGraphicsBeginImageContext(CGSize(width: newWidth, height: newHeight))
        image.draw(in: (CGRect(x: 0, y: 0, width: newWidth, height: newHeight)))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    func cellBlurEffect(with frame: CGRect) -> UIView {
        
        let blurEffect = UIBlurEffect(style: .extraLight)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        
        blurEffectView.frame = frame
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurEffectView.backgroundColor = NCBrandColor.sharedInstance.brand.withAlphaComponent(0.2)
        
        return blurEffectView
    }
    
    func setLayoutForView(key: String, layout: String, sort: String, ascending: Bool, groupBy: String, directoryOnTop: Bool) {
        
        let string =  layout + "|" + sort + "|" + "\(ascending)" + "|" + groupBy + "|" + "\(directoryOnTop)"
        
        UICKeyChainStore.setString(string, forKey: key, service: k_serviceShareKeyChain)
    }
    
    func getLayoutForView(key: String) -> (String, String, Bool, String, Bool) {
        
        guard let string = UICKeyChainStore.string(forKey: key, service: k_serviceShareKeyChain) else {
            return (k_layout_list, "fileName", true, "none", true)
        }

        let array = string.components(separatedBy: "|")
        if array.count == 5 {
            let sort = NSString(string: array[2])
            let directoryOnTop = NSString(string: array[4])

            return (array[0], array[1], sort.boolValue, array[3], directoryOnTop.boolValue)
        }
        
        return (k_layout_list, "fileName", true, "none", true)
    }
    
    func convertSVGtoPNGWriteToUserData(svgUrlString: String, fileName: String?, width: CGFloat?, rewrite: Bool) {
        
        var fileNamePNG = ""
        
        guard let svgUrlString = svgUrlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return
        }
        guard let iconURL = URL(string: svgUrlString) else {
            return
        }
        
        if fileName == nil {
            fileNamePNG = iconURL.deletingPathExtension().lastPathComponent + ".png"
        } else {
            fileNamePNG = fileName!
        }
        
        let imageNamePath = CCUtility.getDirectoryUserData() + "/" + fileNamePNG
        
        if !FileManager.default.fileExists(atPath: imageNamePath) || rewrite == true {
            
            guard let imageData = try? Data(contentsOf:iconURL) else {
                return
            }
            
            if let image = UIImage.init(data: imageData) {
                
                var newImage: UIImage = image
                
                if width != nil {
                    
                    let ratio = image.size.height / image.size.width
                    let newSize = CGSize(width: width!, height: width! * ratio)
                    
                    if #available(iOS 10.0, *) {
                        let renderFormat = UIGraphicsImageRendererFormat.default()
                        renderFormat.opaque = false
                        let renderer = UIGraphicsImageRenderer(size: CGSize(width: newSize.width, height: newSize.height), format: renderFormat)
                        newImage = renderer.image {
                            (context) in
                            image.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
                        }
                    } else {
                        UIGraphicsBeginImageContextWithOptions(CGSize(width: newSize.width, height: newSize.height), false, 0)
                        image.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
                        newImage = UIGraphicsGetImageFromCurrentImageContext()!
                        UIGraphicsEndImageContext()
                    }
                }
                
                guard let pngImageData = newImage.pngData() else {
                    return
                }
                CCUtility.write(pngImageData, fileNamePath: imageNamePath)
                
            } else {
                
                guard let svgImage: SVGKImage = SVGKImage(contentsOf: iconURL) else {
                    return
                }
                
                if width != nil {
                    let scale = svgImage.size.height / svgImage.size.width
                    svgImage.size = CGSize(width: width!, height: width! * scale)
                }
                
                guard let image: UIImage = svgImage.uiImage else {
                    return
                }
                guard let pngImageData = image.pngData() else {
                    return
                }
                
                CCUtility.write(pngImageData, fileNamePath: imageNamePath)
            }
        }
    }
    
    @objc func startActivityIndicator(view: UIView) {
        
        activityIndicator.color = NCBrandColor.sharedInstance.brand
        activityIndicator.hidesWhenStopped = true
            
        view.addSubview(activityIndicator)
            
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
            
        let horizontalConstraint = NSLayoutConstraint(item: activityIndicator, attribute: NSLayoutConstraint.Attribute.centerX, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.centerX, multiplier: 1, constant: 0)
        view.addConstraint(horizontalConstraint)
            
        let verticalConstraint = NSLayoutConstraint(item: activityIndicator, attribute: NSLayoutConstraint.Attribute.centerY, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.centerY, multiplier: 1, constant: 0)
        view.addConstraint(verticalConstraint)

        activityIndicator.startAnimating()
    }
    
    @objc func stopActivityIndicator() {
        activityIndicator.stopAnimating()
        activityIndicator.removeFromSuperview()
    }
}

