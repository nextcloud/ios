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
    
    func convertSVGtoPNGWriteToUserData(svgUrlString: String) {
        
        guard let svgUrlString = svgUrlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return
        }
        guard let iconURL = URL(string: svgUrlString) else {
            return
        }
        
        let fileName = iconURL.deletingPathExtension().lastPathComponent
        let imageNamePath = CCUtility.getDirectoryUserData() + "/" + fileName + ".png"
        
        if !FileManager.default.fileExists(atPath: imageNamePath) {
            guard let svgkImage: SVGKImage = SVGKImage(contentsOf: iconURL) else {
                return
            }
            guard let image: UIImage = svgkImage.uiImage else {
                return
            }
            guard let pngImageData = image.pngData() else {
                return
            }
            CCUtility.write(pngImageData, fileNamePath: imageNamePath)
        }
    }
}

//MARK: -

@IBDesignable class NCAvatar: UIImageView {
    
    @IBInspectable var roundness: CGFloat = 2 {
        didSet{
            layoutSubviews()
        }
    }
    
    @IBInspectable var borderWidth: CGFloat = 5 {
        didSet{
            layoutSubviews()
        }
    }
    
    @IBInspectable var borderColor: UIColor = UIColor.blue {
        didSet{
            layoutSubviews()
        }
    }
    
    @IBInspectable var background: UIColor = UIColor.clear {
        didSet{
            layoutSubviews()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        layer.cornerRadius = bounds.width / roundness
        layer.borderWidth = borderWidth
        layer.borderColor = borderColor.cgColor
        layer.backgroundColor = background.cgColor
        clipsToBounds = true
        
        let path = UIBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), cornerRadius: bounds.width / roundness)
        let mask = CAShapeLayer()
        
        mask.path = path.cgPath
        layer.mask = mask
    }
}
