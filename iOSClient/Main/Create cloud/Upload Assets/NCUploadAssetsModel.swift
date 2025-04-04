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
    var uti: String?
    var nativeFormat: Bool
    var data: Data?
    var fileName: String
    var image: UIImage?
}

class NCUploadAssetsModel: ObservableObject, NCCreateFormUploadConflictDelegate {
    @Published var serverUrl: String
    @Published var assets: [TLPHAsset]
    @Published var previewStore: [PreviewStore] = []
    @Published var dismissView = false
    @Published var hiddenSave = true
    @Published var useAutoUploadFolder = false
    @Published var useAutoUploadSubFolder = false
    @Published var showHUD = false
    @Published var uploadInProgress = false
    /// Root View Controller
    @Published var controller: NCMainTabBarController?
    /// Session
    var session: NCSession.Session {
        NCSession.shared.getSession(controller: controller)
    }
    let database = NCManageDatabase.shared
    var transfersNoConflict: [TableTransfer] = []
    var transfersInConflict: [TableTransfer] = []
    var timer: Timer?

    init(assets: [TLPHAsset], serverUrl: String, controller: NCMainTabBarController?) {
        self.assets = assets
        self.serverUrl = serverUrl
        self.controller = controller

        for asset in self.assets {
            var uti: String?

            if let phAsset = asset.phAsset,
               let resource = PHAssetResource.assetResources(for: phAsset).first(where: { $0.type == .photo }) {
                uti = resource.uniformTypeIdentifier
            }

            guard let localIdentifier = asset.phAsset?.localIdentifier
            else {
                continue
            }

            self.previewStore.append(PreviewStore(id: localIdentifier, asset: asset, assetType: asset.type, uti: uti, nativeFormat: !NCKeychain().formatCompatibility, fileName: ""))

        }

        self.hiddenSave = false
    }

    func getTextServerUrl() -> String {
        if let directory = database.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl)), let metadata = database.getMetadataFromOcId(directory.ocId) {
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

    func lowResolutionImage(asset: PHAsset) -> UIImage? {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        let targetSize = CGSize(width: 80, height: 80)
        var thumbnail: UIImage?

        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { result, _ in
            thumbnail = result
        }

        return thumbnail
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
        self.timer = nil
    }

    func dismissCreateFormUploadConflict(transfers: [TableTransfer]?) {
        guard let transfers else {
            self.showHUD = false
            self.uploadInProgress.toggle()
            return
        }

        func createProcessUploads() {
            if !self.dismissView {
                self.database.createTransferProcessUploads(transfers: transfers) { items in
                    self.dismissView = true
                }
            }
        }

        if useAutoUploadFolder {
            let assets = self.assets.compactMap { $0.phAsset }
            NCNetworking.shared.createFolder(assets: assets, useSubFolder: self.useAutoUploadSubFolder, session: self.session)
            self.showHUD = false
            createProcessUploads()
        } else {
            createProcessUploads()
        }
    }

    func save(completion: @escaping (_ transfersNOConflict: [TableTransfer], _ transfersInConflict: [TableTransfer]) -> Void) {
        let utilityFileSystem = NCUtilityFileSystem()
        var transfersNoConflict: [TableTransfer] = []
        var transfersInConflict: [TableTransfer] = []
        let autoUploadPath = database.getAccountAutoUploadPath(session: self.session)
        var serverUrl = useAutoUploadFolder ? autoUploadPath : serverUrl

        for tlAsset in assets {
            guard let asset = tlAsset.phAsset,
                  let previewStore = previewStore.first(where: { $0.id == asset.localIdentifier })
            else {
                continue
            }
            let assetFileName = asset.originalFilename
            var livePhoto: Bool = false
            let creationDate = asset.creationDate ?? Date()
            let ext = assetFileName.pathExtension.lowercased()
            let fileName = previewStore.fileName.isEmpty ? utilityFileSystem.createFileName(assetFileName as String, fileDate: creationDate, fileType: asset.mediaType)
            : (previewStore.fileName + "." + ext)

            if previewStore.assetType == .livePhoto && NCKeychain().livePhoto && previewStore.data == nil {
                livePhoto = true
            }

            if useAutoUploadSubFolder {
                serverUrl = utilityFileSystem.createGranularityPath(asset: asset, serverUrl: autoUploadPath)
            }

            if let transfer = self.database.createTransferForUpload(session: session,
                                                                    serverUrl: serverUrl,
                                                                    fileName: fileName,
                                                                    livePhoto: livePhoto,
                                                                    nativeFormat: previewStore.nativeFormat,
                                                                    localIdentifier: asset.localIdentifier,
                                                                    uploadSession: NCNetworking.shared.sessionUploadBackground,
                                                                    sceneIdentifier: controller?.sceneIdentifier) {

                if let previewStore = self.previewStore.first(where: { $0.id == asset.localIdentifier }),
                   let data = previewStore.data {
                    if transfer.contentType == "image/heic" {
                        let fileNameNoExtension = (fileName as NSString).deletingPathExtension
                        transfer.contentType = "image/jpeg"
                        transfer.fileName = fileNameNoExtension + ".jpg"
                        transfer.fileNameView = fileNameNoExtension + ".jpg"
                        transfer.nativeFormat = false
                    }
                    let fileNamePath = utilityFileSystem.getDirectoryProviderStorageOcId(transfer.id, fileNameView: transfer.fileNameView)
                    do {
                        try data.write(to: URL(fileURLWithPath: fileNamePath))
                        transfer.isExtractFile = true
                        transfer.size = utilityFileSystem.getFileSize(filePath: fileNamePath)
                        if let date = asset.creationDate {
                            transfer.creationDate = date
                        }
                        if let date = asset.modificationDate {
                            transfer.modificationDate = date
                        }
                    } catch {
                        continue
                    }
                }

                if let result = database.getMetadataConflict(account: session.account, serverUrl: serverUrl, fileNameView: fileName, nativeFormat: transfer.nativeFormat) {
                    transfer.fileName = result.fileName
                    transfersInConflict.append(transfer)
                } else {
                    transfersNoConflict.append(transfer)
                }

            } else {
                continue
            }
        }

        completion(transfersNoConflict, transfersInConflict)
    }
}
