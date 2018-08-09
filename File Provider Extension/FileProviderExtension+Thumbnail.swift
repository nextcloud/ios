//
//  FileProviderExtension+Thumbnail.swift
//  PickerFileProvider
//
//  Created by Marino Faggiana on 28/05/18.
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

import FileProvider

extension FileProviderExtension {

    override func fetchThumbnails(for itemIdentifiers: [NSFileProviderItemIdentifier], requestedSize size: CGSize, perThumbnailCompletionHandler: @escaping (NSFileProviderItemIdentifier, Data?, Error?) -> Void, completionHandler: @escaping (Error?) -> Void) -> Progress {
                
        let progress = Progress(totalUnitCount: Int64(itemIdentifiers.count))
        var counterProgress: Int64 = 0
        
        // Check account
        if providerData.setupActiveAccount() == false {
            completionHandler(NSFileProviderError(.notAuthenticated))
            return Progress(totalUnitCount:0)
        }
        
        for itemIdentifier in itemIdentifiers {
            
            let metadata = providerData.getTableMetadataFromItemIdentifier(itemIdentifier)
            if metadata != nil {
                
                if (metadata!.typeFile == k_metadataTypeFile_image || metadata!.typeFile == k_metadataTypeFile_video) {
                    
                    guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata!.directoryID) else {
                        continue
                    }
                    
                    
                    let width = NCUtility.sharedInstance.getScreenWidthForPreview()
                    let height = NCUtility.sharedInstance.getScreenHeightForPreview()
                    
                    let ocNetworking = OCnetworking.init(delegate: nil, metadataNet: nil, withUser: providerData.accountUser, withUserID: providerData.accountUserID, withPassword: providerData.accountPassword, withUrl: providerData.accountUrl)
                    
                    ocNetworking?.downloadPreview(with: metadata!, serverUrl: serverUrl, withWidth: width, andHeight: height, completion: { (message, errorCode) in
                        
                        if errorCode == 0 {
                            do {
                                let url = URL.init(fileURLWithPath: CCUtility.getDirectoryProviderStorageIconFileID(metadata!.fileID, fileNameView: metadata!.fileNameView))
                                let data = try Data.init(contentsOf: url)
                                perThumbnailCompletionHandler(itemIdentifier, data, nil)
                            } catch let error {
                                print("error: \(error)")
                                perThumbnailCompletionHandler(itemIdentifier, nil, NSFileProviderError(.noSuchItem))
                            }
                        } else {
                            perThumbnailCompletionHandler(itemIdentifier, nil, NSFileProviderError(.serverUnreachable))
                        }
                        
                        counterProgress += 1
                        if (counterProgress == progress.totalUnitCount) {
                            completionHandler(nil)
                        }
                    })
                    
                } else {
                    
                    counterProgress += 1
                    if (counterProgress == progress.totalUnitCount) {
                        completionHandler(nil)
                    }
                }
            } else {
                
                counterProgress += 1
                if (counterProgress == progress.totalUnitCount) {
                    completionHandler(nil)
                }
            }
        }
        
        return progress
    }

}
