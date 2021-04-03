//
//  NCNetworkingProcessUpload.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 25/06/2020.
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
import NCCommunication

class NCNetworkingProcessUpload: NSObject {

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var timerProcess: Timer?
    
    let maxConcurrentOperationUpload = 5
    
    override init() {
        super.init()
        startTimer()
    }
    
    @objc func startProcess() {
        if timerProcess?.isValid ?? false {
            process()
        }
    }
    
    func startTimer() {
        timerProcess = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(process), userInfo: nil, repeats: true)
    }

    @objc private func process() {

        if appDelegate.account == "" { return }
        
        var counterUpload: Int = 0
        var sizeUpload = 0
        let sessionSelectors = [NCGlobal.shared.selectorUploadFile, NCGlobal.shared.selectorUploadAutoUpload, NCGlobal.shared.selectorUploadAutoUploadAll]
        
        let metadatasUpload = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "status == %d OR status == %d", NCGlobal.shared.metadataStatusInUpload, NCGlobal.shared.metadataStatusUploading))
        counterUpload = metadatasUpload.count
        for metadata in metadatasUpload {
            sizeUpload = sizeUpload + Int(metadata.size)
        }
        if sizeUpload > NCGlobal.shared.uploadMaxFileSize { return }
        
        timerProcess?.invalidate()
        
        print("[LOG] PROCESS-UPLOAD \(counterUpload)")
    
        NCNetworking.shared.getOcIdInBackgroundSession { (listOcId) in
            
            for sessionSelector in sessionSelectors {
                if counterUpload < self.maxConcurrentOperationUpload {
                    let limit = self.maxConcurrentOperationUpload - counterUpload
                    var predicate = NSPredicate()
                    if UIApplication.shared.applicationState == .background {
                        predicate = NSPredicate(format: "sessionSelector == %@ AND status == %d AND (typeFile != %@ || livePhoto == true)", sessionSelector, NCGlobal.shared.metadataStatusWaitUpload, NCGlobal.shared.metadataTypeFileVideo)
                    } else {
                        predicate = NSPredicate(format: "sessionSelector == %@ AND status == %d", sessionSelector, NCGlobal.shared.metadataStatusWaitUpload)
                    }
                    let metadatas = NCManageDatabase.shared.getAdvancedMetadatas(predicate: predicate, page: 1, limit: limit, sorted: "date", ascending: true)
                    if metadatas.count > 0 {
                        NCCommunicationCommon.shared.writeLog("PROCESS-UPLOAD find \(metadatas.count) items")
                    }
                    
                    for metadata in metadatas {
                        
                        // Is already in upload ? skipped
                        if listOcId.contains(metadata.ocId) {
                            NCCommunicationCommon.shared.writeLog("Process auto upload skipped file: \(metadata.serverUrl)/\(metadata.fileNameView), because is already in session.")
                            continue
                        }
                        
                        // Session Extension ? skipped
                        if metadata.session == NCNetworking.shared.sessionIdentifierBackgroundExtension {
                            continue
                        }
                        
                        // Is already in upload E2EE / CHUNK ? exit
                        for metadata in metadatasUpload {
                            if metadata.chunk || metadata.e2eEncrypted {
                                self.startTimer()
                                return
                            }
                        }
                        
                        // Chunk 
                        if metadata.chunk && UIApplication.shared.applicationState == .active {
                            if let metadata = NCManageDatabase.shared.setMetadataStatus(ocId: metadata.ocId, status: NCGlobal.shared.metadataStatusInUpload) {
                                NCNetworking.shared.upload(metadata: metadata) { (_, _) in }
                            }
                            self.startTimer()
                            return
                        }
                        
                        // E2EE
                        if metadata.e2eEncrypted && UIApplication.shared.applicationState == .active {
                            if let metadata = NCManageDatabase.shared.setMetadataStatus(ocId: metadata.ocId, status: NCGlobal.shared.metadataStatusInUpload) {
                                NCNetworking.shared.upload(metadata: metadata) { (_, _) in }
                            }
                            self.startTimer()
                            return
                        }
                        
                        counterUpload += 1
                        if let metadata = NCManageDatabase.shared.setMetadataStatus(ocId: metadata.ocId, status: NCGlobal.shared.metadataStatusInUpload) {
                            NCNetworking.shared.upload(metadata: metadata) { (_, _) in }
                        }
                        sizeUpload = sizeUpload + Int(metadata.size)
                        if sizeUpload > NCGlobal.shared.uploadMaxFileSize {
                            self.startTimer()
                            return
                        }
                    }
                    
                } else {
                    self.startTimer()
                    return
                }
            }
            
            // No upload available ? --> Retry Upload in Error
            if counterUpload == 0 {
                let metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "status == %d", NCGlobal.shared.metadataStatusUploadError))
                for metadata in metadatas {
                    NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: NCNetworking.shared.sessionIdentifierBackground, sessionError: "", sessionTaskIdentifier: 0 ,status: NCGlobal.shared.metadataStatusWaitUpload)
                }
            }
             
            // verify delete Asset Local Identifiers in auto upload (DELETE Photos album)
            if (counterUpload == 0 && self.appDelegate.passcodeViewController == nil) {
                self.deleteAssetLocalIdentifiers(account: self.appDelegate.account, sessionSelector: NCGlobal.shared.selectorUploadAutoUpload) {
                    self.startTimer()
                }
            } else {
                self.startTimer()
            }
        }
    }
    
    private func deleteAssetLocalIdentifiers(account: String, sessionSelector: String, completition: @escaping () -> ()) {
        
        if UIApplication.shared.applicationState != .active {
            completition()
            return
        }
        let metadatasSessionUpload = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND session CONTAINS[cd] %@", account, "upload"))
        if metadatasSessionUpload.count > 0 {
            completition()
            return
        }
        let localIdentifiers = NCManageDatabase.shared.getAssetLocalIdentifiersUploaded(account: account, sessionSelector: sessionSelector)
        if localIdentifiers.count == 0 {
            completition()
            return
        }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }, completionHandler: { success, error in
            DispatchQueue.main.async {
                NCManageDatabase.shared.clearAssetLocalIdentifiers(localIdentifiers, account: account)
                completition()
            }
        })
    }
    
    //MARK: -
    
    @objc func createProcessUploads(metadatas: [tableMetadata], verifyAlreadyExists: Bool = false) {
        
        var metadatasForUpload: [tableMetadata] = []
        
        for metadata in metadatas {
            
            if verifyAlreadyExists {
                if NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ && serverUrl == %@ && fileName == %@ && session != ''", metadata.account, metadata.serverUrl, metadata.fileName)) != nil {
                    continue
                }
            }
            
            // E2EE
            if CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account, urlBase: metadata.urlBase) {
                metadata.e2eEncrypted = true
            }
            
            // CHUNCK
            let chunckSize = NCGlobal.shared.chunckSize * 1000000
            if metadata.size <= chunckSize {
                metadatasForUpload.append(metadata)
            } else {
                metadata.chunk = true
                metadata.session = NCCommunicationCommon.shared.sessionIdentifierUpload
                metadatasForUpload.append(tableMetadata.init(value: metadata))
            }
        }
        
        NCManageDatabase.shared.addMetadatas(metadatasForUpload)
        
        startProcess()
    }
}

