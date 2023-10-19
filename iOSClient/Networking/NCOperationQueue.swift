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
import JGProgressHUD

@objc class NCOperationQueue: NSObject {
    @objc public static let shared: NCOperationQueue = {
        let instance = NCOperationQueue()
        return instance
    }()

    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!

    // MARK: - Download file

    func download(metadata: tableMetadata, selector: String) {

        for case let operation as NCOperationDownload in appDelegate.downloadQueue.operations where operation.metadata.ocId == metadata.ocId { return }
        appDelegate.downloadQueue.addOperation(NCOperationDownload(metadata: metadata, selector: selector))
    }

    // MARK: - Download Thumbnail Activity

    func downloadThumbnailActivity(fileNamePathOrFileId: String, fileNamePreviewLocalPath: String, fileId: String, cell: NCActivityCollectionViewCell, collectionView: UICollectionView?) {

        cell.imageView?.image = UIImage(named: "file_photo")
        cell.fileId = fileId

        if !FileManager.default.fileExists(atPath: fileNamePreviewLocalPath) {
            for case let operation as NCOperationDownloadThumbnailActivity in appDelegate.downloadThumbnailActivityQueue.operations where operation.fileId == fileId {
                return
            }
            appDelegate.downloadThumbnailActivityQueue.addOperation(NCOperationDownloadThumbnailActivity(fileNamePathOrFileId: fileNamePathOrFileId, fileNamePreviewLocalPath: fileNamePreviewLocalPath, fileId: fileId, cell: cell, collectionView: collectionView))
        }
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

        for case let operation as NCOperationDownloadAvatar in appDelegate.downloadAvatarQueue.operations where operation.fileName == fileName { return }
        appDelegate.downloadAvatarQueue.addOperation(NCOperationDownloadAvatar(user: user, fileName: fileName, fileNameLocalPath: fileNameLocalPath, cell: cell, view: view, cellImageView: cellImageView))
    }

    // MARK: - Unified Search

    func unifiedSearchAddSection(collectionViewCommon: NCCollectionViewCommon, metadatas: [tableMetadata], searchResult: NKSearchResult) {
        appDelegate.unifiedSearchQueue.addOperation(NCOperationUnifiedSearch(collectionViewCommon: collectionViewCommon, metadatas: metadatas, searchResult: searchResult))
    }

    // MARK: - Save Live Photo

    func saveLivePhoto(metadata: tableMetadata, metadataMOV: tableMetadata) {

        for case let operation as NCOperationSaveLivePhoto in appDelegate.saveLivePhotoQueue.operations where operation.metadata.fileName == metadata.fileName { return }
        appDelegate.saveLivePhotoQueue.addOperation(NCOperationSaveLivePhoto(metadata: metadata, metadataMOV: metadataMOV))
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

        guard !isCancelled else { return self.finish() }

        NCNetworking.shared.download(metadata: metadata, selector: self.selector) { _, _ in
            self.finish()
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

        guard !isCancelled else { return self.finish() }

        NextcloudKit.shared.downloadPreview(fileNamePathOrFileId: fileNamePathOrFileId,
                                            fileNamePreviewLocalPath: fileNamePreviewLocalPath,
                                            widthPreview: 0,
                                            heightPreview: 0,
                                            etag: nil,
                                            useInternalEndpoint: false,
                                            options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { _, imagePreview, _, _, _, error in

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

        guard !isCancelled else { return self.finish() }

        NextcloudKit.shared.downloadAvatar(user: user,
                                           fileNameLocalPath: fileNameLocalPath,
                                           sizeImage: NCGlobal.shared.avatarSize,
                                           avatarSizeRounded: NCGlobal.shared.avatarSizeRounded,
                                           etag: self.etag,
                                           options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { _, imageAvatar, _, etag, error in

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

        guard !isCancelled else { return self.finish() }

        self.collectionViewCommon.dataSource.addSection(metadatas: metadatas, searchResult: searchResult)
        self.collectionViewCommon.searchResults?.append(self.searchResult)
        reloadDataThenPerform {
            self.finish()
        }
    }
}

// MARK: -

class NCOperationSaveLivePhoto: ConcurrentOperation {

    var metadata: tableMetadata
    var metadataMOV: tableMetadata
    let hud = JGProgressHUD()
    let appDelegate = UIApplication.shared.delegate as? AppDelegate

    init(metadata: tableMetadata, metadataMOV: tableMetadata) {
        self.metadata = tableMetadata.init(value: metadata)
        self.metadataMOV = tableMetadata.init(value: metadataMOV)
    }

    override func start() {
        guard !isCancelled else { return self.finish() }

        DispatchQueue.main.async {
            self.hud.indicatorView = JGProgressHUDRingIndicatorView()
            if let indicatorView = self.hud.indicatorView as? JGProgressHUDRingIndicatorView {
                indicatorView.ringWidth = 1.5
            }
            self.hud.textLabel.text = NSLocalizedString("_download_image_", comment: "")
            self.hud.detailTextLabel.text = self.metadata.fileName
            self.hud.show(in: (self.appDelegate?.window?.rootViewController?.view)!)
        }

        NCNetworking.shared.download(metadata: metadata, selector: "", notificationCenterProgressTask: false, checkfileProviderStorageExists: true) { _ in
        } progressHandler: { progress in
            self.hud.progress = Float(progress.fractionCompleted)
        } completion: { _, error in
            guard error == .success else {
                DispatchQueue.main.async {
                    self.hud.indicatorView = JGProgressHUDErrorIndicatorView()
                    self.hud.textLabel.text = NSLocalizedString("_livephoto_save_error_", comment: "")
                    self.hud.dismiss()
                }
                return self.finish()
            }
            NCNetworking.shared.download(metadata: self.metadataMOV, selector: "", notificationCenterProgressTask: false, checkfileProviderStorageExists: true) { _ in
                DispatchQueue.main.async {
                    self.hud.textLabel.text = NSLocalizedString("_download_video_", comment: "")
                    self.hud.detailTextLabel.text = self.metadataMOV.fileName
                }
            } progressHandler: { progress in
                self.hud.progress = Float(progress.fractionCompleted)
            } completion: { _, error in
                guard error == .success else {
                    DispatchQueue.main.async {
                        self.hud.indicatorView = JGProgressHUDErrorIndicatorView()
                        self.hud.textLabel.text = NSLocalizedString("_livephoto_save_error_", comment: "")
                        self.hud.dismiss()
                    }
                    return self.finish()
                }
                self.saveLivePhotoToDisk(metadata: self.metadata, metadataMov: self.metadataMOV)
            }
        }
    }

    func saveLivePhotoToDisk(metadata: tableMetadata, metadataMov: tableMetadata) {

        let fileNameImage = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!)
        let fileNameMov = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadataMov.ocId, fileNameView: metadataMov.fileNameView)!)

        DispatchQueue.main.async {
            self.hud.textLabel.text = NSLocalizedString("_livephoto_save_", comment: "")
            self.hud.detailTextLabel.text = ""
        }

        NCLivePhoto.generate(from: fileNameImage, videoURL: fileNameMov, progress: { progress in
            self.hud.progress = Float(progress)
        }, completion: { _, resources in
            if resources != nil {
                NCLivePhoto.saveToLibrary(resources!) { result in
                    DispatchQueue.main.async {
                        if !result {
                            self.hud.indicatorView = JGProgressHUDErrorIndicatorView()
                            self.hud.textLabel.text = NSLocalizedString("_livephoto_save_error_", comment: "")
                        } else {
                            self.hud.indicatorView = JGProgressHUDSuccessIndicatorView()
                            self.hud.textLabel.text = NSLocalizedString("_success_", comment: "")
                        }
                        self.hud.dismiss()
                    }
                    return self.finish()
                }
            } else {
                DispatchQueue.main.async {
                    self.hud.indicatorView = JGProgressHUDErrorIndicatorView()
                    self.hud.textLabel.text = NSLocalizedString("_livephoto_save_error_", comment: "")
                    self.hud.dismiss()
                }
                return self.finish()
            }
        })
    }
}
