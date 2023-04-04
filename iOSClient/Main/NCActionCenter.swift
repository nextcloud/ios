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

class NCActionCenter: NSObject, UIDocumentInteractionControllerDelegate, NCSelectDelegate {
    public static let shared: NCActionCenter = {
        let instance = NCActionCenter()
        NotificationCenter.default.addObserver(instance, selector: #selector(downloadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile), object: nil)
        NotificationCenter.default.addObserver(instance, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)
        return instance
    }()

    var viewerQuickLook: NCViewerQuickLook?
    var documentController: UIDocumentInteractionController?

    // MARK: - Download

    @objc func downloadedFile(_ notification: NSNotification) {

        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let selector = userInfo["selector"] as? String,
              let error = userInfo["error"] as? NKError,
              let account = userInfo["account"] as? String,
              account == appDelegate.account
        else { return }

        guard error == .success else {
            // File do not exists on server, remove in local
            if error.errorCode == NCGlobal.shared.errorResourceNotFound || error.errorCode == NCGlobal.shared.errorBadServerResponse {
                do {
                    try FileManager.default.removeItem(atPath: CCUtility.getDirectoryProviderStorageOcId(ocId))
                } catch { }
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocId))
                NCManageDatabase.shared.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", ocId))
            } else {
                NCContentPresenter.shared.messageNotification("_download_file_", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
            }
            return
        }
        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) else { return }

        switch selector {
        case NCGlobal.shared.selectorLoadFileQuickLook:
            let fileNamePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
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
                appDelegate.window?.rootViewController?.present(navigationController, animated: true)
            } else {
                CCUtility.copyFile(atPath: fileNamePath, toPath: fileNameTemp)
                appDelegate.window?.rootViewController?.present(viewerQuickLook, animated: true)
            }

        case NCGlobal.shared.selectorLoadFileView:
            guard UIApplication.shared.applicationState == .active else { break }

            if metadata.contentType.contains("opendocument") && !NCUtility.shared.isRichDocument(metadata) {
                self.openDocumentController(metadata: metadata)
            } else if metadata.classFile == NKCommon.TypeClassFile.compress.rawValue || metadata.classFile == NKCommon.TypeClassFile.unknow.rawValue {
                self.openDocumentController(metadata: metadata)
            } else {
                if let viewController = appDelegate.activeViewController {
                    let imageIcon = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
                    NCViewer.shared.view(viewController: viewController, metadata: metadata, metadatas: [metadata], imageIcon: imageIcon)
                }
            }

        case NCGlobal.shared.selectorOpenIn:
            if UIApplication.shared.applicationState == .active {
                self.openDocumentController(metadata: metadata)
            }

        case NCGlobal.shared.selectorLoadOffline:
            NCManageDatabase.shared.setLocalFile(ocId: metadata.ocId, offline: true)

        case NCGlobal.shared.selectorPrint:
            // waiting close menu
            // https://github.com/nextcloud/ios/issues/2278
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.printDocument(metadata: metadata)
            }

        case NCGlobal.shared.selectorSaveAlbum:
            saveAlbum(metadata: metadata)

        case NCGlobal.shared.selectorSaveAlbumLivePhotoIMG, NCGlobal.shared.selectorSaveAlbumLivePhotoMOV:

            var metadata = metadata
            var metadataMOV = metadata
            guard let metadataTMP = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) else { break }

            if selector == NCGlobal.shared.selectorSaveAlbumLivePhotoIMG {
                metadataMOV = metadataTMP
            }

            if selector == NCGlobal.shared.selectorSaveAlbumLivePhotoMOV {
                metadata = metadataTMP
            }

            if CCUtility.fileProviderStorageExists(metadata) && CCUtility.fileProviderStorageExists(metadataMOV) {
                saveLivePhotoToDisk(metadata: metadata, metadataMov: metadataMOV)
            }

        case NCGlobal.shared.selectorSaveAsScan:
            saveAsScan(metadata: metadata)

        case NCGlobal.shared.selectorOpenDetail:
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterOpenMediaDetail, userInfo: ["ocId": metadata.ocId])

        default:
            let applicationHandle = NCApplicationHandle()
            applicationHandle.downloadedFile(selector: selector, metadata: metadata)
        }
    }

    func setMetadataAvalableOffline(_ metadata: tableMetadata, isOffline: Bool) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let serverUrl = metadata.serverUrl + "/" + metadata.fileName
        if isOffline {
            if metadata.directory {
                NCManageDatabase.shared.setDirectory(serverUrl: serverUrl, offline: false, account: appDelegate.account)
            } else {
                NCManageDatabase.shared.setLocalFile(ocId: metadata.ocId, offline: false)
            }
        } else if metadata.directory {
            NCManageDatabase.shared.setDirectory(serverUrl: serverUrl, offline: true, account: appDelegate.account)
            NCOperationQueue.shared.synchronizationMetadata(metadata, selector: NCGlobal.shared.selectorDownloadAllFile)
        } else {
            NCNetworking.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorLoadOffline) { _, _ in }
            if let metadataLivePhoto = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
                NCNetworking.shared.download(metadata: metadataLivePhoto, selector: NCGlobal.shared.selectorLoadOffline) { _, _ in }
            }
        }
    }

    // MARK: - Upload

    @objc func uploadedFile(_ notification: NSNotification) {

        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError,
              let account = userInfo["account"] as? String,
              account == appDelegate.account
        else { return }

        if error != .success, error.errorCode != NSURLErrorCancelled, error.errorCode != NCGlobal.shared.errorRequestExplicityCancelled {
            NCContentPresenter.shared.messageNotification("_upload_file_", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
        }
    }

    // MARK: -

    func openShare(viewController: UIViewController, metadata: tableMetadata, indexPage: NCGlobal.NCSharePagingIndex) {

        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        NCActivityIndicator.shared.start(backgroundView: viewController.view)
        NCNetworking.shared.readFile(serverUrlFileName: serverUrlFileName, queue: .main) { _, metadata, error in
            NCActivityIndicator.shared.stop()
            if let metadata = metadata, error == .success {
                let shareNavigationController = UIStoryboard(name: "NCShare", bundle: nil).instantiateInitialViewController() as? UINavigationController
                let shareViewController = shareNavigationController?.topViewController as? NCSharePaging

                shareViewController?.metadata = metadata
                shareViewController?.indexPage = indexPage

                shareNavigationController?.modalPresentationStyle = .formSheet
                if let shareNavigationController = shareNavigationController {
                    viewController.present(shareNavigationController, animated: true, completion: nil)
                }
            }
        }
    }

    // MARK: - Open in ...

    func openDocumentController(metadata: tableMetadata) {

        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let mainTabBar = appDelegate.mainTabBar else { return }
        let fileURL = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))

        documentController = UIDocumentInteractionController(url: fileURL)
        documentController?.presentOptionsMenu(from: mainTabBar.menuRect, in: mainTabBar, animated: true)
    }

    func openActivityViewController(selectedMetadata: [tableMetadata]) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

        let metadatas = selectedMetadata.filter({ !$0.directory })
        var items: [URL] = []
        var downloadMetadata: [(tableMetadata, URL)] = []

        for metadata in metadatas {
            let fileURL = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))
            if CCUtility.fileProviderStorageExists(metadata) {
                items.append(fileURL)
            } else {
                downloadMetadata.append((metadata, fileURL))
            }
        }

        let processor = ParallelWorker(n: 5, titleKey: "_downloading_", totalTasks: downloadMetadata.count, hudView: appDelegate.window?.rootViewController?.view)
        for (metadata, url) in downloadMetadata {
            processor.execute { completion in
                NCNetworking.shared.download(metadata: metadata, selector: "", completion: { _, _ in
                    if CCUtility.fileProviderStorageExists(metadata) { items.append(url) }
                    completion()
                })
            }
        }

        processor.completeWork {
            guard !items.isEmpty, let mainTabBar = appDelegate.mainTabBar else { return }
            let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
            activityViewController.popoverPresentationController?.permittedArrowDirections = .any
            activityViewController.popoverPresentationController?.sourceView = mainTabBar
            activityViewController.popoverPresentationController?.sourceRect = mainTabBar.menuRect
            appDelegate.window?.rootViewController?.present(activityViewController, animated: true)
        }
    }

    // MARK: - Save as scan

    func saveAsScan(metadata: tableMetadata) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

        let fileNamePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
        let fileNameDestination = CCUtility.createFileName("scan.png", fileDate: Date(), fileType: PHAssetMediaType.image, keyFileName: NCGlobal.shared.keyFileNameMask, keyFileNameType: NCGlobal.shared.keyFileNameType, keyFileNameOriginal: NCGlobal.shared.keyFileNameOriginal, forcedNewFileName: true)!
        let fileNamePathDestination = CCUtility.getDirectoryScan() + "/" + fileNameDestination

        NCUtilityFileSystem.shared.copyFile(atPath: fileNamePath, toPath: fileNamePathDestination)

        let storyboard = UIStoryboard(name: "NCScan", bundle: nil)
        let navigationController = storyboard.instantiateInitialViewController()!

        navigationController.modalPresentationStyle = UIModalPresentationStyle.pageSheet

        appDelegate.window?.rootViewController?.present(navigationController, animated: true, completion: nil)
    }

    // MARK: - Print

    func printDocument(metadata: tableMetadata) {

        let fileNameURL = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!)
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)

        printInfo.jobName = fileNameURL.lastPathComponent
        printInfo.outputType = metadata.classFile == NKCommon.TypeClassFile.image.rawValue ? .photo : .general
        printController.printInfo = printInfo
        printController.showsNumberOfCopies = true

        guard !UIPrintInteractionController.canPrint(fileNameURL) else {
            printController.printingItem = fileNameURL
            printController.present(animated: true)
            return
        }

        // can't print without data
        guard let data = try? Data(contentsOf: fileNameURL) else { return }

        if let svg = SVGKImage(data: data) {
            printController.printingItem = svg.uiImage
            printController.present(animated: true)
            return
        }

        guard let text = String(data: data, encoding: .utf8) else { return }
        let formatter = UISimpleTextPrintFormatter(text: text)
        formatter.perPageContentInsets.top = 72
        formatter.perPageContentInsets.bottom = 72
        formatter.perPageContentInsets.left = 72
        formatter.perPageContentInsets.right = 72
        printController.printFormatter = formatter
        printController.present(animated: true)
    }

    // MARK: - Save photo

    func saveAlbum(metadata: tableMetadata) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

        let fileNamePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!

        NCAskAuthorization.shared.askAuthorizationPhotoLibrary(viewController: appDelegate.mainTabBar?.window?.rootViewController) { hasPermission in
            guard hasPermission else {
                let error = NKError(errorCode: NCGlobal.shared.errorFileNotSaved, errorDescription: "_access_photo_not_enabled_msg_")
                return NCContentPresenter.shared.messageNotification("_access_photo_not_enabled_", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error)
            }

            let errorSave = NKError(errorCode: NCGlobal.shared.errorFileNotSaved, errorDescription: "_file_not_saved_cameraroll_")

            do {
                if metadata.classFile == NKCommon.TypeClassFile.image.rawValue {
                    let data = try Data(contentsOf: URL(fileURLWithPath: fileNamePath))
                    PHPhotoLibrary.shared().performChanges({
                        let assetRequest = PHAssetCreationRequest.forAsset()
                        assetRequest.addResource(with: .photo, data: data, options: nil)
                    }) { success, _ in
                        if !success {
                            NCContentPresenter.shared.messageNotification("_save_selected_files_", error: errorSave, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error)
                        }
                    }
                } else if metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: fileNamePath))
                    }) { success, _ in
                        if !success {
                            NCContentPresenter.shared.messageNotification("_save_selected_files_", error: errorSave, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error)
                        }
                    }
                } else {
                    NCContentPresenter.shared.messageNotification("_save_selected_files_", error: errorSave, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error)
                    return
                }
            } catch {
                NCContentPresenter.shared.messageNotification("_save_selected_files_", error: errorSave, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error)
            }
        }
    }

    func saveLivePhoto(metadata: tableMetadata, metadataMOV: tableMetadata) {

        if !CCUtility.fileProviderStorageExists(metadata) {
            NCOperationQueue.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorSaveAlbumLivePhotoIMG)
        }

        if !CCUtility.fileProviderStorageExists(metadataMOV) {
            NCOperationQueue.shared.download(metadata: metadataMOV, selector: NCGlobal.shared.selectorSaveAlbumLivePhotoMOV)
        }

        if CCUtility.fileProviderStorageExists(metadata) && CCUtility.fileProviderStorageExists(metadataMOV) {
            saveLivePhotoToDisk(metadata: metadata, metadataMov: metadataMOV)
        }
    }

    func saveLivePhotoToDisk(metadata: tableMetadata, metadataMov: tableMetadata) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

        let fileNameImage = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!)
        let fileNameMov = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadataMov.ocId, fileNameView: metadataMov.fileNameView)!)
        let hud = JGProgressHUD()

        hud.indicatorView = JGProgressHUDRingIndicatorView()
        if let indicatorView = hud.indicatorView as? JGProgressHUDRingIndicatorView {
            indicatorView.ringWidth = 1.5
        }
        hud.textLabel.text = NSLocalizedString("_saving_", comment: "")
        hud.show(in: (appDelegate.window?.rootViewController?.view)!)

        NCLivePhoto.generate(from: fileNameImage, videoURL: fileNameMov, progress: { progress in
            hud.progress = Float(progress)
        }, completion: { _, resources in

            if resources != nil {
                NCLivePhoto.saveToLibrary(resources!) { result in
                    DispatchQueue.main.async {
                        if !result {
                            hud.indicatorView = JGProgressHUDErrorIndicatorView()
                            hud.textLabel.text = NSLocalizedString("_livephoto_save_error_", comment: "")
                        } else {
                            hud.indicatorView = JGProgressHUDSuccessIndicatorView()
                            hud.textLabel.text = NSLocalizedString("_success_", comment: "")
                        }
                        hud.dismiss(afterDelay: 1)
                    }
                }
            } else {
                hud.indicatorView = JGProgressHUDErrorIndicatorView()
                hud.textLabel.text = NSLocalizedString("_livephoto_save_error_", comment: "")
                hud.dismiss(afterDelay: 1)
            }
        })
    }

    // MARK: - Copy & Paste

    func copyPasteboard(pasteboardOcIds: [String], hudView: UIView) {
        var items = [[String: Any]]()
        let hud = JGProgressHUD()
        hud.textLabel.text = NSLocalizedString("_wait_", comment: "")
        hud.show(in: hudView)

        // getting file data can take some time and block the main queue
        DispatchQueue.global(qos: .userInitiated).async {
            var downloadMetadatas: [tableMetadata] = []
            for ocid in pasteboardOcIds {
                guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocid) else { continue }
                if let pasteboardItem = metadata.toPasteBoardItem() {
                    items.append(pasteboardItem)
                } else {
                    downloadMetadatas.append(metadata)
                }
            }

            DispatchQueue.main.async(execute: hud.dismiss)

            // do 5 downloads in parallel to optimize efficiency
            let parallelizer = ParallelWorker(n: 5, titleKey: "_downloading_", totalTasks: downloadMetadatas.count, hudView: hudView)

            for metadata in downloadMetadatas {
                parallelizer.execute { completion in
                    NCNetworking.shared.download(metadata: metadata, selector: "") { _, _ in completion() }
                }
            }
            parallelizer.completeWork {
                items.append(contentsOf: downloadMetadatas.compactMap({ $0.toPasteBoardItem() }))
                UIPasteboard.general.setItems(items, options: [:])
            }
        }
    }

    func pastePasteboard(serverUrl: String) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

        let parallelizer = ParallelWorker(n: 5, titleKey: "_uploading_", totalTasks: nil, hudView: appDelegate.window?.rootViewController?.view)

        func uploadPastePasteboard(fileName: String, serverUrlFileName: String, fileNameLocalPath: String, serverUrl: String, completion: @escaping () -> Void) {
            NextcloudKit.shared.upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath) { request in
                NCNetworking.shared.uploadRequest[fileNameLocalPath] = request
            } progressHandler: { _ in
            } completionHandler: { account, ocId, etag, _, _, _, afError, error in
                NCNetworking.shared.uploadRequest.removeValue(forKey: fileNameLocalPath)
                if error == .success && etag != nil && ocId != nil {
                    let toPath = CCUtility.getDirectoryProviderStorageOcId(ocId!, fileNameView: fileName)!
                    NCUtilityFileSystem.shared.moveFile(atPath: fileNameLocalPath, toPath: toPath)
                    NCManageDatabase.shared.addLocalFile(account: account, etag: etag!, ocId: ocId!, fileName: fileName)
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSourceNetworkForced, userInfo: ["serverUrl": serverUrl])
                } else if afError?.isExplicitlyCancelledError ?? false {
                    print("cancel")
                } else {
                    NCContentPresenter.shared.showError(error: error)
                }
                completion()
            }
        }

        for (index, items) in UIPasteboard.general.items.enumerated() {
            for item in items {
                let results = NextcloudKit.shared.nkCommonInstance.getFileProperties(inUTI: item.key as CFString)
                guard !results.ext.isEmpty,
                      let data = UIPasteboard.general.data(forPasteboardType: item.key, inItemSet: IndexSet([index]))?.first
                else { continue }
                let fileName = results.name + "_" + CCUtility.getIncrementalNumber() + "." + results.ext
                let serverUrlFileName = serverUrl + "/" + fileName
                let ocIdUpload = UUID().uuidString
                let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(ocIdUpload, fileNameView: fileName)!
                do { try data.write(to: URL(fileURLWithPath: fileNameLocalPath)) } catch { continue }
                parallelizer.execute { completion in
                    uploadPastePasteboard(fileName: fileName, serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, serverUrl: serverUrl, completion: completion)
                }
            }
        }
        parallelizer.completeWork()
    }

    // MARK: -

    func openFileViewInFolder(serverUrl: String, fileNameBlink: String?, fileNameOpen: String?) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            var topNavigationController: UINavigationController?
            var pushServerUrl = NCUtilityFileSystem.shared.getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId)
            guard var mostViewController = appDelegate.window?.rootViewController?.topMostViewController() else { return }

            if mostViewController.isModal {
                mostViewController.dismiss(animated: false)
                if let viewController = appDelegate.window?.rootViewController?.topMostViewController() {
                    mostViewController = viewController
                }
            }
            mostViewController.navigationController?.popToRootViewController(animated: false)

            if let tabBarController = appDelegate.window?.rootViewController as? UITabBarController {
                tabBarController.selectedIndex = 0
                if let navigationController = tabBarController.viewControllers?.first as? UINavigationController {
                    navigationController.popToRootViewController(animated: false)
                    topNavigationController = navigationController
                }
            }
            if pushServerUrl == serverUrl {
                let viewController = topNavigationController?.topViewController as? NCFiles
                viewController?.blinkCell(fileName: fileNameBlink)
                viewController?.openFile(fileName: fileNameOpen)
                return
            }
            guard let topNavigationController = topNavigationController else { return }

            let diffDirectory = serverUrl.replacingOccurrences(of: pushServerUrl, with: "")
            var subDirs = diffDirectory.split(separator: "/")

            while pushServerUrl != serverUrl, !subDirs.isEmpty {

                guard let dir = subDirs.first, let viewController = UIStoryboard(name: "NCFiles", bundle: nil).instantiateInitialViewController() as? NCFiles else { return }
                pushServerUrl = pushServerUrl + "/" + dir

                viewController.serverUrl = pushServerUrl
                viewController.isRoot = false
                viewController.titleCurrentFolder = String(dir)
                if pushServerUrl == serverUrl {
                    viewController.fileNameBlink = fileNameBlink
                    viewController.fileNameOpen = fileNameOpen
                }
                appDelegate.listFilesVC[serverUrl] = viewController

                viewController.navigationItem.backButtonTitle = viewController.titleCurrentFolder
                topNavigationController.pushViewController(viewController, animated: false)

                subDirs.remove(at: 0)
            }
        }
    }

    // MARK: - NCSelect + Delegate

    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool) {
        if serverUrl != nil && !items.isEmpty {
            if copy {
                for case let metadata as tableMetadata in items {
                    NCOperationQueue.shared.copyMove(metadata: metadata, serverUrl: serverUrl!, overwrite: overwrite, move: false)
                }
            } else if move {
                for case let metadata as tableMetadata in items {
                    NCOperationQueue.shared.copyMove(metadata: metadata, serverUrl: serverUrl!, overwrite: overwrite, move: true)
                }
            }
        }
    }

    func openSelectView(items: [tableMetadata]) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

        let navigationController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateInitialViewController() as? UINavigationController
        let topViewController = navigationController?.topViewController as? NCSelect
        var listViewController = [NCSelect]()

        var copyItems: [tableMetadata] = []
        for item in items {
            copyItems.append(item)
        }

        let homeUrl = NCUtilityFileSystem.shared.getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId)
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
                if let path = NCUtilityFileSystem.shared.deleteLastPath(serverUrlPath: serverUrl) {
                    serverUrl = path
                }
            } else {
                break
            }
        }

        navigationController?.setViewControllers(listViewController, animated: false)
        navigationController?.modalPresentationStyle = .formSheet

        if let navigationController = navigationController {
            appDelegate.window?.rootViewController?.present(navigationController, animated: true, completion: nil)
        }
    }
}

fileprivate extension tableMetadata {
    func toPasteBoardItem() -> [String: Any]? {
        // Get Data
        let fileUrl = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileNameView))
        guard CCUtility.fileProviderStorageExists(self),
              let data = try? Data(contentsOf: fileUrl),
              let unmanagedFileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension as CFString, nil)
        else { return nil }
        // Pasteboard item
        let fileUTI = unmanagedFileUTI.takeRetainedValue() as String
        return [fileUTI: data]
    }
}
