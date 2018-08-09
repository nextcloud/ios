//
//  NCUtility.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 25/06/18.
//  Copyright © 2018 TWS. All rights reserved.
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
}
