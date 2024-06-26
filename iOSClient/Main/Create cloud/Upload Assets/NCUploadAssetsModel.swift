//
//  NCUploadAssetsModel.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 04/01/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
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

import SwiftUI
import NextcloudKit
import TLPhotoPicker
import Mantis
import Photos
import QuickLook

// MARK: - Class

struct PreviewStore {
    var id: String
    var asset: TLPHAsset
    var assetType: TLPHAsset.AssetType
    var data: Data?
    var fileName: String
    var image: UIImage
}

class NCUploadAssetsModel: NSObject, ObservableObject, NCCreateFormUploadConflictDelegate {
    @Published var serverUrl: String
    @Published var assets: [TLPHAsset]
    @Published var userBaseUrl: NCUserBaseUrl
    @Published var previewStore: [PreviewStore] = []
    @Published var dismissView = false
    @Published var hiddenSave = true
    @Published var useAutoUploadFolder = false
    @Published var useAutoUploadSubFolder = false
    @Published var showHUD = false
    @Published var uploadInProgress = false
    /// Root View Controller
    @Published var controller: NCMainTabBarController?

    var metadatasNOConflict: [tableMetadata] = []
    var metadatasUploadInConflict: [tableMetadata] = []
    var timer: Timer?

    init(assets: [TLPHAsset], serverUrl: String, userBaseUrl: NCUserBaseUrl, controller: NCMainTabBarController?) {
        self.assets = assets
        self.serverUrl = serverUrl
        self.userBaseUrl = userBaseUrl
        self.controller = controller
        self.showHUD = true
        super.init()

        DispatchQueue.global(qos: .userInteractive).async {
            for asset in self.assets {
                guard let image = asset.fullResolutionImage?.resizeImage(size: CGSize(width: 300, height: 300), isAspectRation: true),
                      let localIdentifier = asset.phAsset?.localIdentifier else { continue }
                self.previewStore.append(PreviewStore(id: localIdentifier, asset: asset, assetType: asset.type, fileName: "", image: image))
            }
            DispatchQueue.main.async {
                self.showHUD = false
                self.hiddenSave = false
            }
        }
    }

    func getTextServerUrl() -> String {
        if let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", userBaseUrl.account, serverUrl)), let metadata = NCManageDatabase.shared.getMetadataFromOcId(directory.ocId) {
            return (metadata.fileNameView)
        } else {
            return (serverUrl as NSString).lastPathComponent
        }
    }

    func getOriginalFilenameForPreview() -> NSString {
        if let asset = assets.first?.phAsset {
            return asset.originalFilename
        } else {
            return ""
        }
    }

    func deleteAsset(index: Int) {
        assets.remove(at: index)
        previewStore.remove(at: index)
        if previewStore.isEmpty {
            dismissView = true
        }
    }

    func presentedQuickLook(index: Int, fileNamePath: String) -> Bool {
        var image: UIImage?

        if let imageData = previewStore[index].data {
            image = UIImage(data: imageData)
        } else if let imageFullResolution = previewStore[index].asset.fullResolutionImage?.fixedOrientation() {
            image = imageFullResolution
        }
        if let image = image {
            if let data = image.jpegData(compressionQuality: 1) {
                do {
                    try data.write(to: URL(fileURLWithPath: fileNamePath))
                    return true
                } catch {
                }
            }
        }
        return false
    }

    func startTimer(navigationItem: UINavigationItem) {
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { _ in
            guard let buttonDone = navigationItem.leftBarButtonItems?.first, let buttonCrop = navigationItem.leftBarButtonItems?.last else { return }
            buttonCrop.isEnabled = true
            buttonDone.isEnabled = true
            if let markup = navigationItem.rightBarButtonItems?.first(where: { $0.accessibilityIdentifier == "QLOverlayMarkupButtonAccessibilityIdentifier" }) {
                if let originalButton = markup.value(forKey: "originalButton") as AnyObject? {
                    if let symbolImageName = originalButton.value(forKey: "symbolImageName") as? String {
                        if symbolImageName == "pencil.tip.crop.circle.on" {
                            buttonCrop.isEnabled = false
                            buttonDone.isEnabled = false
                        }
                    }
                }
            }
        })
    }

    func stopTimer() {
        self.timer?.invalidate()
    }

    func dismissCreateFormUploadConflict(metadatas: [tableMetadata]?) {
        guard let metadatas = metadatas else {
            self.showHUD = false
            self.uploadInProgress.toggle()
            return
        }

        func createProcessUploads() {
            if !self.dismissView {
                NCNetworkingProcess.shared.createProcessUploads(metadatas: metadatas, completion: { _ in
                    self.dismissView = true
                })
            }
        }

        if useAutoUploadFolder {
            DispatchQueue.global().async {
                let assets = self.assets.compactMap { $0.phAsset }
                let result = NCNetworking.shared.createFolder(assets: assets, useSubFolder: self.useAutoUploadSubFolder, account: self.userBaseUrl.account, urlBase: self.userBaseUrl.urlBase, userId: self.userBaseUrl.userId, withPush: false)
                DispatchQueue.main.async {
                    self.showHUD = false
                    self.uploadInProgress.toggle()
                    if result {
                        createProcessUploads()
                    } else {
                        let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_error_createsubfolders_upload_")
                        NCContentPresenter().showError(error: error)
                    }
                }
            }
        } else {
            createProcessUploads()
        }
    }

    func save(completion: @escaping (_ metadatasNOConflict: [tableMetadata], _ metadatasUploadInConflict: [tableMetadata]) -> Void) {
        let utilityFileSystem = NCUtilityFileSystem()
        var metadatasNOConflict: [tableMetadata] = []
        var metadatasUploadInConflict: [tableMetadata] = []
        let autoUploadPath = NCManageDatabase.shared.getAccountAutoUploadPath(urlBase: userBaseUrl.urlBase, userId: userBaseUrl.userId, account: userBaseUrl.account)
        var serverUrl = useAutoUploadFolder ? autoUploadPath : serverUrl

        for tlAsset in assets {
            guard let asset = tlAsset.phAsset, let previewStore = previewStore.first(where: { $0.id == asset.localIdentifier }) else { continue }

            let assetFileName = asset.originalFilename
            var livePhoto: Bool = false
            let creationDate = asset.creationDate ?? Date()
            let ext = assetFileName.pathExtension.lowercased()

            let fileName = previewStore.fileName.isEmpty ? utilityFileSystem.createFileName(assetFileName as String, fileDate: creationDate, fileType: asset.mediaType)
            : (previewStore.fileName + "." + ext)

            if previewStore.assetType == .livePhoto && NCKeychain().livePhoto && previewStore.data == nil {
                livePhoto = true
            }

            // Auto upload with subfolder
            if useAutoUploadSubFolder {
                serverUrl = utilityFileSystem.createGranularityPath(serverUrl: serverUrl)
            }

            // Check if is in upload
            if let results = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@ AND session != ''", userBaseUrl.account, serverUrl, fileName), sorted: "fileName", ascending: false), !results.isEmpty {
                continue
            }

            let metadata = NCManageDatabase.shared.createMetadata(account: userBaseUrl.account, user: userBaseUrl.user, userId: userBaseUrl.userId, fileName: fileName, fileNameView: fileName, ocId: NSUUID().uuidString, serverUrl: serverUrl, urlBase: userBaseUrl.urlBase, url: "", contentType: "")

            if livePhoto {
                metadata.livePhotoFile = (metadata.fileName as NSString).deletingPathExtension + ".mov"
            }
            metadata.assetLocalIdentifier = asset.localIdentifier
            metadata.session = NCNetworking.shared.sessionUploadBackground
            metadata.sessionSelector = NCGlobal.shared.selectorUploadFile
            metadata.status = NCGlobal.shared.metadataStatusWaitUpload
            metadata.sessionDate = Date()

            // Modified
            if let previewStore = self.previewStore.first(where: { $0.id == asset.localIdentifier }), let data = previewStore.data {
                if metadata.contentType == "image/heic" {
                    let fileNameNoExtension = (fileName as NSString).deletingPathExtension
                    metadata.contentType = "image/jpeg"
                    metadata.fileName = fileNameNoExtension + ".jpg"
                    metadata.fileNameView = fileNameNoExtension + ".jpg"
                }
                let fileNamePath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)
                do {
                    try data.write(to: URL(fileURLWithPath: fileNamePath))
                    metadata.isExtractFile = true
                    metadata.size = utilityFileSystem.getFileSize(filePath: fileNamePath)
                    metadata.creationDate = asset.creationDate as? NSDate ?? (Date() as NSDate)
                    metadata.date = asset.modificationDate as? NSDate ?? (Date() as NSDate)
                } catch {  }
            }

            if let result = NCManageDatabase.shared.getMetadataConflict(account: userBaseUrl.account, serverUrl: serverUrl, fileNameView: fileName) {
                metadata.fileName = result.fileName
                metadatasUploadInConflict.append(metadata)
            } else {
                metadatasNOConflict.append(metadata)
            }
        }

        completion(metadatasNOConflict, metadatasUploadInConflict)
    }
}
