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
import NextcloudKit
import Photos
import JGProgressHUD
import RealmSwift

class NCNetworkingProcessUpload: NSObject {
    public static let shared: NCNetworkingProcessUpload = {
        let instance = NCNetworkingProcessUpload()
        return instance
    }()

    private let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    private lazy var rootViewController = appDelegate.window?.rootViewController
    private lazy var hudView = rootViewController?.view
    private var notificationToken: NotificationToken?
    private var timerProcess: Timer?
    private var pauseProcess: Bool = false
    private var hud: JGProgressHUD?

    func observeTableMetadata() {
        do {
            let realm = try Realm()
            let results = realm.objects(tableMetadata.self).filter("session != '' || sessionError != ''")
            notificationToken = results.observe { [weak self] (changes: RealmCollectionChange) in
                switch changes {
                case .initial:
                    print("Initial")
                case .update(_, let deletions, let insertions, let modifications):
                    if !deletions.isEmpty || !insertions.isEmpty || !modifications.isEmpty {
                        self?.invalidateObserveTableMetadata()
                        self?.start(completition: { items in
                            print("[LOG] PROCESS-UPLOAD-OBSERVE \(items)")
                            DispatchQueue.main.async {
                                self?.observeTableMetadata()
                            }
                        })
                    }
                case .error(let error):
                    NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to TableMetadata: \(error)")
                }
            }
        } catch let error as NSError {
            NSLog("Could not access database: ", error)
        }
    }

    func invalidateObserveTableMetadata() {
        notificationToken?.invalidate()
        notificationToken = nil
    }

    func startTimer() {
        DispatchQueue.main.async {
            self.timerProcess?.invalidate()
            self.timerProcess = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.processTimer), userInfo: nil, repeats: true)
        }
    }

    func stopTimer() {
        DispatchQueue.main.async {
            self.timerProcess?.invalidate()
        }
    }

    @objc private func processTimer() {
        start { items in
            print("[LOG] PROCESS-UPLOAD-TIMER \(items)")
        }
    }

    func start(completition: @escaping (_ items: Int) -> Void) {

        if appDelegate.account.isEmpty || pauseProcess {
            return completition(0)
        } else {
            pauseProcess = true
        }

        let applicationState = UIApplication.shared.applicationState
        let queue = DispatchQueue.global()
        var maxConcurrentOperationUpload = NCBrandOptions.shared.maxConcurrentOperationUpload

        if applicationState == .active {
            hud = JGProgressHUD()
        }

        queue.async {

            let metadatasUpload = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND status == %d", self.appDelegate.account, NCGlobal.shared.metadataStatusUploading))
            let isWiFi = NCNetworking.shared.networkReachability == NKCommon.TypeReachability.reachableEthernetOrWiFi
            var counterUpload = metadatasUpload.count
            let sessionSelectors = [NCGlobal.shared.selectorUploadFileNODelete, NCGlobal.shared.selectorUploadFile, NCGlobal.shared.selectorUploadAutoUpload, NCGlobal.shared.selectorUploadAutoUploadAll]

            // ** TEST ONLY ONE **
            // E2EE
            let uniqueMetadatas = metadatasUpload.unique(map: { $0.serverUrl })
            for metadata in uniqueMetadatas {
                if metadata.isDirectoryE2EE {
                    self.pauseProcess = false
                    return completition(counterUpload)
                }
            }
            // CHUNK
            if !metadatasUpload.filter({ $0.chunk > 0 }).isEmpty {
                self.pauseProcess = false
                return completition(counterUpload)
            }

            NCNetworking.shared.getOcIdInBackgroundSession(queue: queue, completion: { listOcId in

                for sessionSelector in sessionSelectors where counterUpload < maxConcurrentOperationUpload {

                    let limit = maxConcurrentOperationUpload - counterUpload
                    let metadatas = NCManageDatabase.shared.getAdvancedMetadatas(predicate: NSPredicate(format: "account == %@ AND sessionSelector == %@ AND status == %d", self.appDelegate.account, sessionSelector, NCGlobal.shared.metadataStatusWaitUpload), page: 1, limit: limit, sorted: "date", ascending: true)
                    if !metadatas.isEmpty {
                        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] PROCESS-UPLOAD find \(metadatas.count) items")
                    }

                    for metadata in metadatas where counterUpload < maxConcurrentOperationUpload {

                        // Is already in upload background? skipped
                        if listOcId.contains(metadata.ocId) {
                            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Process auto upload skipped file: \(metadata.serverUrl)/\(metadata.fileNameView), because is already in session.")
                            continue
                        }

                        // Session Extension ? skipped
                        if metadata.session == NCNetworking.shared.sessionUploadBackgroundExtension {
                            continue
                        }

                        let semaphore = DispatchSemaphore(value: 0)
                        let cameraRoll = NCCameraRoll()
                        cameraRoll.extractCameraRoll(from: metadata) { metadatas in
                            if metadatas.isEmpty {
                                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                            }
                            for metadata in metadatas where counterUpload < maxConcurrentOperationUpload {

                                // isE2EE
                                let isInDirectoryE2EE = metadata.isDirectoryE2EE

                                // NO WiFi
                                if !isWiFi && metadata.session == NCNetworking.shared.sessionUploadBackgroundWWan {
                                    continue
                                }

                                if applicationState != .active && (isInDirectoryE2EE || metadata.chunk > 0) {
                                    continue
                                }

                                if let metadata = NCManageDatabase.shared.setMetadataStatus(ocId: metadata.ocId, status: NCGlobal.shared.metadataStatusUploading) {
                                    NCNetworking.shared.upload(metadata: metadata, hudView: self.hudView, hud: self.hud)
                                    if isInDirectoryE2EE || metadata.chunk > 0 {
                                        maxConcurrentOperationUpload = 1
                                    }
                                    counterUpload += 1
                                }
                            }
                            semaphore.signal()
                        }
                        semaphore.wait()
                    }
                }

                // No upload available ? --> Retry Upload in Error
                if counterUpload == 0 {
                    let metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND status == %d", self.appDelegate.account, NCGlobal.shared.metadataStatusUploadError))
                    for metadata in metadatas {
                        // Verify QUOTA
                        if metadata.sessionError.contains("\(NCGlobal.shared.errorQuota)") {
                            NextcloudKit.shared.getUserProfile { _, userProfile, _, error in
                                if error == .success, let userProfile, userProfile.quotaFree > 0, userProfile.quotaFree > metadata.size {
                                    NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                                               session: NCNetworking.shared.sessionUploadBackground,
                                                                               sessionError: "",
                                                                               taskIdentifier: 0,
                                                                               status: NCGlobal.shared.metadataStatusWaitUpload)
                                }
                            }
                        } else {
                            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                                       session: NCNetworking.shared.sessionUploadBackground,
                                                                       sessionError: "",
                                                                       taskIdentifier: 0,
                                                                       status: NCGlobal.shared.metadataStatusWaitUpload)
                        }
                    }

                    // verify delete Asset Local Identifiers in auto upload (DELETE Photos album)
                    if applicationState == .active && metadatas.isEmpty {
                        self.deleteAssetLocalIdentifiers(account: self.appDelegate.account) {
                            self.pauseProcess = false
                        }
                    } else {
                        self.pauseProcess = false
                    }
                } else {
                    self.pauseProcess = false
                }

                completition(counterUpload)
            })
        }
    }

    private func deleteAssetLocalIdentifiers(account: String, completition: @escaping () -> Void) {

        DispatchQueue.main.async {

            guard !self.appDelegate.isPasscodePresented else {
                return completition()
            }

            let metadatasSessionUpload = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND session CONTAINS[cd] %@", account, "upload"))
            if !metadatasSessionUpload.isEmpty { return completition() }

            let localIdentifiers = NCManageDatabase.shared.getAssetLocalIdentifiersUploaded(account: account)
            if localIdentifiers.isEmpty { return completition() }

            let assets = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)

            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
            }, completionHandler: { _, _ in
                NCManageDatabase.shared.clearAssetLocalIdentifiers(localIdentifiers, account: self.appDelegate.account)
                completition()
            })
        }
    }

    // MARK: -

    func createProcessUploads(metadatas: [tableMetadata], verifyAlreadyExists: Bool = false, completion: @escaping (_ items: Int) -> Void) {

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
        completion(metadatasForUpload.count)
    }

    // MARK: -

    func verifyUploadZombie() {

        let utilityFileSystem = NCUtilityFileSystem()

        // selectorUploadFileShareExtension (FOREGROUND)
        if let results = NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "session == %@ AND sessionSelector == %@", NextcloudKit.shared.nkCommonInstance.sessionIdentifierUpload, NCGlobal.shared.selectorUploadFileShareExtension)) {
            for metadata in results {
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
            }
        }

        // metadataStatusUploading (FOREGROUND)
        if let results = NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "session == %@ AND status == %d", NextcloudKit.shared.nkCommonInstance.sessionIdentifierUpload, NCGlobal.shared.metadataStatusUploading)) {
            if results.isEmpty { NCNetworking.shared.transferInForegorund = nil }
            for metadata in results {
                let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)
                if NCNetworking.shared.uploadRequest[fileNameLocalPath] == nil {
                    NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                               sessionError: "",
                                                               taskIdentifier: 0,
                                                               status: NCGlobal.shared.metadataStatusWaitUpload)
                }
            }
        }

        // metadataStatusDownloading (FOREGROUND)
        if let results = NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "session == %@ AND status == %d", NextcloudKit.shared.nkCommonInstance.sessionIdentifierDownload, NCGlobal.shared.metadataStatusDownloading)) {
            for metadata in results {
                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                           session: "",
                                                           sessionError: "",
                                                           selector: "",
                                                           taskIdentifier: 0,
                                                           status: NCGlobal.shared.metadataStatusNormal,
                                                           errorCode: 0)
            }
        }

        // metadataStatusUploading (BACKGROUND)
        if let results = NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "(session == %@ OR session == %@ OR session == %@) AND status == %d", NCNetworking.shared.sessionUploadBackground, NCNetworking.shared.sessionUploadBackgroundWWan, NCNetworking.shared.sessionUploadBackgroundExtension, NCGlobal.shared.metadataStatusUploading)) {
            for metadata in results {
                var taskUpload: URLSessionTask?
                var session: URLSession?
                let sessionTaskIdentifier = metadata.sessionTaskIdentifier
                let ocId = metadata.ocId
                if metadata.session == NCNetworking.shared.sessionUploadBackground {
                    session = NCNetworking.shared.sessionManagerUploadBackground
                } else if metadata.session == NCNetworking.shared.sessionUploadBackgroundWWan {
                    session = NCNetworking.shared.sessionManagerUploadBackgroundWWan
                }

                session?.getAllTasks(completionHandler: { tasks in
                    for task in tasks {
                        if task.taskIdentifier == sessionTaskIdentifier {
                            taskUpload = task
                        }
                    }
                    if taskUpload == nil, let metadata = NCManageDatabase.shared.getResultMetadata(predicate: NSPredicate(format: "ocId == %@ AND status == %d", ocId, NCGlobal.shared.metadataStatusUploading)) {
                        NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                                   session: NCNetworking.shared.sessionUploadBackground,
                                                                   sessionError: "",
                                                                   taskIdentifier: 0,
                                                                   status: NCGlobal.shared.metadataStatusWaitUpload)
                    }
                })
            }
        }
    }
}
