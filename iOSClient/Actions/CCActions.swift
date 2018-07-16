//
//  CCActions.swift
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 06/02/17.
//  Copyright (c) 2017 TWS. All rights reserved.
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

@objc protocol CCActionsRenameDelegate {

    func renameSuccess(_ metadataNet: CCMetadataNet)
    func renameMoveFileOrFolderFailure(_ metadataNet: CCMetadataNet, message: NSString, errorCode: NSInteger)
}

@objc protocol CCActionsSearchDelegate {
    
    func searchSuccessFailure(_ metadataNet: CCMetadataNet, metadatas: [Any], message: NSString, errorCode: NSInteger)
}

class CCActions: NSObject {
    
    //MARK: Shared Instance
    
    @objc static let sharedInstance: CCActions = {
        let instance = CCActions()
        return instance
    }()
    
    //MARK: Local Variable
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    //MARK: Init
    
    override init() {
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Rename File or Folder
    // --------------------------------------------------------------------------------------------
    
    @objc func renameFileOrFolder(_ metadata: tableMetadata, fileName: String, delegate: AnyObject) {

        let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)
        
        let fileName = CCUtility.removeForbiddenCharactersServer(fileName)!
        
        guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
            return
        }
        
        if fileName.count == 0 {
            return
        }
        
        if metadata.fileNameView == fileName {
            return
        }
        
        // Verify if exists the fileName TO
        
        let ocNetworking = OCnetworking.init(delegate: nil, metadataNet: nil, withUser: self.appDelegate.activeUser, withUserID: self.appDelegate.activeUserID, withPassword: self.appDelegate.activePassword, withUrl: self.appDelegate.activeUrl)
        
        ocNetworking?.readFile(fileName, serverUrl: serverUrl, account: self.appDelegate.activeAccount, success: { (metadata) in
                
            let alertController = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: NSLocalizedString("_file_already_exists_", comment: ""), preferredStyle: UIAlertControllerStyle.alert)
                
            let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default) {
                (result : UIAlertAction) -> Void in
            }
                
            alertController.addAction(okAction)
                
            delegate.present(alertController, animated: true, completion: nil)
                
        }, failure: { (message, errorCode) in
                
            metadataNet.action = actionMoveFileOrFolder
            metadataNet.delegate = delegate
            metadataNet.directory = metadata.directory
            metadataNet.fileID = metadata.fileID
            metadataNet.fileName = metadata.fileName
            metadataNet.fileNameTo = fileName
            metadataNet.fileNameView = metadata.fileNameView
            metadataNet.selector = selectorRename
            metadataNet.serverUrl = serverUrl
            metadataNet.serverUrlTo = serverUrl
                
            self.appDelegate.addNetworkingOperationQueue(self.appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
        })
    }
    
    @objc func renameSuccess(_ metadataNet: CCMetadataNet) {
                
        // Rename metadata
        _ = NCManageDatabase.sharedInstance.renameMetadata(fileNameTo: metadataNet.fileNameTo, fileID: metadataNet.fileID)
        
        if metadataNet.directory == true {
            
            let serverUrl = CCUtility.stringAppendServerUrl(metadataNet.serverUrl, addFileName: metadataNet.fileName)
            let serverUrlTo = CCUtility.stringAppendServerUrl(metadataNet.serverUrl, addFileName: metadataNet.fileNameTo)
            
            guard let directoryTable = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "serverUrl == %@", serverUrl!)) else {
                
                metadataNet.delegate?.renameMoveFileOrFolderFailure(metadataNet, message: "Internal error, ServerUrl not found" as NSString, errorCode: 0)
                return
            }
            
            NCManageDatabase.sharedInstance.setDirectory(serverUrl: serverUrl!, serverUrlTo: serverUrlTo!, etag: nil, fileID: nil, encrypted: directoryTable.e2eEncrypted)
            
        } else {
            
            NCManageDatabase.sharedInstance.setLocalFile(fileID: metadataNet.fileID, date: nil, exifDate: nil, exifLatitude: nil, exifLongitude: nil, fileName: metadataNet.fileNameTo, etag: nil)
            
            // Move file system
            do {
                try FileManager.default.moveItem(atPath: CCUtility.getDirectoryProviderStorageFileID(metadataNet.fileID) + "/" + metadataNet.fileName, toPath: CCUtility.getDirectoryProviderStorageFileID(metadataNet.fileID) + "/" +  metadataNet.fileNameTo)
            } catch let error {
                print("error: \(error)")
            }
            do {
                try FileManager.default.moveItem(atPath: CCUtility.getDirectoryProviderStorageIconFileID(metadataNet.fileID, fileNameView: metadataNet.fileName), toPath: CCUtility.getDirectoryProviderStorageIconFileID(metadataNet.fileID, fileNameView: metadataNet.fileNameTo))
            } catch let error {
                print("error: \(error)")
            }
        }
        
        metadataNet.delegate?.renameSuccess(metadataNet)
    }
    
    @objc func renameMoveFileOrFolderFailure(_ metadataNet: CCMetadataNet, message: NSString, errorCode: NSInteger) {
        
        if message.length > 0 {
            
            var title : String = ""
            
            if metadataNet.selector == selectorRename {
                
                title = "_delete_"
            }
            
            if metadataNet.selector == selectorMove {
                
                title = "_move_"
            }
            
            appDelegate.messageNotification(title, description: message as String, visible: true, delay:TimeInterval(k_dismissAfterSecond), type:TWMessageBarMessageType.error, errorCode: errorCode)
        }
        
        metadataNet.delegate?.renameMoveFileOrFolderFailure(metadataNet, message: message as NSString, errorCode: errorCode)
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Search
    // --------------------------------------------------------------------------------------------
    
    @objc func search(_ serverUrl: String, fileName: String, etag: String, depth: String, date: Date?, contenType: [String]?, selector: String, delegate: AnyObject) {
        
        guard let directoryID = NCManageDatabase.sharedInstance.getDirectoryID(serverUrl) else {
            return
        }
        
        // Search DAV API
            
        let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)
        
        metadataNet.action = actionSearch
        metadataNet.contentType = contenType
        metadataNet.date = date
        metadataNet.delegate = delegate
        metadataNet.directoryID = directoryID
        metadataNet.fileName = fileName
        metadataNet.etag = etag
        metadataNet.depth = depth
        metadataNet.priority = Operation.QueuePriority.high.rawValue
        metadataNet.selector = selector
        metadataNet.serverUrl = serverUrl

        appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
    }
    
    @objc func searchSuccessFailure(_ metadataNet: CCMetadataNet, metadatas: [tableMetadata], message: NSString, errorCode: NSInteger) {
        
        metadataNet.delegate?.searchSuccessFailure(metadataNet, metadatas: metadatas, message: message, errorCode: errorCode)
    }
}




