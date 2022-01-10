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

import UIKit
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
    private let downloadAvatarQueue = Queuer(name: "downloadAvatarQueue", maxConcurrentOperationCount: 10, qualityOfService: .default)

    private var timerReadFileForMediaQueue: Timer?

    @objc func cancelAllQueue() {
        downloadCancelAll()
        deleteCancelAll()
        copyMoveCancelAll()
        synchronizationCancelAll()
        downloadThumbnailCancelAll()
        downloadAvatarCancelAll()
    }

    // Download file

    func download(metadata: tableMetadata, selector: String) {
        for operation in downloadQueue.operations as! [NCOperationDownload] {
            if operation.metadata.ocId == metadata.ocId {
                return
            }
        }
        downloadQueue.addOperation(NCOperationDownload(metadata: metadata, selector: selector))
    }
    @objc func downloadCancelAll() {
        downloadQueue.cancelAll()
    }
    @objc func downloadCount() -> Int {
        return downloadQueue.operationCount
    }
    @objc func downloadExists(metadata: tableMetadata) -> Bool {
        for operation in downloadQueue.operations as! [NCOperationDownload] {
            if operation.metadata.ocId == metadata.ocId {
                return true
            }
        }
        return false
    }

    // Delete file

    @objc func delete(metadata: tableMetadata, onlyLocalCache: Bool) {
        for operation in deleteQueue.operations as! [NCOperationDelete] {
            if operation.metadata.ocId == metadata.ocId {
                return
            }
        }
        deleteQueue.addOperation(NCOperationDelete(metadata: metadata, onlyLocalCache: onlyLocalCache))
    }
    @objc func deleteCancelAll() {
        deleteQueue.cancelAll()
    }
    @objc func deleteCount() -> Int {
        return deleteQueue.operationCount
    }

    // Copy Move file

    @objc func copyMove(metadata: tableMetadata, serverUrl: String, overwrite: Bool, move: Bool) {
        for operation in copyMoveQueue.operations as! [NCOperationCopyMove] {
            if operation.metadata.ocId == metadata.ocId {
                return
            }
        }
        copyMoveQueue.addOperation(NCOperationCopyMove(metadata: metadata, serverUrlTo: serverUrl, overwrite: overwrite, move: move))
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
        synchronizationQueue.addOperation(NCOperationSynchronization(metadata: metadata, selector: selector))
    }
    @objc func synchronizationCancelAll() {
        synchronizationQueue.cancelAll()
    }

    // Download Thumbnail

    @objc func downloadThumbnail(metadata: tableMetadata, placeholder: Bool, cell: UIView?, view: UIView?) {

        let cell: NCCellProtocol? = cell as? NCCellProtocol

        if placeholder {
            if metadata.iconName.count > 0 {
                cell?.filePreviewImageView?.image = UIImage(named: metadata.iconName)
            } else {
                cell?.filePreviewImageView?.image = NCBrandColor.cacheImages.file
            }
        }

        if metadata.hasPreview && metadata.status == NCGlobal.shared.metadataStatusNormal && (!CCUtility.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag)) {
            for operation in downloadThumbnailQueue.operations as! [NCOperationDownloadThumbnail] {
                if operation.metadata.ocId == metadata.ocId {
                    return
                }
            }
            downloadThumbnailQueue.addOperation(NCOperationDownloadThumbnail(metadata: metadata, cell: cell, view: view))
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

    // Download Avatar

    func downloadAvatar(user: String, dispalyName: String?, fileName: String, cell: NCCellProtocol, view: UIView?) {

        let fileNameLocalPath = String(CCUtility.getDirectoryUserData()) + "/" + fileName

        if let image = NCManageDatabase.shared.getImageAvatarLoaded(fileName: fileName) {
            cell.fileAvatarImageView?.image = image
            return
        }

        if let account = NCManageDatabase.shared.getActiveAccount() {
            cell.fileAvatarImageView?.image = NCUtility.shared.loadUserImage(
                for: user,
                   displayName: dispalyName,
                   userBaseUrl: account)
        }

        for operation in downloadAvatarQueue.operations as! [NCOperationDownloadAvatar] {
            if operation.fileName == fileName {
                return
            }
        }
        downloadAvatarQueue.addOperation(NCOperationDownloadAvatar(user: user, fileName: fileName, fileNameLocalPath: fileNameLocalPath, cell: cell, view: view))
    }

    func cancelDownloadAvatar(user: String) {
        for operation in  downloadAvatarQueue.operations as! [NCOperationDownloadAvatar] {
            if operation.user == user {
                operation.cancel()
            }
        }
    }

    @objc func downloadAvatarCancelAll() {
        downloadAvatarQueue.cancelAll()
    }
}

// MARK: -

class NCOperationDownload: ConcurrentOperation {

    var metadata: tableMetadata
    var selector: String

    init(metadata: tableMetadata, selector: String) {
        self.metadata = tableMetadata.init(value: metadata)
        self.selector = selector
    }

    override func start() {
        if isCancelled {
            self.finish()
        } else {
            NCNetworking.shared.download(metadata: metadata, selector: self.selector) { _ in
                self.finish()
            }
        }
    }
}

// MARK: -

class NCOperationDelete: ConcurrentOperation {

    var metadata: tableMetadata
    var onlyLocalCache: Bool

    init(metadata: tableMetadata, onlyLocalCache: Bool) {
        self.metadata = tableMetadata.init(value: metadata)
        self.onlyLocalCache = onlyLocalCache
    }

    override func start() {
        if isCancelled {
            self.finish()
        } else {
            NCNetworking.shared.deleteMetadata(metadata, onlyLocalCache: onlyLocalCache) { errorCode, errorDescription in
                if errorCode != 0 {
                    NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                }
                self.finish()
            }
        }
    }
}

// MARK: -

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
                NCNetworking.shared.moveMetadata(metadata, serverUrlTo: serverUrlTo, overwrite: overwrite) { errorCode, errorDescription in
                    if errorCode != 0 {
                        NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                    }
                    self.finish()
                }
            } else {
                NCNetworking.shared.copyMetadata(metadata, serverUrlTo: serverUrlTo, overwrite: overwrite) { errorCode, errorDescription in
                    if errorCode != 0 {
                        NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                    }
                    self.finish()
                }
            }
        }
    }
}

// MARK: -

class NCOperationSynchronization: ConcurrentOperation {

    var metadata: tableMetadata
    var selector: String
    var download: Bool

    init(metadata: tableMetadata, selector: String) {
        self.metadata = tableMetadata.init(value: metadata)
        self.selector = selector
        if selector == NCGlobal.shared.selectorDownloadFile || selector == NCGlobal.shared.selectorDownloadAllFile {
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

                let serverUrl = metadata.serverUrl + "/" + metadata.fileName
                let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, serverUrl))

                NCCommunication.shared.readFileOrFolder(serverUrlFileName: serverUrl, depth: "0", showHiddenFiles: CCUtility.getShowHiddenFiles()) { account, files, _, errorCode, _ in

                    if (errorCode == 0) && (directory?.etag != files.first?.etag || self.selector == NCGlobal.shared.selectorDownloadAllFile) {

                        NCCommunication.shared.readFileOrFolder(serverUrlFileName: serverUrl, depth: "1", showHiddenFiles: CCUtility.getShowHiddenFiles(), queue: NCCommunicationCommon.shared.backgroundQueue) { account, files, _, errorCode, _ in

                            if errorCode == 0 {

                                NCManageDatabase.shared.convertNCCommunicationFilesToMetadatas(files, useMetadataFolder: true, account: account) { metadataFolder, _, metadatas in

                                    let metadatasResult = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND status == %d", account, serverUrl, NCGlobal.shared.metadataStatusNormal))

                                    if self.selector == NCGlobal.shared.selectorDownloadAllFile {

                                        NCManageDatabase.shared.updateMetadatas(metadatas, metadatasResult: metadatasResult)

                                        for metadata in metadatas {
                                            if metadata.directory {
                                                NCOperationQueue.shared.synchronizationMetadata(metadata, selector: self.selector)
                                            } else {
                                                if NCManageDatabase.shared.isDownloadMetadata(metadata, download: true) {
                                                    NCOperationQueue.shared.download(metadata: metadata, selector: self.selector)
                                                }
                                            }
                                        }

                                    } else {

                                        let metadatasChanged = NCManageDatabase.shared.updateMetadatas(metadatas, metadatasResult: metadatasResult, addExistsInLocal: self.download, addCompareEtagLocal: true, addDirectorySynchronized: true)

                                        for metadata in metadatasChanged.metadatasUpdate {
                                            if metadata.directory {
                                                NCOperationQueue.shared.synchronizationMetadata(metadata, selector: self.selector)
                                            }
                                        }

                                        for metadata in metadatasChanged.metadatasLocalUpdate {
                                            NCOperationQueue.shared.download(metadata: metadata, selector: self.selector)
                                        }
                                    }

                                    // Update etag directory
                                    NCManageDatabase.shared.addDirectory(encrypted: metadataFolder.e2eEncrypted, favorite: metadataFolder.favorite, ocId: metadataFolder.ocId, fileId: metadataFolder.fileId, etag: metadataFolder.etag, permissions: metadataFolder.permissions, serverUrl: serverUrl, account: metadataFolder.account)
                                }

                            } else if errorCode == NCGlobal.shared.errorResourceNotFound && self.metadata.directory {
                                NCManageDatabase.shared.deleteDirectoryAndSubDirectory(serverUrl: self.metadata.serverUrl, account: self.metadata.account)
                            }

                            self.finish()
                        }

                    } else {

                        let metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl))
                        for metadata in metadatas {
                            if metadata.directory {
                                NCOperationQueue.shared.synchronizationMetadata(metadata, selector: self.selector)
                            } else {
                                if NCManageDatabase.shared.isDownloadMetadata(metadata, download: self.download) {
                                    NCOperationQueue.shared.download(metadata: metadata, selector: self.selector)
                                }
                            }
                        }

                        self.finish()
                    }
                }

            } else {
                if NCManageDatabase.shared.isDownloadMetadata(metadata, download: self.download) {
                    NCOperationQueue.shared.download(metadata: metadata, selector: self.selector)
                }
                self.finish()
            }
        }
    }
}

// MARK: -

class NCOperationDownloadThumbnail: ConcurrentOperation {

    var metadata: tableMetadata
    var cell: NCCellProtocol?
    var view: UIView?
    var fileNamePath: String = ""
    var fileNamePreviewLocalPath: String = ""
    var fileNameIconLocalPath: String = ""

    init(metadata: tableMetadata, cell: NCCellProtocol?, view: UIView?) {
        self.metadata = tableMetadata.init(value: metadata)
        self.cell = cell
        self.view = view
        self.fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, account: metadata.account)!
        self.fileNamePreviewLocalPath = CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)!
        self.fileNameIconLocalPath = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)!
    }

    override func start() {

        if isCancelled {
            self.finish()
        } else {
            var etagResource: String?
            if FileManager.default.fileExists(atPath: fileNameIconLocalPath) && FileManager.default.fileExists(atPath: fileNamePreviewLocalPath) {
                etagResource = metadata.etagResource
            }
            NCCommunication.shared.downloadPreview(
                fileNamePathOrFileId: fileNamePath,
                fileNamePreviewLocalPath: fileNamePreviewLocalPath,
                widthPreview: NCGlobal.shared.sizePreview,
                heightPreview: NCGlobal.shared.sizePreview,
                fileNameIconLocalPath: fileNameIconLocalPath,
                sizeIcon: NCGlobal.shared.sizeIcon,
                etag: etagResource,
                queue: NCCommunicationCommon.shared.backgroundQueue) { _, _, imageIcon, _, etag, errorCode, _ in

                    if errorCode == 0 && imageIcon != nil {
                        NCManageDatabase.shared.setMetadataEtagResource(ocId: self.metadata.ocId, etagResource: etag)
                        DispatchQueue.main.async {
                            if self.metadata.ocId == self.cell?.fileObjectId {
                                if let filePreviewImageView = self.cell?.filePreviewImageView {
                                    UIView.transition(with: filePreviewImageView,
                                                      duration: 0.75,
                                                      options: .transitionCrossDissolve,
                                                      animations: { filePreviewImageView.image = imageIcon! },
                                                      completion: nil)
                                }
                            } else {
                                if self.view is UICollectionView {
                                    (self.view as? UICollectionView)?.reloadData()
                                } else if self.view is UITableView {
                                    (self.view as? UITableView)?.reloadData()
                                }
                            }
                            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadedThumbnail, userInfo: ["ocId": self.metadata.ocId])
                        }
                    }
                    self.finish()
                }
        }
    }
}

// MARK: -

class NCOperationDownloadAvatar: ConcurrentOperation {

    var user: String
    var fileName: String
    var etag: String?
    var fileNameLocalPath: String
    var cell: NCCellProtocol!
    var view: UIView?

    init(user: String, fileName: String, fileNameLocalPath: String, cell: NCCellProtocol, view: UIView?) {
        self.user = user
        self.fileName = fileName
        self.fileNameLocalPath = fileNameLocalPath
        self.cell = cell
        self.view = view
        self.etag = NCManageDatabase.shared.getTableAvatar(fileName: fileName)?.etag
    }

    override func start() {

        if isCancelled {
            self.finish()
        } else {
            NCCommunication.shared.downloadAvatar(user: user, fileNameLocalPath: fileNameLocalPath, sizeImage: NCGlobal.shared.avatarSize, avatarSizeRounded: NCGlobal.shared.avatarSizeRounded, etag: self.etag, queue: NCCommunicationCommon.shared.backgroundQueue) { _, imageAvatar, _, etag, errorCode, _ in

                if errorCode == 0, let imageAvatar = imageAvatar, let etag = etag {

                    NCManageDatabase.shared.addAvatar(fileName: self.fileName, etag: etag)

                    DispatchQueue.main.async {
                        if self.user == self.cell.fileUser {
                            if let avatarImageView = self.cell?.fileAvatarImageView {
                                UIView.transition(with: avatarImageView, duration: 0.75, options: .transitionCrossDissolve) {
                                    avatarImageView.image = imageAvatar
                                } completion: { _ in
                                    if self.view is UICollectionView {
                                        (self.view as? UICollectionView)?.reloadData()
                                    } else if self.view is UITableView {
                                        (self.view as? UITableView)?.reloadData()
                                    }
                                }
                            }
                        } else {
                            if self.view is UICollectionView {
                                (self.view as? UICollectionView)?.reloadData()
                            } else if self.view is UITableView {
                                (self.view as? UITableView)?.reloadData()
                            }
                        }
                    }

                } else if errorCode == NCGlobal.shared.errorNotModified {

                    NCManageDatabase.shared.setAvatarLoaded(fileName: self.fileName)
                }

                self.finish()
            }
        }
    }
}
