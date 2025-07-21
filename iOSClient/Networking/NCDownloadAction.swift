// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import Queuer
import SVGKit
import Photos
import Alamofire

class NCDownloadAction: NSObject, UIDocumentInteractionControllerDelegate, NCSelectDelegate, NCTransferDelegate {
    static let shared = NCDownloadAction()

    var viewerQuickLook: NCViewerQuickLook?
    var documentController: UIDocumentInteractionController?
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let database = NCManageDatabase.shared
    let global = NCGlobal.shared
    var sceneIdentifier: String = ""

    override private init() { }

    func setup(sceneIdentifier: String) {
        self.sceneIdentifier = sceneIdentifier

        NCNetworking.shared.addDelegate(self)
    }

    // MARK: - Download

    func transferChange(status: String, metadata: tableMetadata, error: NKError) {
        DispatchQueue.main.async {
            switch status {
            /// DOWNLOADED
            case self.global.networkingStatusDownloaded:
                self.downloadedFile(metadata: metadata, error: error)
            default:
                break
            }
        }
    }

    func downloadedFile(metadata: tableMetadata, error: NKError) {
        guard error == .success else {
            return
        }
        /// Select UIWindowScene active in serverUrl
        var controller: NCMainTabBarController?
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if windowScenes.count == 1 {
            controller = UIApplication.shared.firstWindow?.rootViewController as? NCMainTabBarController
        } else if let sceneIdentifier = metadata.sceneIdentifier,
                  let tabBarController = SceneManager.shared.getController(sceneIdentifier: sceneIdentifier) {
            controller = tabBarController
        } else {
            for windowScene in windowScenes {
                if let rootViewController = windowScene.keyWindow?.rootViewController as? NCMainTabBarController,
                   rootViewController.currentServerUrl() == metadata.serverUrl {
                    controller = rootViewController
                    break
                }
            }
        }
        guard let controller else { return }

        switch metadata.sessionSelector {
        case NCGlobal.shared.selectorLoadFileQuickLook:

            let fileNamePath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)
            let fileNameTemp = NSTemporaryDirectory() + metadata.fileNameView
            let viewerQuickLook = NCViewerQuickLook(with: URL(fileURLWithPath: fileNameTemp), isEditingEnabled: true, metadata: metadata)
            if let image = UIImage(contentsOfFile: fileNamePath) {
                if let data = image.jpegData(compressionQuality: 1) {
                    do {
                        try data.write(to: URL(fileURLWithPath: fileNameTemp))
                    } catch {
                        return
                    }
                }
                let navigationController = UINavigationController(rootViewController: viewerQuickLook)
                navigationController.modalPresentationStyle = .fullScreen
                controller.present(navigationController, animated: true)
            } else {
                self.utilityFileSystem.copyFile(atPath: fileNamePath, toPath: fileNameTemp)
                controller.present(viewerQuickLook, animated: true)
            }

        case NCGlobal.shared.selectorLoadFileView:
            guard !isAppInBackground
            else {
                return
            }

            if metadata.contentType.contains("opendocument") && !self.utility.isTypeFileRichDocument(metadata) {
                self.openActivityViewController(selectedMetadata: [metadata], controller: controller, sender: nil)
            } else if metadata.classFile == NKTypeClassFile.compress.rawValue || metadata.classFile == NKTypeClassFile.unknow.rawValue {
                self.openActivityViewController(selectedMetadata: [metadata], controller: controller, sender: nil)
            } else {
                if let viewController = controller.currentViewController() {
                    let image = self.utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: NCGlobal.shared.previewExt1024)
                    NCViewer().view(viewController: viewController, metadata: metadata, image: image)
                }
            }

        case NCGlobal.shared.selectorOpenIn:
            guard !isAppInBackground
            else {
                return
            }

            self.openActivityViewController(selectedMetadata: [metadata], controller: controller, sender: nil)

        case NCGlobal.shared.selectorSaveAlbum:

            self.saveAlbum(metadata: metadata, controller: controller)

        case NCGlobal.shared.selectorSaveAsScan:

            self.saveAsScan(metadata: metadata, controller: controller)

        case NCGlobal.shared.selectorOpenDetail:
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterOpenMediaDetail, userInfo: ["ocId": metadata.ocId])

        default:
            let applicationHandle = NCApplicationHandle()
            applicationHandle.downloadedFile(selector: metadata.sessionSelector, metadata: metadata)
        }
    }

    // MARK: -

    func setMetadataAvalableOffline(_ metadata: tableMetadata, isOffline: Bool) async {
        if isOffline {
            if metadata.directory {
                await self.database.setDirectoryAsync(serverUrl: metadata.serverUrlFileName, offline: false, metadata: metadata)
                let predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND sessionSelector == %@ AND status == %d", metadata.account, metadata.serverUrlFileName, NCGlobal.shared.selectorSynchronizationOffline, NCGlobal.shared.metadataStatusWaitDownload)
                if let metadatas = await database.getMetadatasAsync(predicate: predicate) {
                    await database.clearMetadatasSessionAsync(metadatas: metadatas)
                }
            } else {
                await database.setOffLocalFileAsync(ocId: metadata.ocId)
            }
        } else if metadata.directory {
            await database.setDirectoryAsync(serverUrl: metadata.serverUrlFileName, offline: true, metadata: metadata)
            await self.database.cleanTablesOcIds(account: metadata.account)
            await NCNetworking.shared.synchronization(account: metadata.account, serverUrl: metadata.serverUrlFileName, metadatasInDownload: nil)
        } else {
            var metadatasSynchronizationOffline: [tableMetadata] = []
            metadatasSynchronizationOffline.append(metadata)
            if let metadata = await database.getMetadataLivePhotoAsync(metadata: metadata) {
                metadatasSynchronizationOffline.append(metadata)
            }
            await database.addLocalFileAsync(metadata: metadata, offline: true)
            for metadata in metadatasSynchronizationOffline {
                await database.setMetadataSessionInWaitDownloadAsync(ocId: metadata.ocId,
                                                                     session: NCNetworking.shared.sessionDownloadBackground,
                                                                     selector: NCGlobal.shared.selectorSynchronizationOffline)
            }
        }
    }

    // MARK: -

    @MainActor
    func viewerFile(account: String, fileId: String, viewController: UIViewController) async {
        var downloadRequest: DownloadRequest?
        let hud = NCHud(viewController.tabBarController?.view)

        if let metadata = await database.getMetadataFromFileIdAsync(fileId) {
            do {
                let attr = try FileManager.default.attributesOfItem(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))
                let fileSize = attr[FileAttributeKey.size] as? UInt64 ?? 0
                if fileSize > 0 {
                    NCViewer().view(viewController: viewController, metadata: metadata)
                    return
                }
            } catch {
                print("Error: \(error)")
            }
        }

        hud.initHudRing(tapToCancelDetailText: true) {
            if let request = downloadRequest {
                request.cancel()
            }
        }

        let resultsFile = await NextcloudKit.shared.getFileFromFileIdAsync(fileId: fileId, account: account)
        hud.dismiss()
        guard resultsFile.error == .success, let file = resultsFile.file else {
            NCContentPresenter().showError(error: resultsFile.error)
            return
        }

        let isDirectoryE2EE = await self.utilityFileSystem.isDirectoryE2EEAsync(file: file)
        let metadata = await self.database.convertFileToMetadataAsync(file, isDirectoryE2EE: isDirectoryE2EE)
        await self.database.addMetadataAsync(metadata)

        let fileNameLocalPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)

        if metadata.isAudioOrVideo {
            NCViewer().view(viewController: viewController, metadata: metadata)
            return
        }

        hud.show()
        let download = await NextcloudKit.shared.downloadAsync(serverUrlFileName: metadata.serverUrlFileName, fileNameLocalPath: fileNameLocalPath, account: account) { request in
            downloadRequest = request
        } taskHandler: { task in
            Task {
                await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                            sessionTaskIdentifier: task.taskIdentifier,
                                                            status: self.global.metadataStatusDownloading)
            }
        } progressHandler: { progress in
            hud.progress(progress.fractionCompleted)
        }

        hud.dismiss()
        await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                    session: "",
                                                    sessionTaskIdentifier: 0,
                                                    sessionError: "",
                                                    status: self.global.metadataStatusNormal,
                                                    etag: download.etag)

        if download.nkError == .success {
            await self.database.addLocalFileAsync(metadata: metadata)
            NCViewer().view(viewController: viewController, metadata: metadata)
        }
    }

    // MARK: -

    func openShare(viewController: UIViewController, metadata: tableMetadata, page: NCBrandOptions.NCInfoPagingTab) {
        var page = page
        let capabilities = NCNetworking.shared.capabilities[metadata.account] ?? NKCapabilities.Capabilities()

        NCActivityIndicator.shared.start(backgroundView: viewController.view)
        NCNetworking.shared.readFile(serverUrlFileName: metadata.serverUrlFileName, account: metadata.account, queue: .main) { _, metadata, error in
            NCActivityIndicator.shared.stop()

            if let metadata = metadata, error == .success {
                var pages: [NCBrandOptions.NCInfoPagingTab] = []
                let shareNavigationController = UIStoryboard(name: "NCShare", bundle: nil).instantiateInitialViewController() as? UINavigationController
                let shareViewController = shareNavigationController?.topViewController as? NCSharePaging

                for value in NCBrandOptions.NCInfoPagingTab.allCases {
                    pages.append(value)
                }

                if capabilities.activity.isEmpty, let idx = pages.firstIndex(of: .activity) {
                    pages.remove(at: idx)
                }
                if !metadata.isSharable(), let idx = pages.firstIndex(of: .sharing) {
                    pages.remove(at: idx)
                }

                (pages, page) = NCApplicationHandle().filterPages(pages: pages, page: page, metadata: metadata)

                shareViewController?.pages = pages
                shareViewController?.metadata = metadata

                if pages.contains(page) {
                    shareViewController?.page = page
                } else if let page = pages.first {
                    shareViewController?.page = page
                } else {
                    return
                }

                shareNavigationController?.modalPresentationStyle = .formSheet
                if let shareNavigationController = shareNavigationController {
                    viewController.present(shareNavigationController, animated: true, completion: nil)
                }
            }
        }
    }

    // MARK: - Open Activity [Share] ...

    func openActivityViewController(selectedMetadata: [tableMetadata], controller: NCMainTabBarController?, sender: Any?) {
        guard let controller else { return }
        let metadatas = selectedMetadata.filter({ !$0.directory })
        var urls: [URL] = []
        var downloadMetadata: [(tableMetadata, URL)] = []

        for metadata in metadatas {
            let fileURL = URL(fileURLWithPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))
            if utilityFileSystem.fileProviderStorageExists(metadata) {
                urls.append(fileURL)
            } else {
                downloadMetadata.append((metadata, fileURL))
            }
        }

        let processor = ParallelWorker(n: 5, titleKey: "_downloading_", totalTasks: downloadMetadata.count, controller: controller)
        for (metadata, url) in downloadMetadata {
            processor.execute { completion in
                Task {
                    guard let metadata = await self.database.setMetadataSessionInWaitDownloadAsync(ocId: metadata.ocId,
                                                                                                   session: NCNetworking.shared.sessionDownload,
                                                                                                   selector: "",
                                                                                                   sceneIdentifier: controller.sceneIdentifier) else {
                        return completion()
                    }

                    NCNetworking.shared.download(metadata: metadata) {
                    } progressHandler: { progress in
                        processor.hud.progress(progress.fractionCompleted)
                    } completion: { _, _ in
                        if self.utilityFileSystem.fileProviderStorageExists(metadata) { urls.append(url) }
                        completion()
                    }
                }
            }
        }

        processor.completeWork {
            guard !urls.isEmpty else { return }
            let activityViewController = UIActivityViewController(activityItems: urls, applicationActivities: nil)

            // iPad
            if let popover = activityViewController.popoverPresentationController {
                if let view = sender as? UIView {
                    popover.sourceView = view
                    popover.sourceRect = view.bounds
                } else {
                    popover.sourceView = controller.view
                    popover.sourceRect = CGRect(x: controller.view.bounds.midX,
                                                y: controller.view.bounds.midY,
                                                width: 0,
                                                height: 0)
                    popover.permittedArrowDirections = []
                }
            }

            controller.present(activityViewController, animated: true)
        }
    }

    // MARK: - Save as scan

    func saveAsScan(metadata: tableMetadata, controller: NCMainTabBarController?) {
        let fileNamePath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)
        let fileNameDestination = utilityFileSystem.createFileName("scan.png", fileDate: Date(), fileType: PHAssetMediaType.image, notUseMask: true)
        let fileNamePathDestination = utilityFileSystem.directoryScan + "/" + fileNameDestination

        utilityFileSystem.copyFile(atPath: fileNamePath, toPath: fileNamePathDestination)

        if let navigationController = UIStoryboard(name: "NCScan", bundle: nil).instantiateInitialViewController() {
            navigationController.modalPresentationStyle = UIModalPresentationStyle.pageSheet
            let viewController = navigationController.presentedViewController as? NCScan
            viewController?.serverUrl = controller?.currentServerUrl()
            viewController?.controller = controller
            controller?.present(navigationController, animated: true, completion: nil)
        }
    }

    // MARK: - Save photo

    func saveAlbum(metadata: tableMetadata, controller: NCMainTabBarController?) {
        let fileNamePath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)

        NCAskAuthorization().askAuthorizationPhotoLibrary(controller: controller) { hasPermission in
            guard hasPermission else {
                let error = NKError(errorCode: NCGlobal.shared.errorFileNotSaved, errorDescription: "_access_photo_not_enabled_msg_")
                return NCContentPresenter().messageNotification("_access_photo_not_enabled_", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error)
            }

            let errorSave = NKError(errorCode: NCGlobal.shared.errorFileNotSaved, errorDescription: "_file_not_saved_cameraroll_")

            do {
                if metadata.isImage {
                    let data = try Data(contentsOf: URL(fileURLWithPath: fileNamePath))
                    PHPhotoLibrary.shared().performChanges({
                        let assetRequest = PHAssetCreationRequest.forAsset()
                        assetRequest.addResource(with: .photo, data: data, options: nil)
                    }) { success, _ in
                        if !success {
                            NCContentPresenter().messageNotification("_save_selected_files_", error: errorSave, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error)
                        }
                    }
                } else if metadata.isVideo {
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: fileNamePath))
                    }) { success, _ in
                        if !success {
                            NCContentPresenter().messageNotification("_save_selected_files_", error: errorSave, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error)
                        }
                    }
                } else {
                    NCContentPresenter().messageNotification("_save_selected_files_", error: errorSave, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error)
                    return
                }
            } catch {
                NCContentPresenter().messageNotification("_save_selected_files_", error: errorSave, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error)
            }
        }
    }

    // MARK: - Copy & Paste

    func pastePasteboard(serverUrl: String, account: String, controller: NCMainTabBarController?) async {
        var fractionCompleted: Float = 0
        let processor = ParallelWorker(n: 5, titleKey: "_status_uploading_", totalTasks: nil, controller: controller)

        func uploadPastePasteboard(fileName: String, serverUrlFileName: String, fileNameLocalPath: String, serverUrl: String, completion: @escaping () -> Void) {
            NextcloudKit.shared.upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, account: account) { _ in
            } progressHandler: { progress in
                if Float(progress.fractionCompleted) > fractionCompleted || fractionCompleted == 0 {
                    processor.hud.progress(progress.fractionCompleted)
                    fractionCompleted = Float(progress.fractionCompleted)
                }
            } completionHandler: { account, ocId, etag, _, _, _, error in
                if error == .success && etag != nil && ocId != nil {
                    let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId!, fileNameView: fileName)
                    self.utilityFileSystem.moveFile(atPath: fileNameLocalPath, toPath: toPath)
                    self.database.addLocalFile(account: account, etag: etag!, ocId: ocId!, fileName: fileName)
                    NCNetworking.shared.notifyAllDelegates { delegate in
                        delegate.transferRequestData(serverUrl: serverUrl)
                    }
                } else {
                    NCContentPresenter().showError(error: error)
                }
                fractionCompleted = 0
                completion()
            }
        }

        for (index, items) in UIPasteboard.general.items.enumerated() {
            for item in items {
                let results = await NKFilePropertyResolver().resolve(inUTI: item.key ,account: account)
                guard let data = UIPasteboard.general.data(forPasteboardType: item.key, inItemSet: IndexSet([index]))?.first else {
                    continue
                }
                let fileName = results.name + "_" + NCKeychain().incrementalNumber + "." + results.ext
                let serverUrlFileName = serverUrl + "/" + fileName
                let ocIdUpload = UUID().uuidString
                let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(ocIdUpload, fileNameView: fileName)
                do { try data.write(to: URL(fileURLWithPath: fileNameLocalPath)) } catch { continue }
                processor.execute { completion in
                    uploadPastePasteboard(fileName: fileName, serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, serverUrl: serverUrl, completion: completion)
                }
            }
        }
        processor.completeWork()
    }

    // MARK: -

    func openFileViewInFolder(serverUrl: String, fileNameBlink: String?, fileNameOpen: String?, sceneIdentifier: String) {
        guard let controller = SceneManager.shared.getController(sceneIdentifier: sceneIdentifier),
              let navigationController = controller.viewControllers?.first as? UINavigationController
        else { return }
        let session = NCSession.shared.getSession(controller: controller)
        var serverUrlPush = self.utilityFileSystem.getHomeServer(session: session)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            navigationController.popToRootViewController(animated: false)
            controller.selectedIndex = 0
            if serverUrlPush == serverUrl,
               let viewController = navigationController.topViewController as? NCFiles {
                viewController.blinkCell(fileName: fileNameBlink)
                viewController.openFile(fileName: fileNameOpen)
                return
            }

            let diffDirectory = serverUrl.replacingOccurrences(of: serverUrlPush, with: "")
            var subDirs = diffDirectory.split(separator: "/")

            while serverUrlPush != serverUrl, !subDirs.isEmpty {

                guard let dir = subDirs.first else { return }
                serverUrlPush = serverUrlPush + "/" + dir

                if let viewController = controller.navigationCollectionViewCommon.first(where: { $0.navigationController == navigationController && $0.serverUrl == serverUrlPush})?.viewController as? NCFiles, viewController.isViewLoaded {
                    viewController.fileNameBlink = fileNameBlink
                    viewController.fileNameOpen = fileNameOpen
                    navigationController.pushViewController(viewController, animated: false)
                } else {
                    if let viewController: NCFiles = UIStoryboard(name: "NCFiles", bundle: nil).instantiateInitialViewController() as? NCFiles {
                        viewController.serverUrl = serverUrlPush
                        viewController.titleCurrentFolder = String(dir)
                        viewController.navigationItem.backButtonTitle = viewController.titleCurrentFolder

                        controller.navigationCollectionViewCommon.append(NavigationCollectionViewCommon(serverUrl: serverUrlPush, navigationController: navigationController, viewController: viewController))

                        if serverUrlPush == serverUrl {
                            viewController.fileNameBlink = fileNameBlink
                            viewController.fileNameOpen = fileNameOpen
                        }
                        navigationController.pushViewController(viewController, animated: false)
                    }
                }
                subDirs.remove(at: 0)
            }
        }
    }

    // MARK: - NCSelect + Delegate

    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool, session: NCSession.Session) {
        if let serverUrl, !items.isEmpty {
            if copy {
                for case let metadata as tableMetadata in items {
                    if metadata.status != NCGlobal.shared.metadataStatusNormal, metadata.status != NCGlobal.shared.metadataStatusWaitCopy {
                        continue
                    }

                    NCNetworking.shared.copyMetadata(metadata, serverUrlTo: serverUrl, overwrite: overwrite)
                }

            } else if move {
                for case let metadata as tableMetadata in items {
                    if metadata.status != NCGlobal.shared.metadataStatusNormal, metadata.status != NCGlobal.shared.metadataStatusWaitMove {
                        continue
                    }

                    NCNetworking.shared.moveMetadata(metadata, serverUrlTo: serverUrl, overwrite: overwrite)
                }
            }
        }
    }

    func openSelectView(items: [tableMetadata], controller: NCMainTabBarController?) {
        let session = NCSession.shared.getSession(controller: controller)
        let navigationController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateInitialViewController() as? UINavigationController
        let topViewController = navigationController?.topViewController as? NCSelect
        var listViewController = [NCSelect]()
        var copyItems: [tableMetadata] = []
        let capabilities = NCNetworking.shared.capabilities[controller?.account ?? ""] ?? NKCapabilities.Capabilities()

        for item in items {
            if let fileNameError = FileNameValidator.checkFileName(item.fileNameView, account: controller?.account, capabilities: capabilities) {
                controller?.present(UIAlertController.warning(message: "\(fileNameError.errorDescription) \(NSLocalizedString("_please_rename_file_", comment: ""))"), animated: true)
                return
            }
            copyItems.append(item)
        }

        let homeUrl = utilityFileSystem.getHomeServer(session: session)
        var serverUrl = copyItems[0].serverUrl

        // Setup view controllers such that the current view is of the same directory the items to be copied are in
        while true {
            // If not in the topmost directory, create a new view controller and set correct title.
            // If in the topmost directory, use the default view controller as the base.
            var viewController: NCSelect?
            if serverUrl != homeUrl {
                viewController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateViewController(withIdentifier: "NCSelect.storyboard") as? NCSelect
                if viewController == nil {
                    return
                }
                viewController!.titleCurrentFolder = (serverUrl as NSString).lastPathComponent
            } else {
                viewController = topViewController
            }
            guard let vc = viewController else { return }

            vc.delegate = self
            vc.typeOfCommandView = .copyMove
            vc.items = copyItems
            vc.serverUrl = serverUrl
            vc.session = session

            vc.navigationItem.backButtonTitle = vc.titleCurrentFolder
            listViewController.insert(vc, at: 0)

            if serverUrl != homeUrl {
                if let path = utilityFileSystem.deleteLastPath(serverUrlPath: serverUrl) {
                    serverUrl = path
                }
            } else {
                break
            }
        }

        navigationController?.setViewControllers(listViewController, animated: false)
        navigationController?.modalPresentationStyle = .formSheet

        if let navigationController = navigationController {
            controller?.present(navigationController, animated: true, completion: nil)
        }
    }
}
