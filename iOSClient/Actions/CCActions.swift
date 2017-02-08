//
//  CCActions.swift
//  Crypto Cloud Technology Nextcloud
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

@objc protocol CCActionsDelegate  {
    
    func deleteFileOrFolderSuccess(_ metadataNet : CCMetadataNet)
    func deleteFileOrFolderFailure(_ metadataNet : CCMetadataNet, message : NSString, errorCode : NSInteger)
}

class CCActions: NSObject {
    
    //MARK: Shared Instance
    
    static let sharedInstance : CCActions = {
        let instance = CCActions()
        return instance
    }()
    
    //MARK: Local Variable
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var metadataNet : CCMetadataNet = CCMetadataNet.init()
    
    var delegate : CCActionsDelegate!
    
    //MARK: Init
    
    override init() {
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Delete File or Folder
    // --------------------------------------------------------------------------------------------

    func deleteFileOrFolder(_ metadata : CCMetadata, delegate : AnyObject) {
        
        let serverUrl : String = CCCoreData.getServerUrl(fromDirectoryID: metadata.directoryID, activeAccount: appDelegate.activeAccount)!
        let metadataNet : CCMetadataNet = CCMetadataNet.init()
        
        if metadata.cryptated == true {
            
            metadataNet.action = actionDeleteFileDirectory
            metadataNet.delegate = delegate
            metadataNet.fileID = metadata.fileID
            metadataNet.fileNamePrint = metadata.fileNamePrint
            metadataNet.metadata = metadata
            metadataNet.serverUrl = serverUrl
            
            // data crypto
            metadataNet.fileName = metadata.fileNameData
            metadataNet.selector = selectorDeleteCrypto
            
            appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
            
            // plist
            metadataNet.fileName = metadata.fileName;
            metadataNet.selector = selectorDeletePlist

            appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
            
        } else {
            
            metadataNet.action = actionDeleteFileDirectory
            metadataNet.delegate = delegate
            metadataNet.fileID = metadata.fileID
            metadataNet.fileName = metadata.fileName
            metadataNet.fileNamePrint = metadata.fileNamePrint
            metadataNet.metadata = metadata
            metadataNet.selector = selectorDelete
            metadataNet.serverUrl = serverUrl

            appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
        }
    }
    
    func deleteFileOrFolderSuccess(_ metadataNet : CCMetadataNet) {
        
        self.delegate = metadataNet.delegate as! CCActionsDelegate
        
        CCCoreData.deleteFile(metadataNet.metadata, serverUrl: metadataNet.serverUrl, directoryUser: appDelegate.directoryUser, typeCloud: appDelegate.typeCloud, activeAccount: appDelegate.activeAccount)
        
        delegate?.deleteFileOrFolderSuccess(metadataNet)
    }
    
    func deleteFileOrFolderFailure(_ metadataNet : CCMetadataNet, message : NSString, errorCode : NSInteger) {
        
        self.delegate = metadataNet.delegate as! CCActionsDelegate
        
        if errorCode == 404 {
            CCCoreData.deleteFile(metadataNet.metadata, serverUrl: metadataNet.serverUrl, directoryUser: appDelegate.directoryUser, typeCloud: appDelegate.typeCloud, activeAccount: appDelegate.activeAccount)
        }

        if message.length > 0 {
            appDelegate.messageNotification("_delete_", description: message as String, visible: true, delay:TimeInterval(dismissAfterSecond), type:TWMessageBarMessageType.error)
        }
        
        delegate?.deleteFileOrFolderFailure(metadataNet, message: message, errorCode: errorCode)
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Rename File or Folder
    // --------------------------------------------------------------------------------------------
    
    func renameFileOrFolder(_ metadata : CCMetadata, fileName : String, delegate : AnyObject) {

        let crypto : CCCrypto = CCCrypto.init()
        let metadataNet : CCMetadataNet = CCMetadataNet.init()
        
        let fileName : String = CCUtility.removeForbiddenCharacters(fileName, hasServerForbiddenCharactersSupport: appDelegate.hasServerForbiddenCharactersSupport)!
        
        let serverUrl : String = CCCoreData.getServerUrl(fromDirectoryID: metadata.directoryID, activeAccount: appDelegate.activeAccount)!
        
        if fileName.characters.count == 0 {
            return
        }
        
        if metadata.fileNamePrint == fileName {
            return
        }
        
        if metadata.cryptated {
            
            // Encrypted
            
            let newTitle = AESCrypt.encrypt(fileName, password: crypto.getKeyPasscode(metadata.uuid))
            
            if !crypto.updateTitleFilePlist(metadata.fileName, title: newTitle, directoryUser: appDelegate.directoryUser) {
                
                print("[LOG] Rename cryptated error \(fileName)")
                
                appDelegate.messageNotification("_rename_", description: "_file_not_found_reload_", visible: true, delay: TimeInterval(dismissAfterSecond), type: TWMessageBarMessageType.error)
                
                return
            }
            
            if !metadata.directory {
                
                do {
                    
                    let dataFile = try NSData.init(contentsOfFile: "\(appDelegate.directoryUser)/\(metadata.fileID)", options:[])
                    
                    do {
                        
                        let dataFileEncrypted = try RNEncryptor.encryptData(dataFile as Data!, with: kRNCryptorAES256Settings, password: crypto.getKeyPasscode(metadata.uuid))
                        
                        
                        
                        
                    } catch let error {
                        print(error.localizedDescription)
                        return
                    }

                } catch let error {
                    print(error.localizedDescription)
                    return
                }
                
            }
 
        } else {
 
            // Plain
            
            metadataNet.action = actionMoveFileOrFolder
            metadataNet.fileID = metadata.fileID
            metadataNet.fileName = metadata.fileName
            metadataNet.fileNamePrint = metadata.fileNamePrint
            metadataNet.fileNameTo = fileName
            metadataNet.selector = selectorRename
            metadataNet.selectorPost = selectorReadFolderForced
            metadataNet.serverUrl = serverUrl
            metadataNet.serverUrlTo = serverUrl
            
            appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
        }
    }
}

    /*
    
    if (metadata.directory == NO) {
    // cripto il file fileID in temp
    
    NSData *data = [NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID]];
    
    if (data) data = [RNEncryptor encryptData:data withSettings:kRNCryptorAES256Settings password:[crypto getKeyPasscode:metadata.uuid] error:nil];
    if (data) [data writeToFile:[NSTemporaryDirectory() stringByAppendingString:metadata.fileNameData] atomically:YES];
    }
    
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    
    metadataNet.action = actionUploadOnlyPlist;
    metadataNet.fileName = metadata.fileName;
    metadataNet.selectorPost = selectorReadFolderForced;
    metadataNet.serverUrl = _localServerUrl;
    metadataNet.session = upload_session_foreground;
    metadataNet.taskStatus = taskStatusResume;
    
    if ([CCCoreData isOfflineLocalFileID:metadata.fileID activeAccount:app.activeAccount])
    metadataNet.selectorPost = selectorAddOffline;
    
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    
    // delete file in filesystem
    [CCCoreData deleteFile:metadata serverUrl:_localServerUrl directoryUser:app.directoryUser typeCloud:app.typeCloud activeAccount:app.activeAccount];
    }

    */

