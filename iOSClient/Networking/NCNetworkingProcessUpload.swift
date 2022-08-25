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

    var timerProcess: Timer?

    let maxConcurrentOperationUpload = 5

    override init() {
        super.init()
        startTimer()
    }

    private func startProcess() {
        if timerProcess?.isValid ?? false {
            DispatchQueue.main.async { self.process() }
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
        guard let account = NCManageDatabase.shared.getActiveAccount() else {
            return
        }

        stopTimer()

        var counterUpload: Int = 0
        let sessionSelectors = [NCGlobal.shared.selectorUploadFileNODelete, NCGlobal.shared.selectorUploadFile, NCGlobal.shared.selectorUploadAutoUpload, NCGlobal.shared.selectorUploadAutoUploadAll]
        let metadatasUpload = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "status == %d OR status == %d", NCGlobal.shared.metadataStatusInUpload, NCGlobal.shared.metadataStatusUploading))
        counterUpload = metadatasUpload.count

        print("[LOG] PROCESS-UPLOAD \(counterUpload)")

        // Update Badge
        let counterBadge = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "status == %d OR status == %d OR status == %d", NCGlobal.shared.metadataStatusWaitUpload, NCGlobal.shared.metadataStatusInUpload, NCGlobal.shared.metadataStatusUploading))
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUpdateBadgeNumber, userInfo: ["counter":counterBadge.count])

        NCNetworking.shared.getOcIdInBackgroundSession(queue: DispatchQueue.global(qos: .background), completion: { listOcId in

            for sessionSelector in sessionSelectors {
                if counterUpload < self.maxConcurrentOperationUpload {

                    let limit = self.maxConcurrentOperationUpload - counterUpload
                    let metadatas = NCManageDatabase.shared.getAdvancedMetadatas(predicate: NSPredicate(format: "sessionSelector == %@ AND status == %d", sessionSelector, NCGlobal.shared.metadataStatusWaitUpload), page: 1, limit: limit, sorted: "date", ascending: true)
                    if metadatas.count > 0 {
                        NCCommunicationCommon.shared.writeLog("PROCESS-UPLOAD find \(metadatas.count) items")
                    }

                    for metadata in metadatas {

                        // Different account
                        if account.account != metadata.account {
                            NCCommunicationCommon.shared.writeLog("Process auto upload skipped file: \(metadata.serverUrl)/\(metadata.fileNameView) on account: \(metadata.account), because the actual account is \(account.account).")
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

                        let semaphore = Semaphore()
                        self.extractFiles(from: metadata) { metadatas in
                            if metadatas.isEmpty {
                                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                            }
                            for metadata in metadatas {
                                #if !EXTENSION
                                if (metadata.e2eEncrypted || metadata.chunk) && UIApplication.shared.applicationState != .active {  continue }
                                #else
                                if (metadata.e2eEncrypted || metadata.chunk) { continue }
                                #endif
                                let isWiFi = NCNetworking.shared.networkReachability == NCCommunicationCommon.typeReachability.reachableEthernetOrWiFi
                                if metadata.session == NCNetworking.shared.sessionIdentifierBackgroundWWan && !isWiFi { continue }
                                if let metadata = NCManageDatabase.shared.setMetadataStatus(ocId: metadata.ocId, status: NCGlobal.shared.metadataStatusInUpload) {
                                    NCNetworking.shared.upload(metadata: metadata)
                                }
                                if metadata.e2eEncrypted || metadata.chunk {
                                    counterUpload = self.maxConcurrentOperationUpload
                                } else {
                                    counterUpload += 1
                                }
                            }
                            semaphore.continue()
                        }
                        semaphore.wait()
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
            #if !EXTENSION
            DispatchQueue.main.async {
                if (counterUpload == 0 && !(UIApplication.shared.delegate as! AppDelegate).isPasscodePresented()) {
                    self.deleteAssetLocalIdentifiers(account: account.account) {
                        self.startTimer()
                    }
                } else {
                    self.startTimer()
                }
            }
            #endif
        })
    }

    #if !EXTENSION
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
    #endif

    // MARK: -

    func extractFiles(from metadata: tableMetadata, completition: @escaping (_ metadatas: [tableMetadata]) -> Void) {

        let chunckSize = CCUtility.getChunkSize() * 1000000
        var metadatas: [tableMetadata] = []
        let metadataSource = tableMetadata.init(value: metadata)

        guard !metadata.isExtractFile else { return  completition([metadataSource]) }
        guard !metadataSource.assetLocalIdentifier.isEmpty else {
            let filePath = CCUtility.getDirectoryProviderStorageOcId(metadataSource.ocId, fileNameView: metadataSource.fileName)!
            metadataSource.size = NCUtilityFileSystem.shared.getFileSize(filePath: filePath)
            let results = NCCommunicationCommon.shared.getInternalType(fileName: metadataSource.fileNameView, mimeType: metadataSource.contentType, directory: false)
            metadataSource.contentType = results.mimeType
            metadataSource.iconName = results.iconName
            metadataSource.classFile = results.classFile
            if let date = NCUtilityFileSystem.shared.getFileCreationDate(filePath: filePath) { metadataSource.creationDate = date }
            if let date =  NCUtilityFileSystem.shared.getFileModificationDate(filePath: filePath) { metadataSource.date = date }
            metadataSource.chunk = chunckSize != 0 && metadata.size > chunckSize
            metadataSource.e2eEncrypted = CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account, urlBase: metadata.urlBase)
            metadataSource.isExtractFile = true
            if let metadata = NCManageDatabase.shared.addMetadata(metadataSource) {
                metadatas.append(metadata)
            }
            return completition(metadatas)
        }

        NCUtility.shared.extractImageVideoFromAssetLocalIdentifier(metadata: metadataSource, modifyMetadataForUpload: true) { metadata, fileNamePath, returnError in
            if let metadata = metadata, let fileNamePath = fileNamePath, !returnError {
                metadatas.append(metadata)
                let toPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
                NCUtilityFileSystem.shared.moveFile(atPath: fileNamePath, toPath: toPath)
            } else {
                return completition(metadatas)
            }
            let fetchAssets = PHAsset.fetchAssets(withLocalIdentifiers: [metadataSource.assetLocalIdentifier], options: nil)
            if metadataSource.livePhoto, fetchAssets.count > 0  {
                NCUtility.shared.createMetadataLivePhotoFromMetadata(metadataSource, asset: fetchAssets.firstObject) { metadata in
                    if let metadata = metadata, let metadata = NCManageDatabase.shared.addMetadata(metadata) {
                        metadatas.append(metadata)
                    }
                    completition(metadatas)
                }
            } else {
                completition(metadatas)
            }
        }
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

        // download
        let metadatasDownload = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "session == %@", NCCommunicationCommon.shared.sessionIdentifierDownload))
        for metadata in metadatasDownload {
            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: "", sessionError: "", sessionSelector: "", sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusNormal)
        }
    }
}
