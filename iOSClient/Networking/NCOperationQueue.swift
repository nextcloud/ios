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
import NextcloudKit

@objc class NCOperationQueue: NSObject {
    @objc public static let shared: NCOperationQueue = {
        let instance = NCOperationQueue()
        return instance
    }()

    private var downloadQueue = Queuer(name: "downloadQueue", maxConcurrentOperationCount: 5, qualityOfService: .default)
    private let deleteQueue = Queuer(name: "deleteQueue", maxConcurrentOperationCount: 10, qualityOfService: .default)
    private let deleteQueueE2EE = Queuer(name: "deleteQueue", maxConcurrentOperationCount: 1, qualityOfService: .default)
    private let copyMoveQueue = Queuer(name: "copyMoveQueue", maxConcurrentOperationCount: 1, qualityOfService: .default)
    private let synchronizationQueue = Queuer(name: "synchronizationQueue", maxConcurrentOperationCount: 1, qualityOfService: .default)
    private let downloadThumbnailQueue = Queuer(name: "downloadThumbnailQueue", maxConcurrentOperationCount: 10, qualityOfService: .default)
    private let downloadThumbnailActivityQueue = Queuer(name: "downloadThumbnailActivityQueue", maxConcurrentOperationCount: 10, qualityOfService: .default)
    private let downloadAvatarQueue = Queuer(name: "downloadAvatarQueue", maxConcurrentOperationCount: 10, qualityOfService: .default)
    private let unifiedSearchQueue = Queuer(name: "unifiedSearchQueue", maxConcurrentOperationCount: 1, qualityOfService: .default)

    private var timerReadFileForMediaQueue: Timer?

    @objc func cancelAllQueue() {
        downloadCancelAll()
        deleteCancelAll()
        copyMoveCancelAll()
        synchronizationCancelAll()
        downloadThumbnailCancelAll()
        downloadThumbnailActivityCancelAll()
        downloadAvatarCancelAll()
        unifiedSearchCancelAll()
    }

    // MARK: - Download file

    func download(metadata: tableMetadata, selector: String) {
        for case let operation as NCOperationDownload in downloadQueue.operations where operation.metadata.ocId == metadata.ocId {
            return
        }
        downloadQueue.addOperation(NCOperationDownload(metadata: metadata, selector: selector))
    }

    func downloadCancelAll() {
        downloadQueue.cancelAll()
    }

    func downloadQueueCount() -> Int {
        return downloadQueue.operationCount
    }

    func downloadExists(metadata: tableMetadata) -> Bool {
        for case let operation as NCOperationDownload in downloadQueue.operations where operation.metadata.ocId == metadata.ocId {
            return true
        }
        return false
    }

    // MARK: - Delete file

    func delete(metadata: tableMetadata, onlyLocalCache: Bool) {

        if metadata.isDirectoryE2EE {
            for case let operation as NCOperationDelete in deleteQueueE2EE.operations where operation.metadata.ocId == metadata.ocId {
                return
            }
            deleteQueueE2EE.addOperation(NCOperationDelete(metadata: metadata, onlyLocalCache: onlyLocalCache))
        } else {
            for case let operation as NCOperationDelete in deleteQueue.operations where operation.metadata.ocId == metadata.ocId {
                return
            }
            deleteQueue.addOperation(NCOperationDelete(metadata: metadata, onlyLocalCache: onlyLocalCache))
        }
    }

    func deleteCancelAll() {
        deleteQueue.cancelAll()
    }

    // MARK: - Copy Move file

    func copyMove(metadata: tableMetadata, serverUrl: String, overwrite: Bool, move: Bool) {
        for case let operation as NCOperationCopyMove in copyMoveQueue.operations where operation.metadata.ocId == metadata.ocId {
            return
        }
        copyMoveQueue.addOperation(NCOperationCopyMove(metadata: metadata, serverUrlTo: serverUrl, overwrite: overwrite, move: move))
    }

    func copyMoveCancelAll() {
        copyMoveQueue.cancelAll()
    }

    // MARK: - Synchronization

    func synchronizationMetadata(_ metadata: tableMetadata, selector: String) {
        for case let operation as NCOperationSynchronization in synchronizationQueue.operations where operation.metadata.ocId == metadata.ocId {
            return
        }
        synchronizationQueue.addOperation(NCOperationSynchronization(metadata: metadata, selector: selector))
    }

    func synchronizationCancelAll() {
        synchronizationQueue.cancelAll()
    }

    // MARK: - Download Thumbnail

    func downloadThumbnail(metadata: tableMetadata, placeholder: Bool, cell: UIView?, view: UIView?) {

        let cell: NCCellProtocol? = cell as? NCCellProtocol

        if placeholder {
            if metadata.iconName.isEmpty {
                cell?.filePreviewImageView?.image = NCBrandColor.cacheImages.file
            } else {
                cell?.filePreviewImageView?.image = UIImage(named: metadata.iconName)
            }
        }

        if metadata.hasPreview && metadata.status == NCGlobal.shared.metadataStatusNormal && (!CCUtility.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag)) {
            for case let operation as NCOperationDownloadThumbnail in downloadThumbnailQueue.operations where operation.metadata.ocId == metadata.ocId {
                return
            }
            downloadThumbnailQueue.addOperation(NCOperationDownloadThumbnail(metadata: metadata, cell: cell, view: view))
        }
    }

    func cancelDownloadThumbnail(metadata: tableMetadata) {
        for case let operation as NCOperationDownloadThumbnail in downloadThumbnailQueue.operations where operation.metadata.ocId == metadata.ocId {
            operation.cancel()
        }
    }

    func downloadThumbnailCancelAll() {
        downloadThumbnailQueue.cancelAll()
    }

    // MARK: - Download Thumbnail Activity

    func downloadThumbnailActivity(fileNamePathOrFileId: String, fileNamePreviewLocalPath: String, fileId: String, cell: NCActivityCollectionViewCell, collectionView: UICollectionView?) {

        cell.imageView?.image = UIImage(named: "file_photo")
        cell.fileId = fileId

        if !FileManager.default.fileExists(atPath: fileNamePreviewLocalPath) {
            for case let operation as NCOperationDownloadThumbnailActivity in downloadThumbnailActivityQueue.operations where operation.fileId == fileId {
                return
            }
            downloadThumbnailActivityQueue.addOperation(NCOperationDownloadThumbnailActivity(fileNamePathOrFileId: fileNamePathOrFileId, fileNamePreviewLocalPath: fileNamePreviewLocalPath, fileId: fileId, cell: cell, collectionView: collectionView))
        }
    }

    func cancelDownloadThumbnailActivity(fileId: String) {
        for case let operation as NCOperationDownloadThumbnailActivity in downloadThumbnailActivityQueue.operations where operation.fileId == fileId {
            operation.cancel()
        }
    }

    func downloadThumbnailActivityCancelAll() {
        downloadThumbnailActivityQueue.cancelAll()
    }

    // MARK: - Download Avatar

    func downloadAvatar(user: String, dispalyName: String?, fileName: String, cell: NCCellProtocol, view: UIView?, cellImageView: UIImageView?) {

        let fileNameLocalPath = String(CCUtility.getDirectoryUserData()) + "/" + fileName

        if let image = NCManageDatabase.shared.getImageAvatarLoaded(fileName: fileName) {
            cellImageView?.image = image
            cell.fileAvatarImageView?.image = image
            return
        }

        if let account = NCManageDatabase.shared.getActiveAccount() {
            cellImageView?.image = NCUtility.shared.loadUserImage(
                for: user,
                   displayName: dispalyName,
                   userBaseUrl: account)
        }

        for case let operation as NCOperationDownloadAvatar in downloadAvatarQueue.operations where operation.fileName == fileName {
            return
        }
        downloadAvatarQueue.addOperation(NCOperationDownloadAvatar(user: user, fileName: fileName, fileNameLocalPath: fileNameLocalPath, cell: cell, view: view, cellImageView: cellImageView))
    }

    func cancelDownloadAvatar(user: String) {
        for case let operation as NCOperationDownloadAvatar in downloadAvatarQueue.operations where operation.user == user {
            operation.cancel()
        }
    }

    func downloadAvatarCancelAll() {
        downloadAvatarQueue.cancelAll()
    }

    // MARK: - Unified Search

    func unifiedSearchAddSection(collectionViewCommon: NCCollectionViewCommon, metadatas: [tableMetadata], searchResult: NKSearchResult) {
        unifiedSearchQueue.addOperation(NCOperationUnifiedSearch.init(collectionViewCommon: collectionViewCommon, metadatas: metadatas, searchResult: searchResult))
    }

    func unifiedSearchCancelAll() {
        unifiedSearchQueue.cancelAll()
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
            NCNetworking.shared.download(metadata: metadata, selector: self.selector) { _, _ in
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
            NCNetworking.shared.deleteMetadata(metadata, onlyLocalCache: onlyLocalCache) { error in
                if error != .success {
                    NCContentPresenter.shared.showError(error: error)
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
                NCNetworking.shared.moveMetadata(metadata, serverUrlTo: serverUrlTo, overwrite: overwrite) { error in
                    if error != .success {
                        NCContentPresenter.shared.showError(error: error)
                    }
                    self.finish()
                }
            } else {
                NCNetworking.shared.copyMetadata(metadata, serverUrlTo: serverUrlTo, overwrite: overwrite) { error in
                    if error != .success {
                        NCContentPresenter.shared.showError(error: error)
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

                NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrl, depth: "0", showHiddenFiles: CCUtility.getShowHiddenFiles()) { account, files, _, error in

                    if (error == .success) && (directory?.etag != files.first?.etag || self.selector == NCGlobal.shared.selectorDownloadAllFile) {

                        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

                        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrl, depth: "1", showHiddenFiles: CCUtility.getShowHiddenFiles(), options: options) { account, files, _, error in

                            if error == .success {

                                NCManageDatabase.shared.convertFilesToMetadatas(files, useMetadataFolder: true) { metadataFolder, _, metadatas in

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

                            } else if error.errorCode == NCGlobal.shared.errorResourceNotFound && self.metadata.directory {
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
    var fileNamePath: String
    var fileNamePreviewLocalPath: String
    var fileNameIconLocalPath: String

    init(metadata: tableMetadata, cell: NCCellProtocol?, view: UIView?) {
        self.metadata = tableMetadata.init(value: metadata)
        self.cell = cell
        self.view = view
        self.fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId, account: metadata.account)!
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
            let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
            NextcloudKit.shared.downloadPreview(
                fileNamePathOrFileId: fileNamePath,
                fileNamePreviewLocalPath: fileNamePreviewLocalPath,
                widthPreview: NCGlobal.shared.sizePreview,
                heightPreview: NCGlobal.shared.sizePreview,
                fileNameIconLocalPath: fileNameIconLocalPath,
                sizeIcon: NCGlobal.shared.sizeIcon,
                etag: etagResource,
                options: options) { _, _, imageIcon, _, etag, error in

                    if error == .success, let imageIcon = imageIcon {
                        NCManageDatabase.shared.setMetadataEtagResource(ocId: self.metadata.ocId, etagResource: etag)
                        DispatchQueue.main.async {
                            if self.metadata.ocId == self.cell?.fileObjectId, let filePreviewImageView = self.cell?.filePreviewImageView {
                                UIView.transition(with: filePreviewImageView,
                                                  duration: 0.75,
                                                  options: .transitionCrossDissolve,
                                                  animations: { filePreviewImageView.image = imageIcon },
                                                  completion: nil)
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

class NCOperationDownloadThumbnailActivity: ConcurrentOperation {

    var cell: NCActivityCollectionViewCell?
    var collectionView: UICollectionView?
    var fileNamePathOrFileId: String
    var fileNamePreviewLocalPath: String
    var fileId: String

    init(fileNamePathOrFileId: String, fileNamePreviewLocalPath: String, fileId: String, cell: NCActivityCollectionViewCell?, collectionView: UICollectionView?) {
        self.fileNamePathOrFileId = fileNamePathOrFileId
        self.fileNamePreviewLocalPath = fileNamePreviewLocalPath
        self.fileId = fileId
        self.cell = cell
        self.collectionView = collectionView
    }

    override func start() {

        if isCancelled {
            self.finish()
        } else {

            let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

            NextcloudKit.shared.downloadPreview(
                fileNamePathOrFileId: fileNamePathOrFileId,
                fileNamePreviewLocalPath: fileNamePreviewLocalPath,
                widthPreview: 0,
                heightPreview: 0,
                etag: nil,
                useInternalEndpoint: false,
                options: options) { _, imagePreview, _, _, _, error in

                    if error == .success, let imagePreview = imagePreview {
                        DispatchQueue.main.async {
                            if self.fileId == self.cell?.fileId, let imageView = self.cell?.imageView {
                                UIView.transition(with: imageView,
                                                  duration: 0.75,
                                                  options: .transitionCrossDissolve,
                                                  animations: { imageView.image = imagePreview },
                                                  completion: nil)
                            } else {
                                self.collectionView?.reloadData()
                            }
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
    var cellImageView: UIImageView?

    init(user: String, fileName: String, fileNameLocalPath: String, cell: NCCellProtocol, view: UIView?, cellImageView: UIImageView?) {
        self.user = user
        self.fileName = fileName
        self.fileNameLocalPath = fileNameLocalPath
        self.cell = cell
        self.view = view
        self.etag = NCManageDatabase.shared.getTableAvatar(fileName: fileName)?.etag
        self.cellImageView = cellImageView
    }

    override func start() {

        if isCancelled {
            self.finish()
        } else {
            
            let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

            NextcloudKit.shared.downloadAvatar(user: user, fileNameLocalPath: fileNameLocalPath, sizeImage: NCGlobal.shared.avatarSize, avatarSizeRounded: NCGlobal.shared.avatarSizeRounded, etag: self.etag, options: options) { _, imageAvatar, _, etag, error in

                if error == .success, let imageAvatar = imageAvatar, let etag = etag {
                    NCManageDatabase.shared.addAvatar(fileName: self.fileName, etag: etag)
                    DispatchQueue.main.async {
                        if self.user == self.cell.fileUser, let avatarImageView = self.cellImageView {
                            UIView.transition(with: avatarImageView,
                                              duration: 0.75,
                                              options: .transitionCrossDissolve,
                                              animations: { avatarImageView.image = imageAvatar },
                                              completion: nil)
                        } else {
                            if self.view is UICollectionView {
                                (self.view as? UICollectionView)?.reloadData()
                            } else if self.view is UITableView {
                                (self.view as? UITableView)?.reloadData()
                            }
                        }
                    }
                } else if error.errorCode == NCGlobal.shared.errorNotModified {
                    NCManageDatabase.shared.setAvatarLoaded(fileName: self.fileName)
                }
                self.finish()
            }
        }
    }
}

// MARK: -

class NCOperationUnifiedSearch: ConcurrentOperation {

    var collectionViewCommon: NCCollectionViewCommon
    var metadatas: [tableMetadata]
    var searchResult: NKSearchResult

    init(collectionViewCommon: NCCollectionViewCommon, metadatas: [tableMetadata], searchResult: NKSearchResult) {
        self.collectionViewCommon = collectionViewCommon
        self.metadatas = metadatas
        self.searchResult = searchResult
    }

    func reloadDataThenPerform(_ closure: @escaping (() -> Void)) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            CATransaction.begin()
            CATransaction.setCompletionBlock(closure)
            self.collectionViewCommon.collectionView.reloadData()
            CATransaction.commit()
        }
    }

    override func start() {

        if isCancelled {
            self.finish()
        } else {
            self.collectionViewCommon.dataSource.addSection(metadatas: metadatas, searchResult: searchResult)
            self.collectionViewCommon.searchResults?.append(self.searchResult)
            reloadDataThenPerform {
                self.finish()
            }
        }
    }
}
