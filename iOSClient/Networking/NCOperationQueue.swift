//
//  NCOperationQueue.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 03/06/2020.
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
import Queuer
import NCCommunication

@objc class NCOperationQueue: NSObject {
    @objc public static let shared: NCOperationQueue = {
        let instance = NCOperationQueue()
        return instance
    }()
    
    private var downloadQueue = Queuer(name: "downloadQueue", maxConcurrentOperationCount: 5, qualityOfService: .default)
    private let deleteQueue = Queuer(name: "deleteQueue", maxConcurrentOperationCount: 1, qualityOfService: .default)
    private let copyMoveQueue = Queuer(name: "copyMoveQueue", maxConcurrentOperationCount: 1, qualityOfService: .default)
    private let synchronizationQueue = Queuer(name: "synchronizationQueue", maxConcurrentOperationCount: 1, qualityOfService: .default)
    private let downloadThumbnailQueue = Queuer(name: "downloadThumbnailQueue", maxConcurrentOperationCount: 10, qualityOfService: .default)
    private let readFileForMediaQueue = Queuer(name: "readFileForMediaQueue", maxConcurrentOperationCount: 10, qualityOfService: .default)
   
    private var timerReadFileForMediaQueue: Timer?

    @objc func cancelAllQueue() {
        downloadCancelAll()
        deleteCancelAll()
        copyMoveCancelAll()
        synchronizationCancelAll()
        downloadThumbnailCancelAll()
        readFileForMediaCancelAll()
    }
    
    // Download file
    
    @objc func download(metadata: tableMetadata, selector: String, setFavorite: Bool) {
        for operation in downloadQueue.operations as! [NCOperationDownload]  {
            if operation.metadata.ocId == metadata.ocId {
                return
            }
        }
        downloadQueue.addOperation(NCOperationDownload.init(metadata: metadata, selector: selector, setFavorite: setFavorite))
    }
    @objc func downloadCancelAll() {
        downloadQueue.cancelAll()
    }
    @objc func downloadCount() -> Int {
        return downloadQueue.operationCount
    }
    
    // Delete file
    
    @objc func delete(metadata: tableMetadata, onlyLocal: Bool) {
        for operation in deleteQueue.operations as! [NCOperationDelete]  {
            if operation.metadata.ocId == metadata.ocId {
                return
            }
        }
        deleteQueue.addOperation(NCOperationDelete.init(metadata: metadata, onlyLocal: onlyLocal))
    }
    @objc func deleteCancelAll() {
        deleteQueue.cancelAll()
    }
    @objc func deleteCount() -> Int {
        return deleteQueue.operationCount
    }
    
    // Copy Move file
    
    @objc func copyMove(metadata: tableMetadata, serverUrl: String, overwrite: Bool, move: Bool) {
        for operation in copyMoveQueue.operations as! [NCOperationCopyMove]  {
            if operation.metadata.ocId == metadata.ocId {
                return
            }
        }
        copyMoveQueue.addOperation(NCOperationCopyMove.init(metadata: metadata, serverUrlTo: serverUrl, overwrite: overwrite, move: move))
    }
    @objc func copyMoveCancelAll() {
        copyMoveQueue.cancelAll()
    }
    @objc func copyMoveCount() -> Int {
        return copyMoveQueue.operationCount
    }
    
    // Synchronization
    
    @objc func synchronizationMetadata(_ metadata: tableMetadata, selector: String) {
        for operation in synchronizationQueue.operations as! [NCOperationSynchronization] {
            if operation.metadata.ocId == metadata.ocId {
                return
            }
        }
        synchronizationQueue.addOperation(NCOperationSynchronization.init(metadata: metadata, selector: selector))
    }
    @objc func synchronizationCancelAll() {
        synchronizationQueue.cancelAll()
    }
    
    // Download Thumbnail
    
    @objc func downloadThumbnail(metadata: tableMetadata, urlBase: String, view: Any, indexPath: IndexPath) {
        if metadata.hasPreview && metadata.status == k_metadataStatusNormal && (!CCUtility.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag)) {
            for operation in downloadThumbnailQueue.operations as! [NCOperationDownloadThumbnail] {
                if operation.metadata.ocId == metadata.ocId {
                    return
                }
            }
            downloadThumbnailQueue.addOperation(NCOperationDownloadThumbnail.init(metadata: metadata, urlBase: urlBase, view: view, indexPath: indexPath))
        }
    }
    
    func cancelDownloadThumbnail(metadata: tableMetadata) {
        for operation in  downloadThumbnailQueue.operations as! [NCOperationDownloadThumbnail] {
            if operation.metadata.ocId == metadata.ocId {
                operation.cancel()
            }
        }
    }
    
    @objc func downloadThumbnailCancelAll() {
        downloadThumbnailQueue.cancelAll()
    }
    
    // Get file information
    
    @objc func readFileForMedia(metadata: tableMetadata) {
        for operation in readFileForMediaQueue.operations as! [NCOperationReadFileForMediaQueue] {
            if operation.metadata.ocId == metadata.ocId {
                return
            }
        }
        readFileForMediaQueue.addOperation(NCOperationReadFileForMediaQueue.init(metadata: metadata))
    }
    
    func cancelReadFileForMedia(metadata: tableMetadata) {
        for operation in  readFileForMediaQueue.operations as! [NCOperationReadFileForMediaQueue] {
            if operation.metadata.ocId == metadata.ocId {
                operation.cancel()
            }
        }
    }
    
    @objc func readFileForMediaCancelAll() {
        readFileForMediaQueue.cancelAll()
    }
    
    @objc func notificationReloadDataSourceMedia() {
        NotificationCenter.default.postOnMainThread(name: k_notificationCenter_reloadMediaDataSource)
    }
    
    func reloadDataSourceMedia() {
        if !(timerReadFileForMediaQueue?.isValid ?? false) {
            timerReadFileForMediaQueue = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(notificationReloadDataSourceMedia), userInfo: nil, repeats: false)
        }
    }
}

//MARK: -

class NCOperationDownload: ConcurrentOperation {
   
    var metadata: tableMetadata
    var selector: String
    var setFavorite: Bool
    
    init(metadata: tableMetadata, selector: String, setFavorite: Bool) {
        self.metadata = tableMetadata.init(value: metadata)
        self.selector = selector
        self.setFavorite = setFavorite
    }
    
    override func start() {
        if isCancelled {
            self.finish()
        } else {
            NCNetworking.shared.download(metadata: metadata, selector: self.selector, setFavorite: self.setFavorite) { (_) in
                self.finish()
            }
        }
    }
}

//MARK: -

class NCOperationDelete: ConcurrentOperation {
   
    var metadata: tableMetadata
    var onlyLocal: Bool
    
    init(metadata: tableMetadata, onlyLocal: Bool) {
        self.metadata = tableMetadata.init(value: metadata)
        self.onlyLocal = onlyLocal
    }
    
    override func start() {
        if isCancelled {
            self.finish()
        } else {
            NCNetworking.shared.deleteMetadata(metadata, account: metadata.account, urlBase: metadata.urlBase, onlyLocal: onlyLocal) { (errorCode, errorDescription) in
                if errorCode != 0 {
                    NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                }
                self.finish()
            }
        }
    }
}

//MARK: -

class NCOperationCopyMove: ConcurrentOperation {
   
    var metadata: tableMetadata
    var serverUrlTo: String
    var overwrite: Bool
    var move: Bool

    init(metadata: tableMetadata, serverUrlTo: String, overwrite: Bool, move: Bool) {
        self.metadata = tableMetadata.init(value: metadata)
        self.serverUrlTo = serverUrlTo
        self.overwrite = overwrite
        self.move = move
    }
    
    override func start() {
        if isCancelled {
            self.finish()
        } else {
            if move {
                NCNetworking.shared.moveMetadata(metadata, serverUrlTo: serverUrlTo, overwrite: overwrite) { (errorCode, errorDescription) in
                    if errorCode != 0 {
                        NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                    }
                    self.finish()
                }
            } else {
                NCNetworking.shared.copyMetadata(metadata, serverUrlTo: serverUrlTo, overwrite: overwrite) { (errorCode, errorDescription) in
                    if errorCode != 0 {
                        NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                    }
                    self.finish()
                }
            }
        }
    }
}

//MARK: -

class NCOperationSynchronization: ConcurrentOperation {
   
    var metadata: tableMetadata
    var selector: String
    var download: Bool
    
    init(metadata: tableMetadata, selector: String) {
        self.metadata = tableMetadata.init(value: metadata)
        self.selector = selector
        if selector == selectorDownloadFile {
            self.download = true
        } else {
            self.download = false
        }
    }
    
    override func start() {
        if isCancelled {
            self.finish()
        } else {
            if metadata.directory {
                
                let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
                
                NCCommunication.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "1", showHiddenFiles: CCUtility.getShowHiddenFiles()) { (account, files, responseData, errorCode, errorDescription) in
                    
                    if errorCode == 0 {
                    
                        NCManageDatabase.sharedInstance.convertNCCommunicationFilesToMetadatas(files, useMetadataFolder: true, account: account) { (metadataFolder, metadatasFolder, metadatas) in
                            
                            let metadatasResult = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND status == %d", account, serverUrlFileName, k_metadataStatusNormal))
                            
                            if self.selector == selectorDownloadAllFile {
                                
                                NCManageDatabase.sharedInstance.updateMetadatas(metadatas, metadatasResult: metadatasResult)

                                for metadata in metadatas {
                                    if metadata.directory {
                                        NCOperationQueue.shared.synchronizationMetadata(metadata, selector: self.selector)
                                    } else {
                                        let localFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                                        if localFile == nil || localFile?.etag != metadata.etag {
                                            NCOperationQueue.shared.download(metadata: metadata, selector: self.selector, setFavorite: false)
                                        }
                                    }
                                }
                                
                            } else {
                            
                                let metadatasChanged = NCManageDatabase.sharedInstance.updateMetadatas(metadatas, metadatasResult: metadatasResult, addExistsInLocal: self.download, addCompareEtagLocal: true)

                                for metadata in metadatasChanged.metadatasUpdate {
                                    if metadata.directory {
                                        NCOperationQueue.shared.synchronizationMetadata(metadata, selector: self.selector)
                                    }
                                }
                                
                                for metadata in metadatasChanged.metadatasLocalUpdate {
                                    NCOperationQueue.shared.download(metadata: metadata, selector: self.selector, setFavorite: false)
                                }
                            }
                            // Update etag directory
                            NCManageDatabase.sharedInstance.addDirectory(encrypted: metadataFolder.e2eEncrypted, favorite: metadataFolder.favorite, ocId: metadataFolder.ocId, fileId: metadataFolder.fileId, etag: metadataFolder.etag, permissions: metadataFolder.permissions, serverUrl: serverUrlFileName, richWorkspace: metadataFolder.richWorkspace, creationDate: metadataFolder.creationDate, account: metadataFolder.account)
                        }
                    
                    } else if errorCode == 404 && self.metadata.directory {
                        NCManageDatabase.sharedInstance.deleteDirectoryAndSubDirectory(serverUrl: self.metadata.serverUrl, account: self.metadata.account)
                    }
                    self.finish()
                }
            } else {
                if self.download {
                    let localFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                    if localFile == nil || localFile?.etag != metadata.etag {
                        NCOperationQueue.shared.download(metadata: metadata, selector: self.selector, setFavorite: false)
                    }
                }
                self.finish()
            }
        }
    }
}

//MARK: -

class NCOperationDownloadThumbnail: ConcurrentOperation {
   
    var metadata: tableMetadata
    var urlBase: String
    var view: Any
    var indexPath: IndexPath
    
    init(metadata: tableMetadata, urlBase: String, view: Any, indexPath: IndexPath) {
        self.metadata = tableMetadata.init(value: metadata)
        self.urlBase = urlBase
        self.view = view
        self.indexPath = indexPath
    }
    
    override func start() {

        if isCancelled {
            self.finish()
        } else {
            let fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: urlBase, account: metadata.account)!
            let fileNamePreviewLocalPath = CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)!
            let fileNameIconLocalPath = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)!

            NCCommunication.shared.downloadPreview(fileNamePathOrFileId: fileNamePath, fileNamePreviewLocalPath: fileNamePreviewLocalPath , widthPreview: Int(k_sizePreview), heightPreview: Int(k_sizePreview), fileNameIconLocalPath: fileNameIconLocalPath, sizeIcon: Int(k_sizeIcon)) { (account, imagePreview, imageIcon,  errorCode, errorDescription) in
                
                var cell: NCImageCellProtocol?
                if self.view is UICollectionView && NCMainCommon.shared.isValidIndexPath(self.indexPath, view: self.view) {
                    cell = (self.view as! UICollectionView).cellForItem(at: self.indexPath) as? NCImageCellProtocol
                } else if self.view is UITableView && NCMainCommon.shared.isValidIndexPath(self.indexPath, view: self.view) {
                    cell = (self.view as! UITableView).cellForRow(at: self.indexPath) as? NCImageCellProtocol
                }

                if (cell != nil) {
                    var previewImage: UIImage!
                    if errorCode == 0 && imageIcon != nil {
                        previewImage = imageIcon
                    } else {
                        if self.metadata.iconName.count > 0 {
                            previewImage = UIImage(named: self.metadata.iconName)
                        } else {
                            previewImage = UIImage(named: "file")
                        }
                    }
                    cell!.filePreviewImageView.backgroundColor = nil
                    UIView.transition(with: cell!.filePreviewImageView,
                        duration: 0.75,
                        options: .transitionCrossDissolve,
                        animations: { cell!.filePreviewImageView.image = previewImage! },
                        completion: nil)
                }
                self.finish()
            }
        }
    }
}

//MARK: -

class NCOperationReadFileForMediaQueue: ConcurrentOperation {
   
    var metadata: tableMetadata
    
    init(metadata: tableMetadata) {
        self.metadata = tableMetadata.init(value: metadata)
    }
    
    override func start() {

        if isCancelled {
            self.finish()
        } else {
            let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
            let requestBody =
            """
            <?xml version=\"1.0\" encoding=\"UTF-8\"?>
            <d:propfind xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
            <d:prop>
                <has-preview xmlns=\"http://nextcloud.org/ns\"/>
                <creation_time xmlns=\"http://nextcloud.org/ns\"/>
                <upload_time xmlns=\"http://nextcloud.org/ns\"/>
            </d:prop>
            </d:propfind>
            """
            
            NCCommunication.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", requestBody: requestBody.data(using: .utf8)) { (account, files, responseData, errorCode, errorDescription) in
                if errorCode == 0 && files.count > 0 {
                    let file = files[0]
                    let metadata = tableMetadata.init(value: self.metadata)
                    var modify = false
                    if metadata.hasPreview != file.hasPreview {
                        metadata.hasPreview = file.hasPreview
                        modify = true
                    }
                    if file.creationDate != nil && metadata.creationDate != file.creationDate {
                        metadata.creationDate = file.creationDate!
                        modify = true
                    }
                    if file.uploadDate != nil && metadata.uploadDate != file.uploadDate {
                        metadata.uploadDate = file.uploadDate!
                        modify = true
                    }
                    if modify {
                        NCManageDatabase.sharedInstance.addMetadata(metadata)
                        NCOperationQueue.shared.reloadDataSourceMedia()
                    }
                } else if errorCode == 404 {
                    NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", self.metadata.ocId))
                    NotificationCenter.default.postOnMainThread(name: k_notificationCenter_mediaFileNotFound, userInfo: ["metadata": self.metadata])
                }
                self.finish()
            }
        }
    }
}



