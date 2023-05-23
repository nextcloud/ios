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
import Photos
import NextcloudKit

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
            if !assets.isEmpty {
                if #available(iOS 15, *) {
                    let vc = NCHostingUploadAssetsView().makeShipDetailsUI(assets: assets, serverUrl: self.appDelegate.activeServerUrl, userBaseUrl: self.appDelegate)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        viewController.present(vc, animated: true, completion: nil)
                    }
                } else {
                    let assets = assets.compactMap { $0.phAsset }
                    let vc = NCCreateFormUploadAssets(serverUrl: self.appDelegate.activeServerUrl, assets: assets, cryptated: false, session: NCNetworking.shared.sessionIdentifierBackground)
                    let navigationController = UINavigationController(rootViewController: vc)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        viewController.present(navigationController, animated: true, completion: nil)
                    }
                }
            }
        }
    }

    private func openPhotosPickerViewController(completition: @escaping ([TLPHAsset]) -> Void) {

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

            completition(assets)

        }, didCancel: nil)

        viewController.didExceedMaximumNumberOfSelection = { _ in
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_limited_dimension_")
            NCContentPresenter.shared.showError(error: error)
        }

        viewController.handleNoAlbumPermissions = { _ in
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_denied_album_")
            NCContentPresenter.shared.showError(error: error)
        }

        viewController.handleNoCameraPermissions = { _ in
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_denied_camera_")
            NCContentPresenter.shared.showError(error: error)
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
    var isViewerMedia: Bool
    var viewController: UIViewController?

    @discardableResult
    init (tabBarController: UITabBarController, isViewerMedia: Bool, allowsMultipleSelection: Bool, viewController: UIViewController? = nil) {

        self.isViewerMedia = isViewerMedia
        self.viewController = viewController
        super.init()

        let documentProviderMenu = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.data])

        documentProviderMenu.modalPresentationStyle = .formSheet
        documentProviderMenu.allowsMultipleSelection = allowsMultipleSelection
        documentProviderMenu.popoverPresentationController?.sourceView = tabBarController.tabBar
        documentProviderMenu.popoverPresentationController?.sourceRect = tabBarController.tabBar.bounds
        documentProviderMenu.delegate = self

        appDelegate.window?.rootViewController?.present(documentProviderMenu, animated: true, completion: nil)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {

        let ocId = NSUUID().uuidString

        if isViewerMedia,
            let urlIn = urls.first,
            let url = self.copySecurityScopedResource(url: urlIn, urlOut: FileManager.default.temporaryDirectory.appendingPathComponent(urlIn.lastPathComponent)),
            let viewController = self.viewController {

            let fileName = url.lastPathComponent
            let metadata = NCManageDatabase.shared.createMetadata(account: appDelegate.account, user: appDelegate.user, userId: appDelegate.userId, fileName: fileName, fileNameView: fileName, ocId: ocId, serverUrl: "", urlBase: appDelegate.urlBase, url: url.path, contentType: "")
            if metadata.classFile == NKCommon.TypeClassFile.unknow.rawValue {
                metadata.classFile = NKCommon.TypeClassFile.video.rawValue
            }
            NCManageDatabase.shared.addMetadata(metadata)
            NCViewer.shared.view(viewController: viewController, metadata: metadata, metadatas: [metadata], imageIcon: nil)

        } else {

            for urlIn in urls {

                let fileName = urlIn.lastPathComponent
                let toPath = CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileName)!
                let urlOut = URL(fileURLWithPath: toPath)
                let serverUrl = appDelegate.activeServerUrl

                guard let url = self.copySecurityScopedResource(url: urlIn, urlOut: urlOut) else { continue }

                let metadataForUpload = NCManageDatabase.shared.createMetadata(account: appDelegate.account, user: appDelegate.user, userId: appDelegate.userId, fileName: fileName, fileNameView: fileName, ocId: ocId, serverUrl: serverUrl, urlBase: appDelegate.urlBase, url: "", contentType: "")

                metadataForUpload.session = NCNetworking.shared.sessionIdentifierBackground
                metadataForUpload.sessionSelector = NCGlobal.shared.selectorUploadFile
                metadataForUpload.size = NCUtilityFileSystem.shared.getFileSize(filePath: toPath)
                metadataForUpload.status = NCGlobal.shared.metadataStatusWaitUpload

                if NCManageDatabase.shared.getMetadataConflict(account: appDelegate.account, serverUrl: serverUrl, fileNameView: fileName) != nil {

                    if let conflict = UIStoryboard(name: "NCCreateFormUploadConflict", bundle: nil).instantiateInitialViewController() as? NCCreateFormUploadConflict {

                        conflict.delegate = appDelegate
                        conflict.serverUrl = serverUrl
                        conflict.metadatasUploadInConflict = [metadataForUpload]

                        appDelegate.window?.rootViewController?.present(conflict, animated: true, completion: nil)
                    }

                } else {
                    NCNetworkingProcessUpload.shared.createProcessUploads(metadatas: [metadataForUpload], completion: { _ in })
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
