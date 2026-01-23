// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import Photos

extension NCNetworking: NCTransferDelegate {
    func setupTransferDelegate() {
        Task {
            await NCNetworking.shared.transferDispatcher.addDelegate(self)
        }
    }

    func transferReloadData(serverUrl: String?) { }

    func transferReloadDataSource(serverUrl: String?, requestData: Bool, status: Int?) { }

    func transferProgressDidUpdate(progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String) { }

    func transferChange(status: String,
                        account: String,
                        fileName: String,
                        serverUrl: String,
                        selector: String?,
                        ocId: String,
                        destination: String?,
                        error: NKError) {
        Task { @MainActor in
            // DOWNLOADED
            guard error == .success,
                  status == self.global.networkingStatusDownloaded,
                  let metadata = await NCManageDatabase.shared.getMetadataFromOcIdAsync(ocId)
            else {
                return
            }
            let selector = selector ?? metadata.sessionSelector
            /// Select UIWindowScene active in serverUrl
            var controller: NCMainTabBarController?
            let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            if windowScenes.count == 1 {
                controller = UIApplication.shared.mainAppWindow?.rootViewController as? NCMainTabBarController
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
            let scene = SceneManager.shared.getWindow(controller: controller)?.windowScene

            switch selector {
            case NCGlobal.shared.selectorLoadFileQuickLook:

                let fileNamePath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId,
                                                                                          fileName: metadata.fileNameView,
                                                                                          userId: metadata.userId,
                                                                                          urlBase: metadata.urlBase)
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

                if metadata.contentType.contains("opendocument") && !NCUtility().isTypeFileRichDocument(metadata) {
                    await NCCreate().createActivityViewController(selectedMetadata: [metadata], controller: controller, sender: nil)
                } else if metadata.classFile == NKTypeClassFile.compress.rawValue || metadata.classFile == NKTypeClassFile.unknow.rawValue {
                    await NCCreate().createActivityViewController(selectedMetadata: [metadata], controller: controller, sender: nil)
                } else {
                    if let viewController = controller.currentViewController() {
                        let image = NCUtility().getImage(ocId: metadata.ocId, etag: metadata.etag, ext: NCGlobal.shared.previewExt1024, userId: metadata.userId, urlBase: metadata.urlBase)
                        Task {
                            if let vc = await NCViewer().getViewerController(metadata: metadata, image: image, delegate: viewController) {
                                viewController.navigationController?.pushViewController(vc, animated: true)
                            }
                        }
                    }
                }

            case NCGlobal.shared.selectorOpenIn:
                guard !isAppInBackground
                else {
                    return
                }

                await NCCreate().createActivityViewController(selectedMetadata: [metadata], controller: controller, sender: nil)

            case NCGlobal.shared.selectorSaveAlbum:

                let fileNamePath = utilityFileSystem.getDirectoryProviderStorageOcId(
                    metadata.ocId,
                    fileName: metadata.fileNameView,
                    userId: metadata.userId,
                    urlBase: metadata.urlBase)

                NCAskAuthorization().askAuthorizationPhotoLibrary(controller: controller) { hasPermission in
                    guard hasPermission else {
                        Task {@MainActor in
                            await showErrorBanner(scene: scene, text: "_access_photo_not_enabled_msg_")
                        }
                        return
                    }

                    do {
                        if metadata.isImage {
                            let data = try Data(contentsOf: URL(fileURLWithPath: fileNamePath))
                            PHPhotoLibrary.shared().performChanges({
                                let assetRequest = PHAssetCreationRequest.forAsset()
                                assetRequest.addResource(with: .photo, data: data, options: nil)
                            }) { success, _ in
                                if !success {
                                    Task {
                                        await showErrorBanner(scene: scene, text: "_file_not_saved_cameraroll_")
                                    }
                                }
                            }
                        } else if metadata.isVideo {
                            PHPhotoLibrary.shared().performChanges({
                                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: fileNamePath))
                            }) { success, _ in
                                if !success {
                                    Task {
                                        await showErrorBanner(scene: scene, text: "_file_not_saved_cameraroll_")
                                    }
                                }
                            }
                        } else {
                            Task {
                                await showErrorBanner(scene: scene, text: "_file_not_saved_cameraroll_")
                            }
                            return
                        }
                    } catch {
                        Task {
                            await showErrorBanner(scene: scene, text: "_file_not_saved_cameraroll_")
                        }
                    }
                }

            case NCGlobal.shared.selectorSaveAsScan:

                let fileNamePath = utilityFileSystem.getDirectoryProviderStorageOcId(
                    metadata.ocId,
                    fileName: metadata.fileNameView,
                    userId: metadata.userId,
                    urlBase: metadata.urlBase
                )
                let fileNameDestination = utilityFileSystem.createFileName("scan.png", fileDate: Date(), fileType: PHAssetMediaType.image, notUseMask: true)
                let fileNamePathDestination = utilityFileSystem.createServerUrl(serverUrl: utilityFileSystem.directoryScan, fileName: fileNameDestination)

                utilityFileSystem.copyFile(atPath: fileNamePath, toPath: fileNamePathDestination)

                if let navigationController = UIStoryboard(name: "NCScan", bundle: nil).instantiateInitialViewController() {
                    navigationController.modalPresentationStyle = UIModalPresentationStyle.pageSheet
                    let viewController = navigationController.presentedViewController as? NCScan
                    viewController?.serverUrl = controller.currentServerUrl()
                    viewController?.controller = controller
                    controller.present(navigationController, animated: true, completion: nil)
                }

            case NCGlobal.shared.selectorOpenDetail:
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterOpenMediaDetail, userInfo: ["ocId": metadata.ocId])

            default:
                let applicationHandle = NCApplicationHandle()
                applicationHandle.downloadedFile(selector: metadata.sessionSelector, metadata: metadata)
            }
        }
    }

    @MainActor
    func viewerFile(account: String, fileId: String, viewController: UIViewController) async {
        if let metadata = await NCManageDatabase.shared.getMetadataFromFileIdAsync(fileId) {
            do {
                let attr = try FileManager.default.attributesOfItem(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(
                    metadata.ocId,
                    fileName: metadata.fileNameView,
                    userId: metadata.userId,
                    urlBase: metadata.urlBase)
                )
                let fileSize = attr[FileAttributeKey.size] as? UInt64 ?? 0
                if fileSize > 0 {
                    if let vc = await NCViewer().getViewerController(metadata: metadata, delegate: viewController) {
                        viewController.navigationController?.pushViewController(vc, animated: true)
                    }
                    return
                }
            } catch {
                print("Error: \(error)")
            }
        }

        let resultsFile = await NextcloudKit.shared.getFileFromFileIdAsync(fileId: fileId, account: account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                    account: account,
                    path: fileId,
                    name: "getFileFromFileId"
                )
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }
        guard resultsFile.error == .success, let file = resultsFile.file else {
            Task {
                await showErrorBanner(controller: viewController.tabBarController, text: resultsFile.error.errorDescription)
            }
            return
        }

        let metadata = await NCManageDatabaseCreateMetadata().convertFileToMetadataAsync(file)
        await NCManageDatabase.shared.addMetadataAsync(metadata)

        let fileNameLocalPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(
            metadata.ocId,
            fileName: metadata.fileNameView,
            userId: metadata.userId,
            urlBase: metadata.urlBase
        )

        if metadata.isAudioOrVideo {
            if let vc = await NCViewer().getViewerController(metadata: metadata, delegate: viewController) {
                viewController.navigationController?.pushViewController(vc, animated: true)
            }
            return
        }

        let download = await NextcloudKit.shared.downloadAsync(
            serverUrlFileName: metadata.serverUrlFileName,
            fileNameLocalPath: fileNameLocalPath,
            account: account) { _ in
        } taskHandler: { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: metadata.account,
                                                                                            path: metadata.serverUrlFileName,
                                                                                            name: "download")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)

                let ocId = metadata.ocId
                await NCManageDatabase.shared.setMetadataSessionAsync(ocId: ocId,
                                                                      sessionTaskIdentifier: task.taskIdentifier,
                                                                      status: self.global.metadataStatusDownloading)
            }
        } progressHandler: { _ in

        }

        await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                              session: "",
                                                              sessionTaskIdentifier: 0,
                                                              sessionError: "",
                                                              status: self.global.metadataStatusNormal,
                                                              etag: download.etag)

        if download.nkError == .success {
            await NCManageDatabase.shared.addLocalFilesAsync(metadatas: [metadata])
            if let vc = await NCViewer().getViewerController(metadata: metadata, delegate: viewController) {
                viewController.navigationController?.pushViewController(vc, animated: true)
            }
        }
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

                guard let dir = subDirs.first else {
                    return
                }
                serverUrlPush = self.utilityFileSystem.createServerUrl(serverUrl: serverUrlPush, fileName: String(dir))

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
}
