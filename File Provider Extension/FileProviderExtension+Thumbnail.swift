//
//  FileProviderExtension+Thumbnail.swift
//  PickerFileProvider
//
//  Created by Marino Faggiana on 28/05/18.
//  Copyright © 2018 TWS. All rights reserved.
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
                    
                    let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata!.directoryID)
                    let fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata!.fileName, serverUrl: serverUrl, activeUrl: providerData.accountUrl)
                    
                    let ocNetworking = OCnetworking.init(delegate: nil, metadataNet: nil, withUser: providerData.accountUser, withUserID: providerData.accountUserID, withPassword: providerData.accountPassword, withUrl: providerData.accountUrl)
                    ocNetworking?.downloadThumbnail(withDimOfThumbnail: "m", fileID: metadata!.fileID, fileNamePath: fileNamePath, fileNameView: metadata!.fileNameView, success: {
                        
                        do {
                            let url = URL.init(fileURLWithPath: CCUtility.getDirectoryProviderStorageIconFileID(metadata!.fileID, fileNameView: metadata!.fileNameView))
                            let data = try Data.init(contentsOf: url)
                            perThumbnailCompletionHandler(itemIdentifier, data, nil)
                        } catch let error {
                            print("error: \(error)")
                            perThumbnailCompletionHandler(itemIdentifier, nil, NSFileProviderError(.noSuchItem))
                        }
                        
                        counterProgress += 1
                        if (counterProgress == progress.totalUnitCount) {
                            completionHandler(nil)
                        }
                        
                    }, failure: { (errorMessage, errorCode) in
                        
                        perThumbnailCompletionHandler(itemIdentifier, nil, NSFileProviderError(.serverUnreachable))
                        
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
