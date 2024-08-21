//
//  NCActionCenter.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 19/04/2020.
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
import Queuer
import JGProgressHUD
import SVGKit
import Photos
import Alamofire

class NCActionCenter: NSObject, UIDocumentInteractionControllerDelegate, NCSelectDelegate {
    public static let shared: NCActionCenter = {
        let instance = NCActionCenter()
        NotificationCenter.default.addObserver(instance, selector: #selector(downloadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile), object: nil)
        NotificationCenter.default.addObserver(instance, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)
        return instance
    }()

    var viewerQuickLook: NCViewerQuickLook?
    var documentController: UIDocumentInteractionController?
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let appDelegate = UIApplication.shared.delegate as? AppDelegate

    // MARK: - Download

    @objc func downloadedFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let selector = userInfo["selector"] as? String,
              let error = userInfo["error"] as? NKError,
              let account = userInfo["account"] as? String,
              account == appDelegate?.account
        else { return }

        guard error == .success else {
            // File do not exists on server, remove in local
            if error.errorCode == NCGlobal.shared.errorResourceNotFound || error.errorCode == NCGlobal.shared.errorBadServerResponse {
                do {
                    try FileManager.default.removeItem(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(ocId))
                } catch { }
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocId))
                NCManageDatabase.shared.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", ocId))
            } else {
                NCContentPresenter().messageNotification("_download_file_", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
            }
            return
        }
        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) else { return }

        DispatchQueue.main.async {

            // Select UIWindowScene active in serverUrl
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

            switch selector {
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

                guard UIApplication.shared.applicationState == .active else { return }
                if metadata.contentType.contains("opendocument") && !self.utility.isTypeFileRichDocument(metadata) {
                    self.openDocumentController(metadata: metadata, controller: controller)
                } else if metadata.classFile == NKCommon.TypeClassFile.compress.rawValue || metadata.classFile == NKCommon.TypeClassFile.unknow.rawValue {
                    self.openDocumentController(metadata: metadata, controller: controller)
                } else {
                    if let viewController = controller.currentViewController() {
                        let imageIcon = UIImage(contentsOfFile: self.utilityFileSystem.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
                        NCViewer().view(viewController: viewController, metadata: metadata, metadatas: [metadata], imageIcon: imageIcon)
                    }
                }

            case NCGlobal.shared.selectorOpenIn:

                if UIApplication.shared.applicationState == .active {
                    self.openDocumentController(metadata: metadata, controller: controller)
                }

            case NCGlobal.shared.selectorSaveAlbum:

                self.saveAlbum(metadata: metadata, controller: controller)

            case NCGlobal.shared.selectorSaveAsScan:

                self.saveAsScan(metadata: metadata, controller: controller)

            case NCGlobal.shared.selectorOpenDetail:
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterOpenMediaDetail, userInfo: ["ocId": metadata.ocId])

            default:
                let applicationHandle = NCApplicationHandle()
                applicationHandle.downloadedFile(selector: selector, metadata: metadata)
            }
        }
    }

    func setMetadataAvalableOffline(_ metadata: tableMetadata, isOffline: Bool) {
        let serverUrl = metadata.serverUrl + "/" + metadata.fileName
        if isOffline {
            if metadata.directory {
                NCManageDatabase.shared.setDirectory(serverUrl: serverUrl, offline: false, metadata: metadata)
                if let metadatas = NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND sessionSelector == %@ AND status == %d", metadata.account, serverUrl, NCGlobal.shared.selectorSynchronizationOffline, NCGlobal.shared.metadataStatusWaitDownload)) {
                    NCManageDatabase.shared.clearMetadataSession(metadatas: metadatas)
                }
            } else {
                NCManageDatabase.shared.setOffLocalFile(ocId: metadata.ocId)
            }
        } else if metadata.directory {
            NCManageDatabase.shared.setDirectory(serverUrl: serverUrl, offline: true, metadata: metadata)
            NCNetworking.shared.synchronization(account: metadata.account, serverUrl: serverUrl, add: true)
        } else {
            var metadatasSynchronizationOffline: [tableMetadata] = []
            metadatasSynchronizationOffline.append(metadata)
            if let metadata = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
                metadatasSynchronizationOffline.append(metadata)
            }
            NCManageDatabase.shared.addLocalFile(metadata: metadata, offline: true)
            NCManageDatabase.shared.setMetadatasSessionInWaitDownload(metadatas: metadatasSynchronizationOffline,
                                                                      session: NCNetworking.shared.sessionDownloadBackground,
                                                                      selector: NCGlobal.shared.selectorSynchronizationOffline)
        }
    }

    func viewerFile(account: String, fileId: String, viewController: UIViewController) {

        guard let hudView = viewController.tabBarController?.view else { return }
        var downloadRequest: DownloadRequest?

        if let metadata = NCManageDatabase.shared.getMetadataFromFileId(fileId) {
            do {
                let attr = try FileManager.default.attributesOfItem(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))
                let fileSize = attr[FileAttributeKey.size] as? UInt64 ?? 0
                if fileSize > 0 {
                    NCViewer().view(viewController: viewController, metadata: metadata, metadatas: [metadata], imageIcon: nil)
                    return
                }
            } catch {
                print("Error: \(error)")
            }
        }

        let hud = JGProgressHUD()
        hud.indicatorView = JGProgressHUDRingIndicatorView()
        if let indicatorView = hud.indicatorView as? JGProgressHUDRingIndicatorView {
            indicatorView.ringWidth = 1.5
            indicatorView.ringColor = NCBrandColor.shared.brandElement
        }
        hud.tapOnHUDViewBlock = { _ in
            if let request = downloadRequest {
                request.cancel()
            }
        }
        hud.show(in: hudView)

        NextcloudKit.shared.getFileFromFileId(fileId: fileId, account: account) { account, file, _, error in

            hud.dismiss()
            if error != .success {
                NCContentPresenter().showError(error: error)
            } else if let file = file {

                let isDirectoryE2EE = self.utilityFileSystem.isDirectoryE2EE(file: file)
                let metadata = NCManageDatabase.shared.convertFileToMetadata(file, isDirectoryE2EE: isDirectoryE2EE)
                NCManageDatabase.shared.addMetadata(metadata)

                let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
                let fileNameLocalPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)

                if metadata.isAudioOrVideo {
                    NCViewer().view(viewController: viewController, metadata: metadata, metadatas: [metadata], imageIcon: nil)
                } else {
                    hud.show(in: hudView)
                    NextcloudKit.shared.download(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, account: account, requestHandler: { request in
                        downloadRequest = request
                    }, taskHandler: { _ in
                    }, progressHandler: { progress in
                        hud.progress = Float(progress.fractionCompleted)
                    }) { accountDownload, _, _, _, _, _, error in
                        hud.dismiss()
                        if account == accountDownload && error == .success {
                            NCManageDatabase.shared.addLocalFile(metadata: metadata)
                            NCViewer().view(viewController: viewController, metadata: metadata, metadatas: [metadata], imageIcon: nil)
                        }
                    }
                }
            } else {
                let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_file_not_found_")
                NCContentPresenter().showError(error: error)
            }
        }
    }

    // MARK: - Upload

    @objc func uploadedFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError,
              let account = userInfo["account"] as? String,
              account == self.appDelegate?.account
        else { return }

        if error != .success, error.errorCode != NSURLErrorCancelled, error.errorCode != NCGlobal.shared.errorRequestExplicityCancelled {
            NCContentPresenter().messageNotification("_upload_file_", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
        }
    }

    // MARK: -

    func openShare(viewController: UIViewController, metadata: tableMetadata, page: NCBrandOptions.NCInfoPagingTab) {

        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        var page = page

        NCActivityIndicator.shared.start(backgroundView: viewController.view)
        NCNetworking.shared.readFile(serverUrlFileName: serverUrlFileName, account: metadata.account, queue: .main) { _, metadata, error in

            NCActivityIndicator.shared.stop()

            if let metadata = metadata, error == .success {

                var pages: [NCBrandOptions.NCInfoPagingTab] = []

                let shareNavigationController = UIStoryboard(name: "NCShare", bundle: nil).instantiateInitialViewController() as? UINavigationController
                let shareViewController = shareNavigationController?.topViewController as? NCSharePaging

                for value in NCBrandOptions.NCInfoPagingTab.allCases {
                    pages.append(value)
                }

                if NCGlobal.shared.capabilityActivity.isEmpty, let idx = pages.firstIndex(of: .activity) {
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

    // MARK: - Open in ...

    func openDocumentController(metadata: tableMetadata, controller: NCMainTabBarController?) {

        guard let mainTabBarController = controller,
              let mainTabBar = mainTabBarController.tabBar as? NCMainTabBar else { return }
        let fileURL = URL(fileURLWithPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))

        documentController = UIDocumentInteractionController(url: fileURL)
        documentController?.presentOptionsMenu(from: mainTabBar.menuRect, in: mainTabBar, animated: true)
    }

    func openActivityViewController(selectedMetadata: [tableMetadata], controller: NCMainTabBarController?) {
        guard let controller,
              let mainTabBar = controller.tabBar as? NCMainTabBar else { return }
        let metadatas = selectedMetadata.filter({ !$0.directory })
        var items: [URL] = []
        var downloadMetadata: [(tableMetadata, URL)] = []

        for metadata in metadatas {
            let fileURL = URL(fileURLWithPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))
            if utilityFileSystem.fileProviderStorageExists(metadata) {
                items.append(fileURL)
            } else {
                downloadMetadata.append((metadata, fileURL))
            }
        }

        let processor = ParallelWorker(n: 5, titleKey: "_downloading_", totalTasks: downloadMetadata.count, hudView: controller.view)
        for (metadata, url) in downloadMetadata {
            processor.execute { completion in
                guard let metadata = NCManageDatabase.shared.setMetadatasSessionInWaitDownload(metadatas: [metadata],
                                                                                               session: NextcloudKit.shared.nkCommonInstance.sessionIdentifierDownload,
                                                                                               selector: "",
                                                                                               sceneIdentifier: controller.sceneIdentifier) else { return completion() }
                NCNetworking.shared.download(metadata: metadata, withNotificationProgressTask: false) {
                } progressHandler: { progress in
                    processor.hud?.progress = Float(progress.fractionCompleted)
                } completion: { _, _ in
                    if self.utilityFileSystem.fileProviderStorageExists(metadata) { items.append(url) }
                    completion()
                }
            }
        }

        processor.completeWork {
            guard !items.isEmpty else { return }
            let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
            activityViewController.popoverPresentationController?.permittedArrowDirections = .any
            activityViewController.popoverPresentationController?.sourceView = mainTabBar
            activityViewController.popoverPresentationController?.sourceRect = mainTabBar.menuRect
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
            controller?.present(navigationController, animated: true, completion: nil)
        }
    }

    // MARK: - Save photo

    func saveAlbum(metadata: tableMetadata, controller: NCMainTabBarController?) {
        let fileNamePath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)

        NCAskAuthorization().askAuthorizationPhotoLibrary(viewController: controller) { hasPermission in
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

    func pastePasteboard(serverUrl: String, account: String, hudView: UIView?) {
        var fractionCompleted: Float = 0
        let processor = ParallelWorker(n: 5, titleKey: "_uploading_", totalTasks: nil, hudView: hudView)

        func uploadPastePasteboard(fileName: String, serverUrlFileName: String, fileNameLocalPath: String, serverUrl: String, completion: @escaping () -> Void) {
            NextcloudKit.shared.upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, account: account) { request in
                NCNetworking.shared.uploadRequest[fileNameLocalPath] = request
            } progressHandler: { progress in
                if Float(progress.fractionCompleted) > fractionCompleted || fractionCompleted == 0 {
                    processor.hud?.progress = Float(progress.fractionCompleted)
                    fractionCompleted = Float(progress.fractionCompleted)
                }
            } completionHandler: { account, ocId, etag, _, _, _, afError, error in
                NCNetworking.shared.uploadRequest.removeValue(forKey: fileNameLocalPath)
                if error == .success && etag != nil && ocId != nil {
                    let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId!, fileNameView: fileName)
                    self.utilityFileSystem.moveFile(atPath: fileNameLocalPath, toPath: toPath)
                    NCManageDatabase.shared.addLocalFile(account: account, etag: etag!, ocId: ocId!, fileName: fileName)
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSourceNetwork)
                } else if afError?.isExplicitlyCancelledError ?? false {
                    print("cancel")
                } else {
                    NCContentPresenter().showError(error: error)
                }
                fractionCompleted = 0
                completion()
            }
        }

        for (index, items) in UIPasteboard.general.items.enumerated() {
            for item in items {
                let results = NextcloudKit.shared.nkCommonInstance.getFileProperties(inUTI: item.key as CFString)
                guard !results.ext.isEmpty,
                      let data = UIPasteboard.general.data(forPasteboardType: item.key, inItemSet: IndexSet([index]))?.first
                else { continue }
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
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let controller = SceneManager.shared.getController(sceneIdentifier: sceneIdentifier),
              let navigationController = controller.viewControllers?.first as? UINavigationController
        else { return }
        var serverUrlPush = self.utilityFileSystem.getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId)

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
                        viewController.isRoot = false
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

    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool) {
        if let serverUrl, !items.isEmpty {
            if copy {
                Task {
                    var error = NKError()
                    var ocId: [String] = []
                    for case let metadata as tableMetadata in items where error == .success {
                        error = await NCNetworking.shared.copyMetadata(metadata, serverUrlTo: serverUrl, overwrite: overwrite)
                        if error == .success {
                            ocId.append(metadata.ocId)
                        }
                    }
                    if error != .success {
                        NCContentPresenter().showError(error: error)
                    }
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterCopyFile, userInfo: ["ocId": ocId, "error": error])
                }
            } else {
                Task {
                    var error = NKError()
                    var ocId: [String] = []
                    for case let metadata as tableMetadata in items where error == .success {
                        error = await NCNetworking.shared.moveMetadata(metadata, serverUrlTo: serverUrl, overwrite: overwrite)
                        if error == .success {
                            ocId.append(metadata.ocId)
                        }
                    }
                    if error != .success {
                        NCContentPresenter().showError(error: error)
                    }
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterMoveFile, userInfo: ["ocId": ocId, "error": error])
                }
            }
        }
    }

    func openSelectView(items: [tableMetadata], controller: NCMainTabBarController?) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

        let navigationController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateInitialViewController() as? UINavigationController
        let topViewController = navigationController?.topViewController as? NCSelect
        var listViewController = [NCSelect]()

        var copyItems: [tableMetadata] = []
        for item in items {
            if let fileNameError = FileNameValidator.shared.checkFileName(item.fileNameView) {
                controller?.present(UIAlertController.warning(message: "\(fileNameError.errorDescription) \(NSLocalizedString("_please_rename_file_", comment: ""))"), animated: true)

                return
            }

            copyItems.append(item)
        }

        let homeUrl = utilityFileSystem.getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId)
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
