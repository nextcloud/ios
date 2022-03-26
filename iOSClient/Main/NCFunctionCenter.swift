//
//  NCFunctionCenter.swift
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
import NCCommunication
import Queuer
import JGProgressHUD
import SVGKit

@objc class NCFunctionCenter: NSObject, UIDocumentInteractionControllerDelegate, NCSelectDelegate {
    @objc public static let shared: NCFunctionCenter = {
        let instance = NCFunctionCenter()
        NotificationCenter.default.addObserver(instance, selector: #selector(downloadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile), object: nil)
        NotificationCenter.default.addObserver(instance, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)
        return instance
    }()

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var viewerQuickLook: NCViewerQuickLook?
    var documentController: UIDocumentInteractionController?

    // MARK: - Download

    @objc func downloadedFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let selector = userInfo["selector"] as? String,
              let errorCode = userInfo["errorCode"] as? Int,
              let errorDescription = userInfo["errorDescription"] as? String,
              let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId),
              metadata.account == appDelegate.account
        else { return }

        guard errorCode == 0 else {
            // File do not exists on server, remove in local
            if errorCode == NCGlobal.shared.errorResourceNotFound || errorCode == NCGlobal.shared.errorBadServerResponse {
                do {
                    try FileManager.default.removeItem(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                } catch { }
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                NCManageDatabase.shared.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                
            } else {
                NCContentPresenter.shared.messageNotification("_download_file_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode, priority: .max)
            }
            return
        }
        
        switch selector {
        case NCGlobal.shared.selectorLoadFileQuickLook:
            let fileNamePath = NSTemporaryDirectory() + metadata.fileNameView
            CCUtility.copyFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView), toPath: fileNamePath)

            var editingMode = false
            if #available(iOS 13.0, *) {
                editingMode = true
            }

            let viewerQuickLook = NCViewerQuickLook(with: URL(fileURLWithPath: fileNamePath), isEditingEnabled: editingMode, metadata: metadata)
            self.appDelegate.window?.rootViewController?.present(viewerQuickLook, animated: true)

        case NCGlobal.shared.selectorLoadFileView:
            guard UIApplication.shared.applicationState == UIApplication.State.active else { break }

            if metadata.contentType.contains("opendocument") && !NCUtility.shared.isRichDocument(metadata) {
                self.openDocumentController(metadata: metadata)
            } else if metadata.classFile == NCCommunicationCommon.typeClassFile.compress.rawValue || metadata.classFile == NCCommunicationCommon.typeClassFile.unknow.rawValue {
                self.openDocumentController(metadata: metadata)
            } else {
                if let viewController = self.appDelegate.activeViewController {
                    let imageIcon = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
                    NCViewer.shared.view(viewController: viewController, metadata: metadata, metadatas: [metadata], imageIcon: imageIcon)
                }
            }
            
        case NCGlobal.shared.selectorOpenIn:
            if UIApplication.shared.applicationState == UIApplication.State.active {
                self.openDocumentController(metadata: metadata)
            }
            
        case NCGlobal.shared.selectorLoadOffline:
            NCManageDatabase.shared.setLocalFile(ocId: metadata.ocId, offline: true)
            
        case NCGlobal.shared.selectorPrint:
            printDocument(metadata: metadata)
            
        case NCGlobal.shared.selectorSaveAlbum:
            saveAlbum(metadata: metadata)
            
        case NCGlobal.shared.selectorSaveBackground:
            saveBackground(metadata: metadata)
            
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
            break
        }
    }

    func setMetadataAvalableOffline(_ metadata: tableMetadata, isOffline: Bool) {
        let serverUrl = metadata.serverUrl + "/" + metadata.fileName
        if isOffline {
            if metadata.directory {
                NCManageDatabase.shared.setDirectory(serverUrl: serverUrl, offline: false, account: self.appDelegate.account)
            } else {
                NCManageDatabase.shared.setLocalFile(ocId: metadata.ocId, offline: false)
            }
        } else if metadata.directory {
            NCManageDatabase.shared.setDirectory(serverUrl: serverUrl, offline: true, account: self.appDelegate.account)
            NCOperationQueue.shared.synchronizationMetadata(metadata, selector: NCGlobal.shared.selectorDownloadAllFile)
        } else {
            NCNetworking.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorLoadOffline) { _ in }
            if let metadataLivePhoto = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
                NCNetworking.shared.download(metadata: metadataLivePhoto, selector: NCGlobal.shared.selectorLoadOffline) { _ in }
            }
        }
    }

    // MARK: - Upload

    @objc func uploadedFile(_ notification: NSNotification) {

        if let userInfo = notification.userInfo as NSDictionary? {
            if let ocId = userInfo["ocId"] as? String, let errorCode = userInfo["errorCode"] as? Int, let errorDescription = userInfo["errorDescription"] as? String, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {

                if metadata.account == appDelegate.account {
                    if errorCode != 0 {
                        if errorCode != -999 && errorDescription != "" {
                            NCContentPresenter.shared.messageNotification("_upload_file_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode, priority: .max)
                        }
                    }
                }
            }
        }
    }

    // MARK: -

    func openShare(viewController: UIViewController, metadata: tableMetadata, indexPage: NCGlobal.NCSharePagingIndex) {

        let shareNavigationController = UIStoryboard(name: "NCShare", bundle: nil).instantiateInitialViewController() as! UINavigationController
        let shareViewController = shareNavigationController.topViewController as! NCSharePaging

        shareViewController.metadata = metadata
        shareViewController.indexPage = indexPage

        shareNavigationController.modalPresentationStyle = .formSheet
        viewController.present(shareNavigationController, animated: true, completion: nil)
    }

    // MARK: -

    func openDownload(metadata: tableMetadata, selector: String) {

        if CCUtility.fileProviderStorageExists(metadata) {

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadedFile, userInfo: ["ocId": metadata.ocId, "selector": selector, "errorCode": 0, "errorDescription": "" ])

        } else {

            NCNetworking.shared.download(metadata: metadata, selector: selector) { _ in }
        }
    }

    // MARK: - Open in ...

    func openDocumentController(metadata: tableMetadata) {

        guard let mainTabBar = self.appDelegate.mainTabBar else { return }
        let fileURL = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))

        documentController = UIDocumentInteractionController(url: fileURL)
        documentController?.presentOptionsMenu(from: mainTabBar.menuRect, in: mainTabBar, animated: true)
    }

    func openActivityViewController(selectedMetadata: [tableMetadata]) {
        let metadatas = selectedMetadata.filter({ !$0.directory })
        var items: [URL] = []
        var downloadMetadata: [(tableMetadata, URL)] = []

        for metadata in metadatas {
            let fileURL = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))
            if CCUtility.fileProviderStorageExists(metadata) { items.append(fileURL) }
            else { downloadMetadata.append((metadata, fileURL)) }
        }

        let processor = ParallelWorker(n: 5, titleKey: "_downloading_", totalTasks: downloadMetadata.count, hudView: self.appDelegate.window?.rootViewController?.view)
        for (metadata, url) in downloadMetadata {
            processor.execute { completion in
                NCNetworking.shared.download(metadata: metadata, selector: "", completion: { _ in
                    if CCUtility.fileProviderStorageExists(metadata) { items.append(url) }
                    completion()
                })
            }
        }

        processor.completeWork {
            guard !items.isEmpty, let mainTabBar = self.appDelegate.mainTabBar else { return }
            let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
            activityViewController.popoverPresentationController?.permittedArrowDirections = .any
            activityViewController.popoverPresentationController?.sourceView = mainTabBar
            activityViewController.popoverPresentationController?.sourceRect = mainTabBar.menuRect
            self.appDelegate.window?.rootViewController?.present(activityViewController, animated: true)
        }
    }

    // MARK: - Save as scan

    func saveAsScan(metadata: tableMetadata) {

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
        printInfo.outputType = metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue ? .photo : .general
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

        let fileNamePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
        let status = PHPhotoLibrary.authorizationStatus()

        if metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue && status == PHAuthorizationStatus.authorized {

            if let image = UIImage(contentsOfFile: fileNamePath) {
                UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveAlbum(_:didFinishSavingWithError:contextInfo:)), nil)
            } else {
                NCContentPresenter.shared.messageNotification("_save_selected_files_", description: "_file_not_saved_cameraroll_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorFileNotSaved)
            }

        } else if metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue && status == PHAuthorizationStatus.authorized {

            if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(fileNamePath) {
                UISaveVideoAtPathToSavedPhotosAlbum(fileNamePath, self, #selector(saveAlbum(_:didFinishSavingWithError:contextInfo:)), nil)
            } else {
                NCContentPresenter.shared.messageNotification("_save_selected_files_", description: "_file_not_saved_cameraroll_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorFileNotSaved)
            }

        } else if status != PHAuthorizationStatus.authorized {

            NCContentPresenter.shared.messageNotification("_access_photo_not_enabled_", description: "_access_photo_not_enabled_msg_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorFileNotSaved)
        }
    }

    @objc private func saveAlbum(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {

        if error != nil {
            NCContentPresenter.shared.messageNotification("_save_selected_files_", description: "_file_not_saved_cameraroll_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorFileNotSaved)
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

        let fileNameImage = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!)
        let fileNameMov = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadataMov.ocId, fileNameView: metadataMov.fileNameView)!)
        let hud = JGProgressHUD()
        
        hud.indicatorView = JGProgressHUDRingIndicatorView()
        if let indicatorView = hud.indicatorView as? JGProgressHUDRingIndicatorView {
            indicatorView.ringWidth = 1.5
        }
        hud.show(in: (appDelegate.window?.rootViewController?.view)!)
        hud.textLabel.text = NSLocalizedString("_saving_", comment: "")
        
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

    func saveBackground(metadata: tableMetadata) {

        let fileNamePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
        let destination = CCUtility.getDirectoryGroup().appendingPathComponent(NCGlobal.shared.appBackground).path + "/" + metadata.fileNameView

        if NCUtilityFileSystem.shared.copyFile(atPath: fileNamePath, toPath: destination) {

            if appDelegate.activeViewController is NCCollectionViewCommon {
                let viewController: NCCollectionViewCommon = appDelegate.activeViewController as! NCCollectionViewCommon
                let layoutKey = viewController.layoutKey
                let serverUrl = viewController.serverUrl
                if serverUrl == metadata.serverUrl {
                    NCUtility.shared.setBackgroundImageForView(key: layoutKey, serverUrl: serverUrl, imageBackgroud: metadata.fileNameView, imageBackgroudContentMode: "")
                    viewController.changeTheming()
                }
            }
        }
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
                if let pasteboardItem = metadata.toPasteBoardItem() { items.append(pasteboardItem) }
                else { downloadMetadatas.append(metadata) }
            }

            DispatchQueue.main.async(execute: hud.dismiss)

            // do 5 downloads in parallel to optimize efficiency
            let parallelizer = ParallelWorker(n: 5, titleKey: "_downloading_", totalTasks: downloadMetadatas.count, hudView: hudView)

            for metadata in downloadMetadatas {
                parallelizer.execute { completion in
                    NCNetworking.shared.download(metadata: metadata, selector: "") { _ in completion() }
                }
            }
            parallelizer.completeWork {
                items.append(contentsOf: downloadMetadatas.compactMap({ $0.toPasteBoardItem() }))
                UIPasteboard.general.setItems(items, options: [:])
            }
        }
    }

    func upload(fileName: String, serverUrlFileName: String, fileNameLocalPath: String, serverUrl: String, completion: @escaping () -> Void) {
        NCCommunication.shared.upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath) { _ in
        } progressHandler: { progress in
        } completionHandler: { account, ocId, etag, _, _, _, errorCode, errorDescription in
            if errorCode == 0 && etag != nil && ocId != nil {
                let toPath = CCUtility.getDirectoryProviderStorageOcId(ocId!, fileNameView: fileName)!
                NCUtilityFileSystem.shared.moveFile(atPath: fileNameLocalPath, toPath: toPath)
                NCManageDatabase.shared.addLocalFile(account: account, etag: etag!, ocId: ocId!, fileName: fileName)
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSourceNetworkForced, userInfo: ["serverUrl": serverUrl])
            } else {
                NCContentPresenter.shared.showError(description: errorDescription, errorCode: errorCode)
            }
            completion()
        }
    }

    func pastePasteboard(serverUrl: String) {
        let parallelizer = ParallelWorker(n: 5, titleKey: "_uploading_", totalTasks: nil, hudView: appDelegate.window?.rootViewController?.view)

        for (index, items) in UIPasteboard.general.items.enumerated() {
            for item in items {
                let results = NCCommunicationCommon.shared.getFileProperties(inUTI: item.key as CFString)
                guard !results.ext.isEmpty,
                      let data = UIPasteboard.general.data(forPasteboardType: item.key, inItemSet: IndexSet([index]))?.first
                else { continue }
                let fileName = results.name + "_" + CCUtility.getIncrementalNumber() + "." + results.ext
                let serverUrlFileName = serverUrl + "/" + fileName
                let ocIdUpload = UUID().uuidString
                let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(ocIdUpload, fileNameView: fileName)!
                do { try data.write(to: URL(fileURLWithPath: fileNameLocalPath)) } catch { continue }
                parallelizer.execute { completion in
                    self.upload(fileName: fileName, serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, serverUrl: serverUrl, completion: completion)
                }
            }
        }
        parallelizer.completeWork()
    }

    // MARK: -

    func openFileViewInFolder(serverUrl: String, fileName: String) {

        let viewController = UIStoryboard(name: "NCFileViewInFolder", bundle: nil).instantiateInitialViewController() as! NCFileViewInFolder
        let navigationController = UINavigationController(rootViewController: viewController)

        let topViewController = viewController
        var listViewController = [NCFileViewInFolder]()
        var serverUrl = serverUrl
        let homeUrl = NCUtilityFileSystem.shared.getHomeServer(account: appDelegate.account)

        while true {

            var viewController: NCFileViewInFolder?
            if serverUrl != homeUrl {
                viewController = UIStoryboard(name: "NCFileViewInFolder", bundle: nil).instantiateInitialViewController() as? NCFileViewInFolder
                if viewController == nil {
                    return
                }
                viewController!.titleCurrentFolder = (serverUrl as NSString).lastPathComponent
            } else {
                viewController = topViewController
            }
            guard let vc = viewController else { return }

            vc.serverUrl = serverUrl
            vc.fileName = fileName

            vc.navigationItem.backButtonTitle = vc.titleCurrentFolder
            listViewController.insert(vc, at: 0)

            if serverUrl != homeUrl {
                serverUrl = NCUtilityFileSystem.shared.deletingLastPathComponent(account: appDelegate.account, serverUrl: serverUrl)
            } else {
                break
            }
        }

        navigationController.setViewControllers(listViewController, animated: false)
        navigationController.modalPresentationStyle = .formSheet

        appDelegate.window?.rootViewController?.present(navigationController, animated: true, completion: nil)
    }

    // MARK: - NCSelect + Delegate

    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool) {
        if serverUrl != nil && items.count > 0 {
            if copy {
                for metadata in items as! [tableMetadata] {
                    NCOperationQueue.shared.copyMove(metadata: metadata, serverUrl: serverUrl!, overwrite: overwrite, move: false)
                }
            } else if move {
                for metadata in items as! [tableMetadata] {
                    NCOperationQueue.shared.copyMove(metadata: metadata, serverUrl: serverUrl!, overwrite: overwrite, move: true)
                }
            }
        }
    }

    func openSelectView(items: [Any]) {

        let navigationController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateInitialViewController() as! UINavigationController
        let topViewController = navigationController.topViewController as! NCSelect
        var listViewController = [NCSelect]()

        var copyItems: [Any] = []
        for item in items {
            copyItems.append(item)
        }

        let homeUrl = NCUtilityFileSystem.shared.getHomeServer(account: appDelegate.account)
        var serverUrl = (copyItems[0] as! Nextcloud.tableMetadata).serverUrl

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
                serverUrl = NCUtilityFileSystem.shared.deletingLastPathComponent(account: appDelegate.account, serverUrl: serverUrl)
            } else {
                break
            }
        }

        navigationController.setViewControllers(listViewController, animated: false)
        navigationController.modalPresentationStyle = .formSheet

        appDelegate.window?.rootViewController?.present(navigationController, animated: true, completion: nil)
    }

    // MARK: - Context Menu Configuration

    @available(iOS 13.0, *)
    func contextMenuConfiguration(ocId: String, viewController: UIViewController, enableDeleteLocal: Bool, enableViewInFolder: Bool, image: UIImage?) -> UIMenu {

        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) else {
            return UIMenu()
        }
        let isFolderEncrypted = CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account, urlBase: metadata.urlBase)
        var titleDeleteConfirmFile = NSLocalizedString("_delete_file_", comment: "")
        if metadata.directory { titleDeleteConfirmFile = NSLocalizedString("_delete_folder_", comment: "") }
        var titleSave: String = NSLocalizedString("_save_selected_files_", comment: "")
        let metadataMOV = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata)
        if metadataMOV != nil {
            titleSave = NSLocalizedString("_livephoto_save_", comment: "")
        }
        let titleFavorite = metadata.favorite ? NSLocalizedString("_remove_favorites_", comment: "") : NSLocalizedString("_add_favorites_", comment: "")

        let serverUrl = metadata.serverUrl + "/" + metadata.fileName
        var isOffline = false
        if metadata.directory {
            if let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, serverUrl)) {
                isOffline = directory.offline
            }
        } else {
            if let localFile = NCManageDatabase.shared.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
                isOffline = localFile.offline
            }
        }
        let titleOffline = isOffline ? NSLocalizedString("_remove_available_offline_", comment: "") :  NSLocalizedString("_set_available_offline_", comment: "")

        let copy = UIAction(title: NSLocalizedString("_copy_file_", comment: ""), image: UIImage(systemName: "doc.on.doc")) { _ in
            self.copyPasteboard(pasteboardOcIds: [metadata.ocId], hudView: viewController.view)
        }

        let copyPath = UIAction(title: NSLocalizedString("_copy_path_", comment: ""), image: UIImage(systemName: "doc.on.clipboard")) { _ in
            let board = UIPasteboard.general
            board.string = NCUtilityFileSystem.shared.getPath(metadata: metadata)
            NCContentPresenter.shared.messageNotification("", description: "_copied_path_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.info, errorCode: NCGlobal.shared.errorNoError)
        }

        let detail = UIAction(title: NSLocalizedString("_details_", comment: ""), image: UIImage(systemName: "info")) { _ in
            self.openShare(viewController: viewController, metadata: metadata, indexPage: .activity)
        }

        let offline = UIAction(title: titleOffline, image: UIImage(systemName: "tray.and.arrow.down")) { _ in
            self.setMetadataAvalableOffline(metadata, isOffline: isOffline)
            if let viewController = viewController as? NCCollectionViewCommon {
                viewController.reloadDataSource()
            }
        }

        let save = UIAction(title: titleSave, image: UIImage(systemName: "square.and.arrow.down")) { _ in
            if metadataMOV != nil {
                self.saveLivePhoto(metadata: metadata, metadataMOV: metadataMOV!)
            } else {
                if CCUtility.fileProviderStorageExists(metadata) {
                    self.saveAlbum(metadata: metadata)
                } else {
                    NCOperationQueue.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorSaveAlbum)
                }
            }
        }

        let saveBackground = UIAction(title: NSLocalizedString("_use_as_background_", comment: ""), image: UIImage(systemName: "text.below.photo")) { _ in
            if CCUtility.fileProviderStorageExists(metadata) {
                self.saveBackground(metadata: metadata)
            } else {
                NCOperationQueue.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorSaveBackground)
            }
        }

        let viewInFolder = UIAction(title: NSLocalizedString("_view_in_folder_", comment: ""), image: UIImage(systemName: "arrow.forward.square")) { _ in
            self.openFileViewInFolder(serverUrl: metadata.serverUrl, fileName: metadata.fileName)
        }

        let openIn = UIAction(title: NSLocalizedString("_open_in_", comment: ""), image: UIImage(systemName: "square.and.arrow.up") ) { _ in
            self.openDownload(metadata: metadata, selector: NCGlobal.shared.selectorOpenIn)
        }

        let print = UIAction(title: NSLocalizedString("_print_", comment: ""), image: UIImage(systemName: "printer") ) { _ in
            self.openDownload(metadata: metadata, selector: NCGlobal.shared.selectorPrint)
        }

        let modify = UIAction(title: NSLocalizedString("_modify_", comment: ""), image: UIImage(systemName: "pencil.tip.crop.circle")) { _ in
            self.openDownload(metadata: metadata, selector: NCGlobal.shared.selectorLoadFileQuickLook)
        }

        let saveAsScan = UIAction(title: NSLocalizedString("_save_as_scan_", comment: ""), image: UIImage(systemName: "viewfinder.circle")) { _ in
            self.openDownload(metadata: metadata, selector: NCGlobal.shared.selectorSaveAsScan)
        }

        // let open = UIMenu(title: NSLocalizedString("_open_", comment: ""), image: UIImage(systemName: "square.and.arrow.up"), children: [openIn, openQuickLook])

        let moveCopy = UIAction(title: NSLocalizedString("_move_or_copy_", comment: ""), image: UIImage(systemName: "arrow.up.right.square")) { _ in
            self.openSelectView(items: [metadata])
        }

        let rename = UIAction(title: NSLocalizedString("_rename_", comment: ""), image: UIImage(systemName: "pencil")) { _ in

            if let vcRename = UIStoryboard(name: "NCRenameFile", bundle: nil).instantiateInitialViewController() as? NCRenameFile {

                vcRename.metadata = metadata
                vcRename.imagePreview = image

                let popup = NCPopupViewController(contentController: vcRename, popupWidth: vcRename.width, popupHeight: vcRename.height)

                viewController.present(popup, animated: true)
            }
        }

        let favorite = UIAction(title: titleFavorite, image: NCUtility.shared.loadImage(named: "star.fill", color: NCBrandColor.shared.yellowFavorite)) { _ in

            NCNetworking.shared.favoriteMetadata(metadata) { errorCode, errorDescription in
                if errorCode != 0 {
                    NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                }
            }
        }

        let deleteConfirmFile = UIAction(title: titleDeleteConfirmFile, image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
            NCNetworking.shared.deleteMetadata(metadata, onlyLocalCache: false) { errorCode, errorDescription in
                if errorCode != 0 {
                    NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                }
            }
        }

        let deleteConfirmLocal = UIAction(title: NSLocalizedString("_remove_local_file_", comment: ""), image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
            NCNetworking.shared.deleteMetadata(metadata, onlyLocalCache: true) { _, _ in
            }
        }

        var delete = UIMenu(title: NSLocalizedString("_delete_file_", comment: ""), image: UIImage(systemName: "trash"), options: .destructive, children: [deleteConfirmLocal, deleteConfirmFile])

        if !enableDeleteLocal {
            delete = UIMenu(title: NSLocalizedString("_delete_file_", comment: ""), image: UIImage(systemName: "trash"), options: .destructive, children: [deleteConfirmFile])
        }

        if metadata.directory {
            delete = UIMenu(title: NSLocalizedString("_delete_folder_", comment: ""), image: UIImage(systemName: "trash"), options: .destructive, children: [deleteConfirmFile])
        }

        // ------ MENU -----

        // DIR

        if metadata.directory {

            let submenu = UIMenu(title: "", options: .displayInline, children: [favorite, offline, rename, moveCopy, copyPath, delete])
            return UIMenu(title: "", children: [detail, submenu])
        }

        // FILE

        var children: [UIMenuElement] = [favorite, offline, openIn, rename, moveCopy, copy, copyPath, delete]

        if (metadata.contentType != "image/svg+xml") && (metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue || metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue) {
            children.insert(save, at: 2)
        }

        if (metadata.contentType != "image/svg+xml") && (metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue) {
            children.insert(saveAsScan, at: 2)
        }

        if (metadata.contentType != "image/svg+xml") && (metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue || metadata.contentType == "application/pdf" || metadata.contentType == "com.adobe.pdf") {
            children.insert(print, at: 2)
        }

        if enableViewInFolder {
            children.insert(viewInFolder, at: children.count-1)
        }

        if (!isFolderEncrypted && metadata.contentType != "image/gif" && metadata.contentType != "image/svg+xml") && (metadata.contentType == "com.adobe.pdf" || metadata.contentType == "application/pdf" || metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue) {
            children.insert(modify, at: children.count-1)
        }

        if metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue && viewController is NCCollectionViewCommon && !NCBrandOptions.shared.disable_background_image {
            let viewController: NCCollectionViewCommon = viewController as! NCCollectionViewCommon
            let layoutKey = viewController.layoutKey
            if layoutKey == NCGlobal.shared.layoutViewFiles {
                children.insert(saveBackground, at: children.count-1)
            }
        }

        let submenu = UIMenu(title: "", options: .displayInline, children: children)
        return UIMenu(title: "", children: [detail, submenu])
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
