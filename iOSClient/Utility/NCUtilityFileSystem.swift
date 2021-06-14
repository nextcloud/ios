//
//  NCUtilityFileSystem.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 28/05/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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
import PhotosUI

class NCUtilityFileSystem: NSObject {
    @objc static let shared: NCUtilityFileSystem = {
        let instance = NCUtilityFileSystem()
        return instance
    }()
    
    let fileManager = FileManager.default
    
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
    
    @objc func getFileSize(filePath: String) -> Int64 {
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: filePath)
            return attributes[FileAttributeKey.size] as? Int64 ?? 0
        } catch {
            print(error)
        }
        return 0
    }
    
    @objc func getFileModificationDate(filePath: String) -> NSDate? {
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: filePath)
            return attributes[FileAttributeKey.modificationDate] as? NSDate
        } catch {
            print(error)
        }
        return nil
    }
    
    @objc func getFileCreationDate(filePath: String) -> NSDate? {
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: filePath)
            return attributes[FileAttributeKey.creationDate] as? NSDate
        } catch {
            print(error)
        }
        return nil
    }
    
    @objc func writeFile(fileURL: URL, text: String) -> Bool {
        
        do {
            try FileManager.default.removeItem(at: fileURL)
        }
        catch {
            print(error)
        }
        
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            return true
        }
        catch {
            print(error)
            return false
        }
    }
    
    @objc func deleteFile(filePath: String) {
        
        do {
            try FileManager.default.removeItem(atPath: filePath)
        }
        catch {
            print(error)
        }
    }
    
    @discardableResult
    @objc func moveFile(atPath: String, toPath: String) -> Bool {

        if atPath == toPath { return true }
    
        do {
            try FileManager.default.removeItem(atPath: toPath)
        }
        catch {
            print(error)
        }
                
        do {
            try FileManager.default.copyItem(atPath: atPath, toPath: toPath)
            try FileManager.default.removeItem(atPath: atPath)
            return true
        }
        catch {
            print(error)
            return false
        }
    }
    
    @discardableResult
    @objc func copyFile(atPath: String, toPath: String) -> Bool {

        if atPath == toPath { return true }
    
        do {
            try FileManager.default.removeItem(atPath: toPath)
        }
        catch {
            print(error)
        }
                
        do {
            try FileManager.default.copyItem(atPath: atPath, toPath: toPath)
            return true
        }
        catch {
            print(error)
            return false
        }
    }
    
    @objc func moveFileInBackground(atPath: String, toPath: String) {
        
        if atPath == toPath { return }
        
        DispatchQueue.global().async {
            
            try? FileManager.default.removeItem(atPath: toPath)
            try? FileManager.default.copyItem(atPath: atPath, toPath: toPath)
            try? FileManager.default.removeItem(atPath: atPath)
        }
    }
    
    @objc func linkItem(atPath: String, toPath: String) {
    
        try? FileManager.default.removeItem(atPath: toPath)
        try? FileManager.default.linkItem(atPath: atPath, toPath: toPath)
    }
    
    // MARK: - 
    
    @objc func getWebDAV(account: String) -> String {
        return NCManageDatabase.shared.getCapabilitiesServerString(account: account, elements: NCElementsJSON.shared.capabilitiesWebDavRoot) ?? "remote.php/webdav"
    }
    
    @objc func getDAV() -> String {
        return "remote.php/dav"
    }
    
    @objc func getHomeServer(urlBase: String, account: String) -> String {
        return urlBase + "/" + self.getWebDAV(account: account)
    }
    
    @objc func deletingLastPathComponent(serverUrl: String, urlBase: String, account: String) -> String {
        if getHomeServer(urlBase: urlBase, account: account) == serverUrl { return serverUrl }
        let fileName = (serverUrl as NSString).lastPathComponent
        let serverUrl = serverUrl.replacingOccurrences(of: "/"+fileName, with: "", options: String.CompareOptions.backwards, range: nil)
        return serverUrl
    }
    
    @objc func createFileName(_ fileName: String, serverUrl: String, account: String) -> String {
        
        var resultFileName = fileName
        var exitLoop = false
            
            while exitLoop == false {
                
                if NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "fileNameView == %@ AND serverUrl == %@ AND account == %@", resultFileName, serverUrl, account)) != nil {
                    
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
}

