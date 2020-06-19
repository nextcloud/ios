//
//  CCloadItemData.swift
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 19/02/16.
//  Copyright (c) 2016 Marino Faggiana. All rights reserved.
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
import MobileCoreServices

class CCloadItemData: NSObject {
    
    @objc func loadFiles(_ directory: String, extensionContext: NSExtensionContext, vc: ShareViewController) {
        
        var filesName: [String] = []
        var conuter = 0
        
        CCUtility.emptyTemporaryDirectory()
                
        if let inputItems : [NSExtensionItem] = extensionContext.inputItems as? [NSExtensionItem] {
            
            for item : NSExtensionItem in inputItems {
                
                if let attachments = item.attachments {
                    
                    if attachments.isEmpty {
                        
                        extensionContext.completeRequest(returningItems: nil, completionHandler: nil)
                        
                        vc.performSelector(onMainThread: #selector(vc.close), with: nil, waitUntilDone: false);
                        
                        return
                    }
                    
                    for (index, current) in (attachments.enumerated()) {
                        
                        if current.hasItemConformingToTypeIdentifier(kUTTypeItem as String) || current.hasItemConformingToTypeIdentifier("public.url") {
                            
                            var typeIdentifier = ""
                            if current.hasItemConformingToTypeIdentifier(kUTTypeItem as String) { typeIdentifier = kUTTypeItem as String }
                            if current.hasItemConformingToTypeIdentifier("public.url") { typeIdentifier = "public.url" }
                            
                            current.loadItem(forTypeIdentifier: typeIdentifier, options: nil, completionHandler: {(item, error) -> Void in
                                
                                var fileNameOriginal: String?
                                var fileName: String = ""
                                
                                let dateFormatter = DateFormatter()
                                dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss-"
                                conuter += 1
                                
                                if let url = item as? NSURL {
                                    fileNameOriginal = url.lastPathComponent!
                                }
                                
                                if error == nil {
                                                                        
                                    if let image = item as? UIImage {
                                        
                                        print("item as UIImage")
                                        
                                        if let pngImageData = image.pngData() {
                                        
                                            if fileNameOriginal != nil {
                                                fileName =  fileNameOriginal!
                                            } else {
                                                fileName = "\(dateFormatter.string(from: Date()))\(conuter).png"
                                            }
                                            
                                            let filenamePath = directory + fileName
                                            
                                            let result = (try? pngImageData.write(to: URL(fileURLWithPath: filenamePath), options: [.atomic])) != nil
                                        
                                            if result {
                                                filesName.append(fileName)
                                            }
                                            
                                        } else {
                                         
                                            print("Error image nil")
                                        }
                                    }
                                    
                                    if let url = item as? URL {
                                        
                                        print("item as url: \(String(describing: item))")
                                        
                                        if fileNameOriginal != nil {
                                            fileName =  fileNameOriginal!
                                        } else {
                                            let ext = url.pathExtension
                                            fileName = "\(dateFormatter.string(from: Date()))\(conuter)." + ext
                                        }
                                        
                                        let filenamePath = directory + fileName
                                      
                                        do {
                                            try FileManager.default.removeItem(atPath: filenamePath)
                                        }
                                        catch let error as NSError {
                                            print("Ooops! Something went wrong: \(error)")
                                        }
                                        
                                        do {
                                            try FileManager.default.copyItem(atPath: url.path, toPath:filenamePath)
                                            
                                            do {
                                                let attr : NSDictionary? = try FileManager.default.attributesOfItem(atPath: filenamePath) as NSDictionary?
                                                
                                                if let _attr = attr {
                                                    if _attr.fileSize() > 0 {
                                                        
                                                        filesName.append(fileName)
                                                    }
                                                }
                                                
                                            } catch let error as NSError {
                                                
                                                print("Error: \(error.localizedDescription)")
                                            }                                            
                                        } catch let error as NSError {
                                            
                                            print("Cannot copy file: \(error.localizedDescription)")
                                        }
                                    }
                                    
                                    if let data = item as? Data {
                                        
                                        if data.count > 0 {
                                        
                                            print("item as NSdata")
                                        
                                            if fileNameOriginal != nil {
                                                fileName =  fileNameOriginal!
                                            } else {
                                                let description = current.description
                                                let fullNameArr = description.components(separatedBy: "\"")
                                                let fileExtArr = fullNameArr[1].components(separatedBy: ".")
                                                let pathExtention = (fileExtArr[fileExtArr.count-1]).uppercased()
                                                fileName = "\(dateFormatter.string(from: Date()))\(conuter).\(pathExtention)"
                                            }
                                            
                                            let filenamePath = directory + fileName
                                            
                                            FileManager.default.createFile(atPath: filenamePath, contents:data, attributes:nil)
                                                                                
                                            filesName.append(fileName)
                                        }
                                    }
                                    
                                    if let data = item as? NSString {
                                        
                                        if data.length > 0 {
                                        
                                            print("item as NSString")
                                        
                                            let fileName = "\(dateFormatter.string(from: Date()))\(conuter).txt"
                                            let filenamePath = directory + fileName
                                        
                                            FileManager.default.createFile(atPath: filenamePath, contents:data.data(using: String.Encoding.utf8.rawValue), attributes:nil)
                                        
                                            filesName.append(fileName)
                                        }
                                    }
                                    
                                    if index + 1 == attachments.count {
                                        
                                        vc.performSelector(onMainThread: #selector(vc.reloadData), with:filesName, waitUntilDone: false)
                                    }
                                    
                                }
                            })
                            
                        }
                        
                    } // end for

                } else {
                    
                    vc.performSelector(onMainThread: #selector(vc.close), with: nil, waitUntilDone: false);
                }
            }
            
        } else {
            
            vc.performSelector(onMainThread: #selector(vc.close), with: nil, waitUntilDone: false);
        }
    }
}
