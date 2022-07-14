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

import UIKit
import NCCommunication
import Photos
import Queuer

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
        timerProcess?.invalidate()
        timerProcess = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(process), userInfo: nil, repeats: true)
    }

    func stopTimer() {
        timerProcess?.invalidate()
    }

    @objc private func process() {
        guard !appDelegate.account.isEmpty else { return }

        let queue = DispatchQueue.global(qos: .background)
        var counterUpload: Int = 0
        let sessionSelectors = [NCGlobal.shared.selectorUploadFile, NCGlobal.shared.selectorUploadAutoUpload, NCGlobal.shared.selectorUploadAutoUploadAll]
        let metadatasUpload = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "status == %d OR status == %d", NCGlobal.shared.metadataStatusInUpload, NCGlobal.shared.metadataStatusUploading))
        counterUpload = metadatasUpload.count

        stopTimer()

        print("[LOG] PROCESS-UPLOAD \(counterUpload)")

        NCNetworking.shared.getOcIdInBackgroundSession(queue: queue, completion: { listOcId in

            for sessionSelector in sessionSelectors {
                if counterUpload < self.maxConcurrentOperationUpload {

                    let limit = self.maxConcurrentOperationUpload - counterUpload
                    let metadatas = NCManageDatabase.shared.getAdvancedMetadatas(predicate: NSPredicate(format: "sessionSelector == %@ AND status == %d", sessionSelector, NCGlobal.shared.metadataStatusWaitUpload), page: 1, limit: limit, sorted: "date", ascending: true)
                    if metadatas.count > 0 {
                        NCCommunicationCommon.shared.writeLog("PROCESS-UPLOAD find \(metadatas.count) items")
                    }

                    for metadata in metadatas {

                        // Different account
                        if self.appDelegate.account != metadata.account {
                            NCCommunicationCommon.shared.writeLog("Process auto upload skipped file: \(metadata.serverUrl)/\(metadata.fileNameView) on account: \(metadata.account), because the actual account is \(self.appDelegate.account).")
                            continue
                        }

                        // Is already in upload background? skipped
                        if listOcId.contains(metadata.ocId) {
                            NCCommunicationCommon.shared.writeLog("Process auto upload skipped file: \(metadata.serverUrl)/\(metadata.fileNameView), because is already in session.")
                            continue
                        }

                        // Session Extension ? skipped
                        if metadata.session == NCNetworking.shared.sessionIdentifierBackgroundExtension {
                            continue
                        }

                        // Is already in upload E2EE / CHUNK ? exit [ ONLY ONE IN QUEUE ]
                        for metadata in metadatasUpload {
                            if metadata.chunk || metadata.e2eEncrypted {
                                counterUpload = self.maxConcurrentOperationUpload
                                continue
                            }
                        }

                        let (metadataForUpload, metadataLivePhotoForUpload) = self.extractMetadataFileLive(metadata: metadata, queue: queue)

                        // Upload
                        if let metadata = metadataForUpload {
                            if (metadata.e2eEncrypted || metadata.chunk) && UIApplication.shared.applicationState != .active { continue }
                            if let metadata = NCManageDatabase.shared.setMetadataStatus(ocId: metadata.ocId, status: NCGlobal.shared.metadataStatusInUpload) {
                                NCNetworking.shared.upload(metadata: metadata) {
                                } completion: { _, _ in }
                            }
                            if metadata.e2eEncrypted || metadata.chunk {
                                counterUpload = self.maxConcurrentOperationUpload
                            } else {
                                counterUpload += 1
                            }
                        }

                        // Upload Live photo
                        if let metadata = metadataLivePhotoForUpload {
                            if (metadata.e2eEncrypted || metadata.chunk) && UIApplication.shared.applicationState != .active { continue }
                            if let metadata = NCManageDatabase.shared.setMetadataStatus(ocId: metadata.ocId, status: NCGlobal.shared.metadataStatusInUpload) {
                                NCNetworking.shared.upload(metadata: metadata) {
                                } completion: { _, _ in }
                            }
                            if metadata.e2eEncrypted || metadata.chunk {
                                counterUpload = self.maxConcurrentOperationUpload
                            } else {
                                counterUpload += 1
                            }
                        }
                    }
                }
            }

            // No upload available ? --> Retry Upload in Error
            if counterUpload == 0 {
                let metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "status == %d", NCGlobal.shared.metadataStatusUploadError))
                for metadata in metadatas {
                    NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: NCNetworking.shared.sessionIdentifierBackground, sessionError: "", sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusWaitUpload)
                }
            }
             
            // verify delete Asset Local Identifiers in auto upload (DELETE Photos album)
            DispatchQueue.main.async {
                if (counterUpload == 0 && !self.appDelegate.isPasscodePresented()) {
                    self.deleteAssetLocalIdentifiers(account: self.appDelegate.account) {
                        self.startTimer()
                    }
                } else {
                    self.startTimer()
                }
            }
        })
    }

    private func deleteAssetLocalIdentifiers(account: String, completition: @escaping () -> Void) {

        if UIApplication.shared.applicationState != .active {
            completition()
            return
        }
        let metadatasSessionUpload = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND session CONTAINS[cd] %@", account, "upload"))
        if !metadatasSessionUpload.isEmpty {
            completition()
            return
        }
        let localIdentifiers = NCManageDatabase.shared.getAssetLocalIdentifiersUploaded(account: account)
        if localIdentifiers.isEmpty {
            completition()
            return
        }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }, completionHandler: { _, _ in
            DispatchQueue.main.async {
                NCManageDatabase.shared.clearAssetLocalIdentifiers(localIdentifiers, account: account)
                completition()
            }
        })
    }

    // MARK: -

    func extractMetadataFileLive(metadata: tableMetadata, queue: DispatchQueue) -> (metadataForUpload: tableMetadata?, metadataLivePhotoForUpload: tableMetadata?) {

        var metadataForUpload: tableMetadata?
        var metadataLivePhotoForUpload: tableMetadata?
        let chunckSize = CCUtility.getChunkSize() * 1000000
        let semaphore = Semaphore()

        guard queue != .main else { return(nil, nil) }
        guard !metadata.assetLocalIdentifier.isEmpty else {
            let filePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)!
            metadata.size = NCUtilityFileSystem.shared.getFileSize(filePath: filePath)
            let results = NCCommunicationCommon.shared.getInternalType(fileName: metadata.fileNameView, mimeType: metadata.contentType, directory: false)
            metadata.contentType = results.mimeType
            metadata.iconName = results.iconName
            metadata.classFile = results.classFile
            if let date = NCUtilityFileSystem.shared.getFileCreationDate(filePath: filePath) { metadata.creationDate = date }
            if let date =  NCUtilityFileSystem.shared.getFileModificationDate(filePath: filePath) { metadata.date = date }
            // DETECT IF CHUNCK
            if chunckSize > 0 && metadata.size > chunckSize {
                metadata.chunk = true
                metadata.session = NCCommunicationCommon.shared.sessionIdentifierUpload
            }
            // DETECT IF E2EE
            if CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account, urlBase: metadata.urlBase) {
                metadata.e2eEncrypted = true
            }
            let metadata = NCManageDatabase.shared.addMetadata(metadata)
            return (metadata, nil)
        }

        CCUtility.extractImageVideoFromAssetLocalIdentifier(forUpload: metadata, queue: queue) { extractMetadata, fileNamePath in
            if let metadata = extractMetadata {
                let toPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
                NCUtilityFileSystem.shared.moveFile(atPath: fileNamePath!, toPath: toPath)
                metadata.size = NCUtilityFileSystem.shared.getFileSize(filePath: toPath)
                // DETECT IF CHUNCK
                if chunckSize > 0 && metadata.size > chunckSize {
                    metadata.chunk = true
                    metadata.session = NCCommunicationCommon.shared.sessionIdentifierUpload
                }
                // DETECT IF E2EE
                if CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account, urlBase: metadata.urlBase) {
                    metadata.e2eEncrypted = true
                }
                // update
                metadataForUpload = NCManageDatabase.shared.addMetadata(metadata)
            }
            semaphore.continue()
        }
        semaphore.wait()

        if metadataForUpload == nil {
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            return (nil, nil)
        }

        let fetchAssets = PHAsset.fetchAssets(withLocalIdentifiers: [metadata.assetLocalIdentifier], options: nil)
        if metadata.livePhoto, fetchAssets.count > 0  {
            let ocId = NSUUID().uuidString
            let fileName = (metadata.fileName as NSString).deletingPathExtension + ".mov"
            let filePath = CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileName)!
            CCUtility.extractLivePhotoAsset(fetchAssets.firstObject, filePath: filePath, queue: queue) { url in
                if url != nil {
                    let metadataLivePhoto = NCManageDatabase.shared.createMetadata(account: metadata.account, user: metadata.user, userId: metadata.userId, fileName: fileName, fileNameView: fileName, ocId: ocId, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, url: "", contentType: "", isLivePhoto: true)
                    metadataLivePhoto.classFile = NCCommunicationCommon.typeClassFile.video.rawValue
                    metadataLivePhoto.e2eEncrypted = metadata.e2eEncrypted
                    metadataLivePhoto.isAutoupload = metadata.isAutoupload
                    metadataLivePhoto.session = metadata.session
                    metadataLivePhoto.sessionSelector = metadata.sessionSelector
                    metadataLivePhoto.size = NCUtilityFileSystem.shared.getFileSize(filePath: filePath)
                    metadataLivePhoto.status = metadata.status
                    if chunckSize > 0 && metadataLivePhoto.size > chunckSize {
                        metadataLivePhoto.chunk = true
                        metadataLivePhoto.session = NCCommunicationCommon.shared.sessionIdentifierUpload
                    }
                    metadataLivePhotoForUpload = NCManageDatabase.shared.addMetadata(metadataLivePhoto)
                }
                semaphore.continue()
            }
            semaphore.wait()
        }

        return(metadataForUpload, metadataLivePhotoForUpload)
    }

    // MARK: -

    @objc func createProcessUploads(metadatas: [tableMetadata], verifyAlreadyExists: Bool = false) {

        var metadatasForUpload: [tableMetadata] = []
        for metadata in metadatas {
            if verifyAlreadyExists {
                if NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ && serverUrl == %@ && fileName == %@ && session != ''", metadata.account, metadata.serverUrl, metadata.fileName)) != nil {
                    continue
                }
            }
            metadatasForUpload.append(metadata)
        }
        NCManageDatabase.shared.addMetadatas(metadatasForUpload)
        startProcess()
    }

    // MARK: -

    @objc func verifyUploadZombie() {

        var session: URLSession?

        // remove leaning upload share extension
        let metadatasUploadShareExtension = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "session == %@ AND sessionSelector == %@", NCCommunicationCommon.shared.sessionIdentifierUpload, NCGlobal.shared.selectorUploadFileShareExtension))
        for metadata in metadatasUploadShareExtension {
            let path = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId)!
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NCManageDatabase.shared.deleteChunks(account: metadata.account, ocId: metadata.ocId)
            NCUtilityFileSystem.shared.deleteFile(filePath: path)
        }
        
        // verify metadataStatusInUpload (BACKGROUND)
        let metadatasInUploadBackground = NCManageDatabase.shared.getMetadatas(
            predicate: NSPredicate(
                format: "(session == %@ OR session == %@ OR session == %@) AND status == %d AND sessionTaskIdentifier == 0",
                NCNetworking.shared.sessionIdentifierBackground,
                NCNetworking.shared.sessionIdentifierBackgroundExtension,
                NCNetworking.shared.sessionIdentifierBackgroundWWan,
                NCGlobal.shared.metadataStatusInUpload))
        for metadata in metadatasInUploadBackground {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "ocId == %@ AND status == %d AND sessionTaskIdentifier == 0", metadata.ocId, NCGlobal.shared.metadataStatusInUpload)) {
                    NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: NCNetworking.shared.sessionIdentifierBackground, sessionError: "", sessionSelector: nil, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusWaitUpload)
                }
            }
        }

        // metadataStatusUploading (BACKGROUND)
        let metadatasUploadingBackground = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "(session == %@ OR session == %@ OR session == %@) AND status == %d", NCNetworking.shared.sessionIdentifierBackground, NCNetworking.shared.sessionIdentifierBackgroundWWan, NCNetworking.shared.sessionIdentifierBackgroundExtension, NCGlobal.shared.metadataStatusUploading))
        for metadata in metadatasUploadingBackground {

            if metadata.session == NCNetworking.shared.sessionIdentifierBackground {
                session = NCNetworking.shared.sessionManagerBackground
            } else if metadata.session == NCNetworking.shared.sessionIdentifierBackgroundWWan {
                session = NCNetworking.shared.sessionManagerBackgroundWWan
            }

            var taskUpload: URLSessionTask?

            session?.getAllTasks(completionHandler: { tasks in
                for task in tasks {
                    if task.taskIdentifier == metadata.sessionTaskIdentifier {
                        taskUpload = task
                    }
                }

                if taskUpload == nil {
                    if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "ocId == %@ AND status == %d", metadata.ocId, NCGlobal.shared.metadataStatusUploading)) {
                        NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: NCNetworking.shared.sessionIdentifierBackground, sessionError: "", sessionSelector: nil, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusWaitUpload)
                    }
                }
            })
        }

        // metadataStatusUploading OR metadataStatusInUpload (FOREGROUND)
        let metadatasUploading = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "session == %@ AND (status == %d OR status == %d)", NCCommunicationCommon.shared.sessionIdentifierUpload, NCGlobal.shared.metadataStatusUploading, NCGlobal.shared.metadataStatusInUpload))
        for metadata in metadatasUploading {
            let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
            if NCNetworking.shared.uploadRequest[fileNameLocalPath] == nil {
                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: "", sessionSelector: nil, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusWaitUpload)
            }
        }
    }
}
