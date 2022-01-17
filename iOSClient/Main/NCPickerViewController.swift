//
//  NCPickerViewController.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 11/11/2018.
//  Copyright (c) 2018 Marino Faggiana. All rights reserved.
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
import TLPhotoPicker
import MobileCoreServices

// MARK: - Photo Picker

class NCPhotosPickerViewController: NSObject {

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var sourceViewController: UIViewController
    var maxSelectedAssets = 1
    var singleSelectedMode = false

    @discardableResult
    init(viewController: UIViewController, maxSelectedAssets: Int, singleSelectedMode: Bool) {
        sourceViewController = viewController
        super.init()

        self.maxSelectedAssets = maxSelectedAssets
        self.singleSelectedMode = singleSelectedMode

        self.openPhotosPickerViewController { assets in
            guard let assets = assets else { return }
            if assets.count > 0 {

                let form = NCCreateFormUploadAssets(serverUrl: self.appDelegate.activeServerUrl, assets: assets, cryptated: false, session: NCNetworking.shared.sessionIdentifierBackground, delegate: nil)
                let navigationController = UINavigationController(rootViewController: form)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    viewController.present(navigationController, animated: true, completion: nil)
                }
            }
        }
    }

    private func openPhotosPickerViewController(completition: @escaping ([PHAsset]?) -> Void) {

        var selectedAssets: [PHAsset] = []
        var configure = TLPhotosPickerConfigure()

        configure.cancelTitle = NSLocalizedString("_cancel_", comment: "")
        configure.doneTitle = NSLocalizedString("_done_", comment: "")
        configure.emptyMessage = NSLocalizedString("_no_albums_", comment: "")
        configure.tapHereToChange = NSLocalizedString("_tap_here_to_change_", comment: "")

        if maxSelectedAssets > 0 {
            configure.maxSelectedAssets = maxSelectedAssets
        }
        configure.selectedColor = NCBrandColor.shared.brandElement
        configure.singleSelectedMode = singleSelectedMode
        configure.allowedAlbumCloudShared = true

        let viewController = customPhotoPickerViewController(withTLPHAssets: { assets in

            for asset: TLPHAsset in assets {
                if asset.phAsset != nil {
                    selectedAssets.append(asset.phAsset!)
                }
            }

            completition(selectedAssets)

        }, didCancel: nil)

        viewController.didExceedMaximumNumberOfSelection = { _ in
            NCContentPresenter.shared.messageNotification("_info_", description: "_limited_dimension_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorInternalError)
        }

        viewController.handleNoAlbumPermissions = { _ in
            NCContentPresenter.shared.messageNotification("_info_", description: "_denied_album_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorInternalError)
        }

        viewController.handleNoCameraPermissions = { _ in
            NCContentPresenter.shared.messageNotification("_info_", description: "_denied_camera_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorInternalError)
        }

        viewController.configure = configure

        sourceViewController.present(viewController, animated: true, completion: nil)
    }
}

class customPhotoPickerViewController: TLPhotosPickerViewController {

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func makeUI() {
        super.makeUI()

        self.customNavItem.leftBarButtonItem?.tintColor = .systemBlue
        self.customNavItem.rightBarButtonItem?.tintColor = .systemBlue
    }
}

// MARK: - Document Picker

class NCDocumentPickerViewController: NSObject, UIDocumentPickerDelegate {

    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    @discardableResult
    init (tabBarController: UITabBarController) {
        super.init()

        let documentProviderMenu = UIDocumentPickerViewController(documentTypes: ["public.data"], in: .import)

        documentProviderMenu.modalPresentationStyle = .formSheet
        documentProviderMenu.allowsMultipleSelection = true
        documentProviderMenu.popoverPresentationController?.sourceView = tabBarController.tabBar
        documentProviderMenu.popoverPresentationController?.sourceRect = tabBarController.tabBar.bounds
        documentProviderMenu.delegate = self

        appDelegate.window?.rootViewController?.present(documentProviderMenu, animated: true, completion: nil)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {

        for url in urls {

            let fileName = url.lastPathComponent
            let serverUrl = appDelegate.activeServerUrl
            let ocId = NSUUID().uuidString
            let atPath = url.path
            let toPath = CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileName)!

            if NCUtilityFileSystem.shared.copyFile(atPath: atPath, toPath: toPath) {

                let metadataForUpload = NCManageDatabase.shared.createMetadata(account: appDelegate.account, user: appDelegate.user, userId: appDelegate.userId, fileName: fileName, fileNameView: fileName, ocId: ocId, serverUrl: serverUrl, urlBase: appDelegate.urlBase, url: "", contentType: "", livePhoto: false)

                metadataForUpload.session = NCNetworking.shared.sessionIdentifierBackground
                metadataForUpload.sessionSelector = NCGlobal.shared.selectorUploadFile
                metadataForUpload.size = NCUtilityFileSystem.shared.getFileSize(filePath: toPath)
                metadataForUpload.status = NCGlobal.shared.metadataStatusWaitUpload

                if NCManageDatabase.shared.getMetadataConflict(account: appDelegate.account, serverUrl: serverUrl, fileName: fileName) != nil {

                    if let conflict = UIStoryboard(name: "NCCreateFormUploadConflict", bundle: nil).instantiateInitialViewController() as? NCCreateFormUploadConflict {
                        conflict.delegate = appDelegate
                        conflict.serverUrl = serverUrl
                        conflict.metadatasUploadInConflict = [metadataForUpload]

                        appDelegate.window?.rootViewController?.present(conflict, animated: true, completion: nil)
                    }

                } else {
                    appDelegate.networkingProcessUpload?.createProcessUploads(metadatas: [metadataForUpload])
                }

            } else {
                NCContentPresenter.shared.messageNotification("_error_", description: "_read_file_error_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorInternalError)
            }
        }
    }
}
