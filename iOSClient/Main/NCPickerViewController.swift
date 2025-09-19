// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import TLPhotoPicker
import MobileCoreServices
import Photos
import NextcloudKit
import SwiftUI

// MARK: - Photo Picker

class NCPhotosPickerViewController: NSObject {
    var controller: NCMainTabBarController
    var maxSelectedAssets = 1
    var singleSelectedMode = false
    let global = NCGlobal.shared

    @discardableResult
    init(controller: NCMainTabBarController, maxSelectedAssets: Int, singleSelectedMode: Bool) {
        self.controller = controller
        super.init()
        self.maxSelectedAssets = maxSelectedAssets
        self.singleSelectedMode = singleSelectedMode

        openPhotosPickerViewController { assets in
            guard !assets.isEmpty else {
                return
            }
            let model = NCUploadAssetsModel(assets: assets, serverUrl: controller.currentServerUrl(), controller: controller)
            let view = NCUploadAssetsView(model: model)
            let viewController = UIHostingController(rootView: view)

            controller.present(viewController, animated: true, completion: nil)
        }
    }

    private func openPhotosPickerViewController(completition: @escaping ([TLPHAsset]) -> Void) {
        var configure = TLPhotosPickerConfigure()
        var pickerVC: TLPhotosPickerViewController?

        configure.cancelTitle = NSLocalizedString("_cancel_", comment: "")
        configure.doneTitle = NSLocalizedString("_add_", comment: "")
        configure.emptyMessage = NSLocalizedString("_no_albums_", comment: "")
        configure.tapHereToChange = NSLocalizedString("_tap_here_to_change_", comment: "")

        if maxSelectedAssets > 0 {
            configure.maxSelectedAssets = maxSelectedAssets
        }
        configure.selectedColor = NCBrandColor.shared.getElement(account: controller.account)
        configure.singleSelectedMode = singleSelectedMode
        configure.allowedAlbumCloudShared = true

        pickerVC = customPhotoPickerViewController(withTLPHAssets: { assets in
            pickerVC?.dismiss(animated: true) {
                completition(assets)
            }
        }, didCancel: nil)

        pickerVC?.didExceedMaximumNumberOfSelection = { _ in
            let error = NKError(errorCode: self.global.errorInternalError, errorDescription: "_limited_dimension_")
            NCContentPresenter().showError(error: error)
        }

        pickerVC?.handleNoAlbumPermissions = { _ in
            let error = NKError(errorCode: self.global.errorInternalError, errorDescription: "_denied_album_")
            NCContentPresenter().showError(error: error)
        }

        pickerVC?.handleNoCameraPermissions = { _ in
            let error = NKError(errorCode: self.global.errorInternalError, errorDescription: "_denied_camera_")
            NCContentPresenter().showError(error: error)
        }

        pickerVC?.configure = configure
        guard let pickerVC else {
            return
        }

        DispatchQueue.main.async {
            self.controller.present(pickerVC, animated: true, completion: nil)
        }
    }
}

class customPhotoPickerViewController: TLPhotosPickerViewController {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func makeUI() {
        super.makeUI()

        self.customNavItem.leftBarButtonItem?.tintColor = NCBrandColor.shared.iconImageColor
        self.customNavItem.rightBarButtonItem?.tintColor = NCBrandColor.shared.iconImageColor
        if #available(iOS 26.0, *) {
            doneButton.image = UIImage(systemName: "checkmark")
            cancelButton.image = UIImage(systemName: "xmark")
            navigationBarTopConstraint.constant = self.navigationBarTopConstraint.constant + 10
        }
    }
}

// MARK: - Document Picker

class NCDocumentPickerViewController: NSObject, UIDocumentPickerDelegate {
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    let utilityFileSystem = NCUtilityFileSystem()
    let database = NCManageDatabase.shared
    var isViewerMedia: Bool
    var viewController: UIViewController?
    var controller: NCMainTabBarController

    @discardableResult
    init (controller: NCMainTabBarController, isViewerMedia: Bool, allowsMultipleSelection: Bool, viewController: UIViewController? = nil) {
        self.controller = controller
        self.isViewerMedia = isViewerMedia
        self.viewController = viewController
        super.init()

        let documentProviderMenu = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.data])

        documentProviderMenu.modalPresentationStyle = .formSheet
        documentProviderMenu.allowsMultipleSelection = allowsMultipleSelection
        documentProviderMenu.popoverPresentationController?.sourceView = controller.tabBar
        documentProviderMenu.popoverPresentationController?.sourceRect = controller.tabBar.bounds
        documentProviderMenu.delegate = self

        controller.present(documentProviderMenu, animated: true, completion: nil)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        Task { @MainActor in
            let session = NCSession.shared.getSession(controller: self.controller)
            let capabilities = await NKCapabilities.shared.getCapabilities(for: session.account)

            if isViewerMedia,
               let urlIn = urls.first,
               let url = self.copySecurityScopedResource(url: urlIn, urlOut: FileManager.default.temporaryDirectory.appendingPathComponent(urlIn.lastPathComponent)),
               let viewController = self.viewController {
                let ocId = NSUUID().uuidString
                let fileName = url.lastPathComponent
                let metadata = await database.createMetadataAsync(fileName: fileName,
                                                                  ocId: ocId,
                                                                  serverUrl: "",
                                                                  url: url.path,
                                                                  session: session,
                                                                  sceneIdentifier: self.controller.sceneIdentifier)

                if metadata.classFile == NKTypeClassFile.unknow.rawValue {
                    metadata.classFile = NKTypeClassFile.video.rawValue
                }

                if let fileNameError = FileNameValidator.checkFileName(metadata.fileNameView, account: self.controller.account, capabilities: capabilities) {
                    let message = "\(fileNameError.errorDescription) \(NSLocalizedString("_please_rename_file_", comment: ""))"
                    await UIAlertController.warningAsync( message: message, presenter: self.controller)
                } else {
                    if let metadata = await database.addAndReturnMetadataAsync(metadata),
                       let vc = await NCViewer().getViewerController(metadata: metadata, delegate: viewController) {
                        viewController.navigationController?.pushViewController(vc, animated: true)
                    }
                }
            } else {
                let serverUrl = self.controller.currentServerUrl()
                var metadatas = [tableMetadata]()
                var metadatasInConflict = [tableMetadata]()
                var invalidNameIndexes: [Int] = []

                for urlIn in urls {
                    let ocId = NSUUID().uuidString
                    let fileName = urlIn.lastPathComponent
                    let newFileName = FileAutoRenamer.rename(fileName, capabilities: capabilities)
                    let toPath = utilityFileSystem.getDirectoryProviderStorageOcId(ocId,
                                                                                   fileName: newFileName,
                                                                                   userId: session.userId,
                                                                                   urlBase: session.urlBase)
                    let urlOut = URL(fileURLWithPath: toPath)
                    guard self.copySecurityScopedResource(url: urlIn, urlOut: urlOut) != nil else {
                        continue
                    }
                    let metadataForUpload = await database.createMetadataAsync(fileName: newFileName,
                                                                               ocId: ocId,
                                                                               serverUrl: serverUrl,
                                                                               url: "",
                                                                               session: session,
                                                                               sceneIdentifier: self.controller.sceneIdentifier)

                    metadataForUpload.session = NCNetworking.shared.sessionUploadBackground
                    metadataForUpload.sessionSelector = NCGlobal.shared.selectorUploadFile
                    metadataForUpload.size = utilityFileSystem.getFileSize(filePath: toPath)
                    metadataForUpload.status = NCGlobal.shared.metadataStatusWaitUpload
                    metadataForUpload.sessionDate = Date()

                    if database.getMetadataConflict(account: session.account, serverUrl: serverUrl, fileNameView: fileName, nativeFormat: metadataForUpload.nativeFormat) != nil {
                        metadatasInConflict.append(metadataForUpload)
                    } else {
                        metadatas.append(metadataForUpload)
                    }
                }

                for (index, metadata) in metadatas.enumerated() {
                    if let fileNameError = FileNameValidator.checkFileName(metadata.fileName, account: session.account, capabilities: capabilities) {
                        if metadatas.count == 1 {

                            let newFileName = await UIAlertController.renameFileAsync(fileName: metadata.fileName,
                                                                                      capabilities: capabilities,
                                                                                      account: metadata.account,
                                                                                      presenter: self.controller)

                            metadatas[index].fileName = newFileName
                            metadatas[index].fileNameView = newFileName
                            metadatas[index].serverUrlFileName = utilityFileSystem.createServerUrl(serverUrl: metadatas[index].serverUrl, fileName: newFileName)

                            await self.database.addMetadatasAsync(metadatas)

                            return
                        } else {
                            let message = "\(fileNameError.errorDescription) \(NSLocalizedString("_please_rename_file_", comment: ""))"
                            await UIAlertController.warningAsync( message: message, presenter: self.controller)
                            invalidNameIndexes.append(index)
                        }
                    }
                }

                for index in invalidNameIndexes.reversed() {
                    metadatas.remove(at: index)
                }

                await self.database.addMetadatasAsync(metadatas)

                if !metadatasInConflict.isEmpty {
                    if let conflict = UIStoryboard(name: "NCCreateFormUploadConflict", bundle: nil).instantiateInitialViewController() as? NCCreateFormUploadConflict {
                        conflict.account = self.controller.account
                        conflict.delegate = appDelegate
                        conflict.serverUrl = serverUrl
                        conflict.metadatasUploadInConflict = metadatasInConflict

                        self.controller.present(conflict, animated: true, completion: nil)
                    }
                }
            }
        }
    }

    func copySecurityScopedResource(url: URL, urlOut: URL) -> URL? {
        try? FileManager.default.removeItem(at: urlOut)
        if url.startAccessingSecurityScopedResource() {
            do {
                try FileManager.default.copyItem(at: url, to: urlOut)
                url.stopAccessingSecurityScopedResource()
                return urlOut
            } catch {
            }
        }
        return nil
    }
}
