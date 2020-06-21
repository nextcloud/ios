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

import Foundation
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
    
    @objc func getFileSize(filePath: String) -> Double {
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: filePath)
            return attributes[FileAttributeKey.size] as? Double ?? 0
        } catch { }
        return 0
    }
    
    @objc func getFileModificationDate(filePath: String) -> NSDate? {
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: filePath)
            return attributes[FileAttributeKey.modificationDate] as? NSDate
        } catch { }
        return nil
    }
    
    @objc func getFileCreationDate(filePath: String) -> NSDate? {
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: filePath)
            return attributes[FileAttributeKey.creationDate] as? NSDate
        } catch { }
        return nil
    }
    
    // MARK: - Get file data as chunks Methode.
    func getFileDataInChunks() {
        
        let doumentDirectoryPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        let filePath = doumentDirectoryPath.appendingPathComponent("video.mp4")
        
        
        //Check file exits at path or not.
        if FileManager.default.fileExists(atPath: filePath) {
            
            let chunkSize = 1024 // divide data into 1 kb
            
            //Create NSMutableData object to save read data.
            let ReadData = NSMutableData()
            
            do {
                
                //open file for reading.
                let outputFileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: filePath))
                
                // get the first chunk
                var datas = outputFileHandle.readData(ofLength: chunkSize)
                
                //check next chunk is empty or not.
                while !(datas.isEmpty) {
                    
                    //here I write chunk data to ReadData or you can directly write to socket.
                    ReadData.append(datas)
                    
                    // get the next chunk
                    datas = outputFileHandle.readData(ofLength: chunkSize)
                    
                    print("Running: \(ReadData.length)")
                }
                
                //close outputFileHandle after reading data complete.
                outputFileHandle.closeFile()
                
                print("File reading complete")
                
            }catch let error as NSError {
                print("Error : \(error.localizedDescription)")
            }
        }
    }
}

