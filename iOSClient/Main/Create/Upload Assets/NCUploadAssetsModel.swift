// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-FileCopyrightText: 2026 Rasmus Wøldike
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit
import TLPhotoPicker
import Photos
import QuickLook


// MARK: - CameraAssets helper
enum CameraAssets {
    struct TempAsset {
        let fileURL: URL
        let fileName: String
        let isVideo: Bool
    }
}

// MARK: - PreviewStore
struct PreviewStore {
    var id: String
    var asset: TLPHAsset?
    var assetType: TLPHAsset.AssetType
    var uti: String?
    var nativeFormat: Bool
    var data: Data?
    var fileName: String
    var image: UIImage?
    var tempURL: URL?
}

// MARK: - NCUploadAssetsModel
class NCUploadAssetsModel: ObservableObject, NCCreateFormUploadConflictDelegate {
    func dismissCreateFormUploadConflict(metadatas: [tableMetadata]?) {
        guard let metadatas = metadatas else {
            self.showHUD = false
            self.uploadInProgress.toggle()
            return
        }
        let autoMkcol = capabilities.serverVersionMajor >= NCGlobal.shared.nextcloudVersion33
        func createProcessUploads() {
            if !self.dismissView {
                self.database.addMetadatas(metadatas)
                if self.saveToCameraRoll && !self.tempAssets.isEmpty {
                    self.saveTempAssetsToCameraRoll()
                }
                self.dismissView = true
            }
        }

        if !autoMkcol, useAutoUploadFolder {
            let assets = self.assets.compactMap { $0.phAsset }
            NCManageDatabaseCreateMetadata().createMetadatasFolder(
                assets: assets,
                useSubFolder: self.useAutoUploadSubFolder,
                session: self.session
            ) { metadatasFolder in
                self.database.addMetadatas(metadatasFolder)
                self.showHUD = false
                createProcessUploads()
            }
        } else {
            createProcessUploads()
        }
    }
    

    private func saveTempAssetsToCameraRoll() {
        for url in tempAssets {
            let ext = url.pathExtension.lowercased()
            if ["mov", "mp4", "m4v"].contains(ext) {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }, completionHandler: nil)
            } else if let data = try? Data(contentsOf: url) {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
                }, completionHandler: nil)
            }
        }
    }

    // MARK: - Published
    @Published var serverUrl: String
    @Published var assets: [TLPHAsset] = []
    @Published var previewStore: [PreviewStore] = []
    @Published var dismissView = false
    @Published var hiddenSave = true
    @Published var useAutoUploadFolder = false
    @Published var useAutoUploadSubFolder = false
    @Published var showHUD = false
    @Published var uploadInProgress = false
    @Published var controller: NCMainTabBarController?
    @Published var saveToCameraRoll: Bool = false

    // MARK: - Private
    var keychain = NCPreferences()
    let database = NCManageDatabase.shared
    let global = NCGlobal.shared
    var timer: Timer?
    var metadatasNOConflict: [tableMetadata] = []
    var metadatasUploadInConflict: [tableMetadata] = []
    var tempAssets: [URL] = []

    // MARK: - Session / Capabilities
    var session: NCSession.Session {
        NCSession.shared.getSession(controller: controller)
    }
    
    var capabilities: NKCapabilities.Capabilities {
        NCNetworking.shared.capabilities[controller?.account ?? ""] ?? NKCapabilities.Capabilities()
    }
    
    // MARK: - Initializers
    
    init(assets: [TLPHAsset], serverUrl: String, controller: NCMainTabBarController?) {
        self.assets = assets
        self.serverUrl = serverUrl
        self.controller = controller

        self.useAutoUploadFolder = keychain.getUploadUseAutoUploadFolder(account: session.account)
        self.useAutoUploadSubFolder = keychain.getUploadUseAutoUploadSubFolder(account: session.account)

        for asset in self.assets {
            var uti: String?

            if let phAsset = asset.phAsset,
               let resource = PHAssetResource.assetResources(for: phAsset).first(where: { $0.type == .photo }) {
                uti = resource.uniformTypeIdentifier
            }

            guard let localIdentifier = asset.phAsset?.localIdentifier else { continue }

            self.previewStore.append(
                PreviewStore(
                    id: localIdentifier,
                    asset: asset,
                    assetType: asset.type,
                    uti: uti,
                    nativeFormat: !NCPreferences().formatCompatibility,
                    data: nil,
                    fileName: "",
                    image: nil
                )
            )
        }

        self.hiddenSave = false
    }

    init(tempAssets: [URL], serverUrl: String, controller: NCMainTabBarController?) {
        self.assets = []
        self.tempAssets = tempAssets
        self.serverUrl = serverUrl
        self.controller = controller
        self.saveToCameraRoll = NCPreferences().saveCameraMediaToCameraRoll

        self.useAutoUploadFolder = keychain.getUploadUseAutoUploadFolder(account: session.account)
        self.useAutoUploadSubFolder = keychain.getUploadUseAutoUploadSubFolder(account: session.account)

        self.previewStore = tempAssets.map { url in
            PreviewStore(
                id: UUID().uuidString,
                asset: nil,
                assetType: .photo,
                uti: nil,
                nativeFormat: true,
                data: try? Data(contentsOf: url),
                fileName: url.lastPathComponent,
                image: UIImage(contentsOfFile: url.path),
                tempURL: url
            )
        }

        self.hiddenSave = false
    }
    
    
    // MARK: - Timer (QuickLook)
    func startTimer(navigationItem: UINavigationItem) {
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            guard let buttonDone = navigationItem.leftBarButtonItems?.first,
                  let buttonCrop = navigationItem.leftBarButtonItems?.last else { return }

            buttonCrop.isEnabled = true
            buttonDone.isEnabled = true

            if let markup = navigationItem.rightBarButtonItems?.first(where: { $0.accessibilityIdentifier == "QLOverlayMarkupButtonAccessibilityIdentifier" }),
               let originalButton = markup.value(forKey: "originalButton") as AnyObject?,
               let symbolImageName = originalButton.value(forKey: "symbolImageName") as? String,
               symbolImageName == "pencil.tip.crop.circle.on" {
                buttonCrop.isEnabled = false
                buttonDone.isEnabled = false
            }
        }
    }

    func stopTimer() {
        self.timer?.invalidate()
        self.timer = nil
    }

    // MARK: - Helpers

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

    func presentedQuickLook(index: Int, fileNamePath: String) -> Bool {
        var image: UIImage?
        if let imageData = previewStore[index].data {
            image = UIImage(data: imageData)
        } else if let imageFullResolution = previewStore[index].asset?.fullResolutionImage?.fixedOrientation() {
            image = imageFullResolution
        } else if let tempURL = previewStore[index].tempURL {
            image = UIImage(contentsOfFile: tempURL.path)
        }
        if let image,
           let data = image.jpegData(compressionQuality: 1) {
            try? data.write(to: URL(fileURLWithPath: fileNamePath))
            return true
        }
        return false
    }

    func deleteAsset(index: Int) {
        guard index < previewStore.count else { return }
        previewStore.remove(at: index)
        if previewStore.isEmpty { dismissView = true }
    }

    func updateUseAutoUploadFolder() {
        keychain.setUploadUseAutoUploadFolder(account: session.account, value: useAutoUploadFolder)
    }

    func updateUseAutoUploadSubFolder() {
        keychain.setUploadUseAutoUploadSubFolder(account: session.account, value: useAutoUploadSubFolder)
    }

    func getTextServerUrl() -> String {
        if let directory = database.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl)),
           let metadata = database.getMetadataFromOcId(directory.ocId) {
            return metadata.fileNameView
        }
        return (serverUrl as NSString).lastPathComponent
    }
    
    func save(completion: @escaping (_ metadatasNOConflict: [tableMetadata], _ metadatasUploadInConflict: [tableMetadata]) -> Void) {
        Task { @MainActor in

            let utilityFileSystem = NCUtilityFileSystem()
            var metadatasNOConflict: [tableMetadata] = []
            var metadatasUploadInConflict: [tableMetadata] = []

            let autoUploadServerUrlBase = database.getAccountAutoUploadServerUrlBase(session: self.session)
            var serverUrl = useAutoUploadFolder ? autoUploadServerUrlBase : self.serverUrl
            let isInDirectoryE2EE = NCUtilityFileSystem().isDirectoryE2EE(serverUrl: serverUrl, urlBase: session.urlBase, userId: session.userId, account: session.account)

            for tlAsset in assets {

                guard let asset = tlAsset.phAsset,
                      let preview = previewStore.first(where: { $0.id == asset.localIdentifier }) else { continue }

                let assetFileName = asset.originalFilename
                let creationDate = asset.creationDate ?? Date()
                let ext = (assetFileName as NSString).pathExtension.lowercased()
                let fileName = preview.fileName.isEmpty
                    ? utilityFileSystem.createFileName(assetFileName, fileDate: creationDate, fileType: asset.mediaType)
                    : (preview.fileName + "." + ext)

                let livePhoto = preview.assetType == .livePhoto
                    && !isInDirectoryE2EE
                    && NCPreferences().livePhoto
                    && preview.data == nil

                if useAutoUploadSubFolder {
                    serverUrl = utilityFileSystem.createGranularityPath(asset: asset, serverUrlBase: autoUploadServerUrlBase)
                }

                let predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@ AND session != ''",
                                            session.account, serverUrl, fileName)
                if let results = database.getMetadatas(predicate: predicate, sortedByKeyPath: "fileName", ascending: false),
                   !results.isEmpty {
                    continue
                }

                let metadata = await NCManageDatabaseCreateMetadata().createMetadataAsync(
                    fileName: fileName,
                    ocId: UUID().uuidString,
                    serverUrl: serverUrl,
                    session: session,
                    sceneIdentifier: controller?.sceneIdentifier
                )

                if livePhoto {
                    metadata.livePhotoFile = (metadata.fileName as NSString).deletingPathExtension + ".mov"
                }
                metadata.assetLocalIdentifier = asset.localIdentifier
                metadata.session = NCNetworking.shared.sessionUploadBackground
                metadata.sessionSelector = global.selectorUploadFile
                metadata.status = global.metadataStatusWaitUpload
                metadata.sessionDate = Date()
                metadata.nativeFormat = preview.nativeFormat

                if let data = preview.data {
                    if metadata.contentType == "image/heic" {
                        let fileNameNoExtension = (fileName as NSString).deletingPathExtension
                        metadata.contentType = "image/jpeg"
                        metadata.fileName = fileNameNoExtension + ".jpg"
                        metadata.fileNameView = fileNameNoExtension + ".jpg"
                        metadata.nativeFormat = false
                    }
                    let fileNamePath = utilityFileSystem.getDirectoryProviderStorageOcId(
                        metadata.ocId,
                        fileName: metadata.fileNameView,
                        userId: metadata.userId,
                        urlBase: metadata.urlBase
                    )
                    do {
                        try data.write(to: URL(fileURLWithPath: fileNamePath))
                        metadata.isExtractFile = true
                        metadata.size = utilityFileSystem.getFileSize(filePath: fileNamePath)
                        metadata.creationDate = asset.creationDate as? NSDate ?? (Date() as NSDate)
                        metadata.date = asset.modificationDate as? NSDate ?? (Date() as NSDate)
                    } catch {}
                }

                if let result = database.getMetadataConflict(
                    account: session.account,
                    serverUrl: serverUrl,
                    fileNameView: fileName,
                    nativeFormat: metadata.nativeFormat
                ) {
                    metadata.fileName = result.fileName
                    metadatasUploadInConflict.append(metadata)
                } else {
                    metadatasNOConflict.append(metadata)
                }
            }

            for item in previewStore where item.tempURL != nil {

                guard let url = item.tempURL else { continue }

                let fileName = item.fileName.isEmpty
                    ? url.lastPathComponent
                    : item.fileName

                let ocId = UUID().uuidString

                let metadata = await NCManageDatabaseCreateMetadata().createMetadataAsync(
                    fileName: fileName,
                    ocId: ocId,
                    serverUrl: serverUrl,
                    session: session,
                    sceneIdentifier: controller?.sceneIdentifier
                )

                let toPath = utilityFileSystem.getDirectoryProviderStorageOcId(
                    ocId,
                    fileName: fileName,
                    userId: metadata.userId,
                    urlBase: metadata.urlBase
                )

                do {
                    let destinationURL = URL(fileURLWithPath: toPath)

                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }

                    try FileManager.default.copyItem(at: url, to: destinationURL)

                    metadata.size = utilityFileSystem.getFileSize(filePath: toPath)
                    metadata.session = NCNetworking.shared.sessionUploadBackground
                    metadata.sessionSelector = global.selectorUploadFile
                    metadata.status = global.metadataStatusWaitUpload
                    metadata.sessionDate = Date()

                } catch {
                    print("Copy error:", error)
                    continue
                }

                if let result = database.getMetadataConflict(
                    account: session.account,
                    serverUrl: serverUrl,
                    fileNameView: fileName,
                    nativeFormat: metadata.nativeFormat
                ) {
                    metadata.fileName = result.fileName
                    metadatasUploadInConflict.append(metadata)
                } else {
                    metadatasNOConflict.append(metadata)
                }
            }

            completion(metadatasNOConflict, metadatasUploadInConflict)
        }
    }
}
