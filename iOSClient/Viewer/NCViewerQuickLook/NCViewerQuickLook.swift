//
//  NCViewerQuickLook.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 03/05/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//  Copyright © 2022 Henrik Storch. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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
import QuickLook
import NCCommunication

@objc class NCViewerQuickLook: QLPreviewController {

    let url: URL
    var previewItems: [PreviewItem] = []
    var isEditingEnabled: Bool
    var metadata: tableMetadata?

    // if the document has any changes (annotations)
    var hasChanges = false

    // used to display the save alert
    var parentVC: UIViewController?

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc init(with url: URL, isEditingEnabled: Bool, metadata: tableMetadata?) {
        self.url = url
        self.isEditingEnabled = isEditingEnabled
        if let metadata = metadata {
            self.metadata = tableMetadata.init(value: metadata)
        }

        let previewItem = PreviewItem()
        previewItem.previewItemURL = url
        self.previewItems.append(previewItem)

        super.init(nibName: nil, bundle: nil)

        self.dataSource = self
        self.delegate = self
        self.currentPreviewItemIndex = 0
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard isEditingEnabled else { return }

        if metadata?.livePhoto == true {
            NCContentPresenter.shared.messageNotification(
                "", description: "_message_disable_overwrite_livephoto_",
                delay: NCGlobal.shared.dismissAfterSecond,
                type: NCContentPresenter.messageType.info,
                errorCode: NCGlobal.shared.errorCharactersForbidden)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // needs to be saved bc in didDisappear presentingVC is already nil
        self.parentVC = presentingViewController
    }

    override func viewDidDisappear(_ animated: Bool) {
        // called after `previewController(:didSaveEditedCopyOf:)`
        super.viewDidDisappear(animated)

        guard isEditingEnabled, hasChanges else { return }

        let alertController = UIAlertController(title: NSLocalizedString("_save_", comment: ""), message: "", preferredStyle: .alert)
        let userId = (UIApplication.shared.delegate as? AppDelegate)?.userId ?? ""
        if metadata?.livePhoto == false, metadata?.canUnlock(as: userId) != false {
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_overwrite_original_", comment: ""), style: .default) { _ in
                self.saveModifiedFile(override: true)
            })
        }

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_save_as_copy_", comment: ""), style: .default) { _ in
            self.saveModifiedFile(override: false)
        })
        alertController.addAction(UIAlertAction(title: NSLocalizedString("_discard_changes_", comment: ""), style: .destructive) { _ in })
        parentVC?.present(alertController, animated: true)
    }
}

extension NCViewerQuickLook: QLPreviewControllerDataSource, QLPreviewControllerDelegate {

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        previewItems.count
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        previewItems[index]
    }

    @available(iOS 13.0, *)
    func previewController(_ controller: QLPreviewController, editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode {
        return isEditingEnabled ? .createCopy : .disabled
    }

    fileprivate func saveModifiedFile(override: Bool) {
        guard let metadata = self.metadata else { return }

        let ocId = NSUUID().uuidString
        let size = NCUtilityFileSystem.shared.getFileSize(filePath: url.path)

        if !override {
            let fileName = NCUtilityFileSystem.shared.createFileName(metadata.fileNameView, serverUrl: metadata.serverUrl, account: metadata.account)
            metadata.fileName = fileName
            metadata.fileNameView = fileName
        }

        guard let fileNamePath = CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: metadata.fileNameView),
              NCUtilityFileSystem.shared.copyFile(atPath: url.path, toPath: fileNamePath) else { return }

        let metadataForUpload = NCManageDatabase.shared.createMetadata(
            account: metadata.account,
            user: metadata.user,
            userId: metadata.userId,
            fileName: metadata.fileName,
            fileNameView: metadata.fileNameView,
            ocId: ocId,
            serverUrl: metadata.serverUrl,
            urlBase: metadata.urlBase,
            url: url.path,
            contentType: "",
            livePhoto: false)

        metadataForUpload.session = NCNetworking.shared.sessionIdentifierBackground
        metadataForUpload.sessionSelector = NCGlobal.shared.selectorUploadFile
        metadataForUpload.size = size
        metadataForUpload.status = NCGlobal.shared.metadataStatusWaitUpload
        (UIApplication.shared.delegate as? AppDelegate)?.networkingProcessUpload?.createProcessUploads(metadatas: [metadataForUpload])
    }

    func previewController(_ controller: QLPreviewController, didSaveEditedCopyOf previewItem: QLPreviewItem, at modifiedContentsURL: URL) {
        // easier to handle that way than to use `.updateContents`
        // needs to be moved otherwise it will only be called once!
        guard NCUtilityFileSystem.shared.moveFile(atPath: modifiedContentsURL.path, toPath: url.path) else { return }
        hasChanges = true
    }
}

class PreviewItem: NSObject, QLPreviewItem {
    var previewItemURL: URL?
}
