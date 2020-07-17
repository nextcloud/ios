//
//  NCNetworkingAutoUpload.swift
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

class NCNetworkingAutoUpload: NSObject {

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var timerProcess: Timer?
    
    override init() {
        super.init()

        timerProcess = Timer.scheduledTimer(timeInterval: TimeInterval(k_timerAutoUpload), target: self, selector: #selector(process), userInfo: nil, repeats: true)
    }
    
    @objc func startProcess() {
        if timerProcess?.isValid ?? false {
            process()
        }
    }

    @objc private func process() {

        var counterUpload = 0
        var sizeUpload = 0
        var maxConcurrentOperationUpload = k_maxConcurrentOperation
        
        if appDelegate.activeAccount == nil || appDelegate.activeAccount.count == 0 || appDelegate.maintenanceMode {
            return
        }
        
        timerProcess?.invalidate()
        
        let metadatasUpload = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "status == %d OR status == %d", k_metadataStatusInUpload, k_metadataStatusUploading))
        counterUpload = metadatasUpload.count
        for metadata in metadatasUpload {
            sizeUpload = sizeUpload + Int(metadata.size)
        }
    
        debugPrint("[LOG] PROCESS-AUTO-UPLOAD \(counterUpload)")
    
        // ------------------------- <selector Upload> -------------------------
         
        while counterUpload < maxConcurrentOperationUpload {
            if sizeUpload > k_maxSizeOperationUpload { break }
            let predicate = NSPredicate(format: "sessionSelector == %@ AND status == %d", selectorUploadFile, k_metadataStatusWaitUpload)
             
            if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: predicate, sorted: "date", ascending: true) {
                if CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account) {
                    if UIApplication.shared.applicationState == .background { break }
                    maxConcurrentOperationUpload = 1
                }
                NCManageDatabase.sharedInstance.setMetadataSession(ocId: metadata.ocId, status: Int(k_metadataStatusInUpload))
                
                NCNetworking.shared.upload(metadata: metadata, background: true) { (_, _) in }
                counterUpload += 1
                sizeUpload = sizeUpload + Int(metadata.size)
            } else {
                break
            }
        }
         
        // ------------------------- <selector Auto Upload> -------------------------
             
        while counterUpload < maxConcurrentOperationUpload {
            if sizeUpload > k_maxSizeOperationUpload { break }
            var predicate = NSPredicate()
             
            if UIApplication.shared.applicationState == .background {
                predicate = NSPredicate(format: "sessionSelector == %@ AND status == %d AND typeFile != %@", selectorUploadAutoUpload, k_metadataStatusWaitUpload, k_metadataTypeFile_video)
            } else {
                predicate = NSPredicate(format: "sessionSelector == %@ AND status == %d", selectorUploadAutoUpload, k_metadataStatusWaitUpload)
            }
             
            if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: predicate, sorted: "date", ascending: true) {
                if CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account) {
                    if UIApplication.shared.applicationState == .background { break }
                    maxConcurrentOperationUpload = 1
                }
                NCManageDatabase.sharedInstance.setMetadataSession(ocId: metadata.ocId, status: Int(k_metadataStatusInUpload))
                NCNetworking.shared.upload(metadata: metadata, background: true) { (_, _) in }
                counterUpload += 1
                sizeUpload = sizeUpload + Int(metadata.size)
            } else {
                break
            }
        }
         
        // ------------------------- <selector Auto Upload All> ----------------------
         
        // Verify num error k_maxErrorAutoUploadAll after STOP (100)
        let metadatasInError = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "sessionSelector == %@ AND status == %d", selectorUploadAutoUploadAll, k_metadataStatusUploadError))
        if metadatasInError.count >= k_maxErrorAutoUploadAll {
            NCContentPresenter.shared.messageNotification("_error_", description: "_too_errors_automatic_all_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError))
        } else {
            while counterUpload < maxConcurrentOperationUpload {
                if sizeUpload > k_maxSizeOperationUpload { break }
                var predicate = NSPredicate()
                        
                if UIApplication.shared.applicationState == .background {
                    predicate = NSPredicate(format: "sessionSelector == %@ AND status == %d AND typeFile != %@", selectorUploadAutoUploadAll, k_metadataStatusWaitUpload, k_metadataTypeFile_video)
                } else {
                    predicate = NSPredicate(format: "sessionSelector == %@ AND status == %d", selectorUploadAutoUploadAll, k_metadataStatusWaitUpload)
                }
                        
                if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: predicate, sorted: "date", ascending: true) {
                    if CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account) {
                        if UIApplication.shared.applicationState == .background { break }
                                maxConcurrentOperationUpload = 1
                    }
                    NCManageDatabase.sharedInstance.setMetadataSession(ocId: metadata.ocId, status: Int(k_metadataStatusInUpload))
                    NCNetworking.shared.upload(metadata: metadata, background: true) { (_, _) in }
                    counterUpload += 1
                    sizeUpload = sizeUpload + Int(metadata.size)
                } else {
                    break
                }
            }
        }
         
        // No upload available ? --> Retry Upload in Error
        if counterUpload == 0 {
            let metadatas = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "status == %d", k_metadataStatusUploadError))
            for metadata in metadatas {
                NCManageDatabase.sharedInstance.setMetadataSession(ocId: metadata.ocId, session: NCCommunicationCommon.shared.sessionIdentifierBackground, sessionError: "", sessionTaskIdentifier: 0 ,status: Int(k_metadataStatusWaitUpload))
            }
        }
         
        // verify delete Asset Local Identifiers in auto upload (DELETE Photos album)
        if (counterUpload == 0 && appDelegate.passcodeViewController == nil) {
            NCUtility.sharedInstance.deleteAssetLocalIdentifiers(account: appDelegate.activeAccount, sessionSelector: selectorUploadAutoUpload)
        }
        
        timerProcess = Timer.scheduledTimer(timeInterval: TimeInterval(k_timerAutoUpload), target: self, selector: #selector(process), userInfo: nil, repeats: true)
     }
}

