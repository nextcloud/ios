//
//  NCViewerQuickLook.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 03/05/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//  Copyright © 2022 Henrik Storch. All rights reserved.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
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
import NextcloudKit
import Mantis
import SwiftUI

public protocol NCViewerQuickLookDelegate: AnyObject {
    func dismissQuickLook(fileNameSource: String, hasChangesQuickLook: Bool)
}

// optional func
public extension NCViewerQuickLookDelegate {
    func dismissQuickLook(fileNameSource: String, hasChangesQuickLook: Bool) {}
}

// if the document has any changes
private var hasChangesQuickLook: Bool = false

@objc class NCViewerQuickLook: QLPreviewController {
    private let url: URL
    private let fileNameSource: String
    private var previewItems: [PreviewItem] = []
    private var isEditingEnabled: Bool
    private var metadata: tableMetadata?
    private var timer: Timer?
    // used to display the save alert
    private var parentVC: UIViewController?
    private let utilityFileSystem = NCUtilityFileSystem()

    public var saveAsCopyAlert: Bool = true
    public var uploadMetadata: Bool = true
    public weak var delegateQuickLook: NCViewerQuickLookDelegate?

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc init(with url: URL, fileNameSource: String = "", isEditingEnabled: Bool, metadata: tableMetadata?) {
        self.url = url
        self.fileNameSource = fileNameSource
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
        hasChangesQuickLook = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard isEditingEnabled else { return }

        if metadata?.isLivePhoto == true {
            let error = NKError(errorCode: NCGlobal.shared.errorCharactersForbidden, errorDescription: "_message_disable_overwrite_livephoto_")
            NCContentPresenter().showInfo(error: error)
        }

        if let metadata = metadata, metadata.isImage {
            let buttonDone = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissView))
            let buttonCrop = UIBarButtonItem(image: NCUtility().loadImage(named: "crop"), style: .plain, target: self, action: #selector(crop))
            navigationItem.leftBarButtonItems = [buttonDone, buttonCrop]
            startTimer(navigationItem: navigationItem)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // needs to be saved bc in didDisappear presentingVC is already nil
        parentVC = presentingViewController
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if let metadata = metadata, metadata.classFile != NKCommon.TypeClassFile.image.rawValue {
            dismissView()
        }
    }

    func startTimer(navigationItem: UINavigationItem) {
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { _ in
            guard let buttonDone = navigationItem.leftBarButtonItems?.first, let buttonCrop = navigationItem.leftBarButtonItems?.last else { return }
            buttonCrop.isEnabled = true
            buttonDone.isEnabled = true
            if let markup = navigationItem.rightBarButtonItems?.first(where: { $0.accessibilityIdentifier == "QLOverlayMarkupButtonAccessibilityIdentifier" }) {
                if let originalButton = markup.value(forKey: "originalButton") as AnyObject? {
                    if let symbolImageName = originalButton.value(forKey: "symbolImageName") as? String {
                        if symbolImageName == "pencil.tip.crop.circle.on" {
                            buttonCrop.isEnabled = false
                            buttonDone.isEnabled = false
                        }
                    }
                }
            }
        })
    }

    @objc private func dismissView() {
        guard isEditingEnabled, hasChangesQuickLook, let metadata = metadata else {
            dismiss(animated: true)
            return
        }
        let alertController = UIAlertController(title: NSLocalizedString("_save_", comment: ""), message: nil, preferredStyle: .alert)
        var message: String?

        if metadata.isLivePhoto {
            message = NSLocalizedString("_message_disable_overwrite_livephoto_", comment: "")
        } else if metadata.lock {
            message = NSLocalizedString("_file_locked_no_override_", comment: "")
        } else {
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_overwrite_original_", comment: ""), style: .default) { _ in
                self.saveModifiedFile(override: true)
                self.delegateQuickLook?.dismissQuickLook(fileNameSource: self.fileNameSource, hasChangesQuickLook: hasChangesQuickLook)
            })
        }

        alertController.message = message

        if saveAsCopyAlert {
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_save_as_copy_", comment: ""), style: .default) { _ in
                self.saveModifiedFile(override: false)
                self.delegateQuickLook?.dismissQuickLook(fileNameSource: self.fileNameSource, hasChangesQuickLook: hasChangesQuickLook)
            })
        }
        alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel) { _ in
        })
        alertController.addAction(UIAlertAction(title: NSLocalizedString("_discard_changes_", comment: ""), style: .destructive) { _ in
            self.dismiss(animated: true)
        })

        if metadata.isImage {
            present(alertController, animated: true)
        } else {
            parentVC?.present(alertController, animated: true)
        }
    }

    @objc private func crop() {
        guard let image = UIImage(contentsOfFile: url.path) else { return }
        var toolbarConfig = CropToolbarConfig()

        toolbarConfig.heightForVerticalOrientation = 80
        toolbarConfig.widthForHorizontalOrientation = 100
        toolbarConfig.optionButtonFontSize = 16
        toolbarConfig.optionButtonFontSizeForPad = 21
        toolbarConfig.backgroundColor = .systemGray6
        toolbarConfig.foregroundColor = .systemBlue

        var viewConfig = CropViewConfig()
        viewConfig.cropMaskVisualEffectType = .none
        viewConfig.cropBorderColor = .red

        var config = Mantis.Config()
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            config.localizationConfig.bundle = Bundle(identifier: bundleIdentifier)
            config.localizationConfig.tableName = "Localizable"
        }
        config.cropToolbarConfig = toolbarConfig
        config.cropViewConfig = viewConfig

        let toolbar = CropToolbar()
        toolbar.iconProvider = CropToolbarIcon()

        let cropViewController = Mantis.cropViewController(image: image, config: config, cropToolbar: toolbar)
        cropViewController.delegate = self
        cropViewController.backgroundColor = .systemBackground
        cropViewController.modalPresentationStyle = .fullScreen

        self.present(cropViewController, animated: true)
    }
}

extension NCViewerQuickLook: QLPreviewControllerDataSource, QLPreviewControllerDelegate {

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        previewItems.count
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        previewItems[index]
    }

    func previewController(_ controller: QLPreviewController, editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode {
        return isEditingEnabled ? .createCopy : .disabled
    }

    fileprivate func saveModifiedFile(override: Bool) {
        guard let metadata = self.metadata else { return }
        let session = NCSession.shared.getSession(account: metadata.account)
        if !uploadMetadata {
            return self.dismiss(animated: true)
        }
        let ocId = NSUUID().uuidString
        let size = utilityFileSystem.getFileSize(filePath: url.path)

        if !override {
            let fileName = utilityFileSystem.createFileName(metadata.fileNameView, serverUrl: metadata.serverUrl, account: metadata.account)
            metadata.fileName = fileName
            metadata.fileNameView = fileName
        }

        let fileNamePath = utilityFileSystem.getDirectoryProviderStorageOcId(ocId, fileNameView: metadata.fileNameView)
        guard utilityFileSystem.copyFile(atPath: url.path, toPath: fileNamePath) else { return }

        let metadataForUpload = NCManageDatabase.shared.createMetadata(fileName: metadata.fileName,
                                                                       fileNameView: metadata.fileNameView,
                                                                       ocId: ocId,
                                                                       serverUrl: metadata.serverUrl,
                                                                       url: url.path,
                                                                       contentType: "",
                                                                       session: session,
                                                                       sceneIdentifier: nil)

        metadataForUpload.session = NCNetworking.shared.sessionUploadBackground
        if override {
            metadataForUpload.sessionSelector = NCGlobal.shared.selectorUploadFileNODelete
        } else {
            metadataForUpload.sessionSelector = NCGlobal.shared.selectorUploadFile
        }
        metadataForUpload.size = size
        metadataForUpload.status = NCGlobal.shared.metadataStatusWaitUpload
        metadataForUpload.sessionDate = Date()

        NCNetworkingProcess.shared.createProcessUploads(metadatas: [metadataForUpload]) { _ in
            self.dismiss(animated: true)
        }
    }

    func previewController(_ controller: QLPreviewController, didSaveEditedCopyOf previewItem: QLPreviewItem, at modifiedContentsURL: URL) {
        // easier to handle that way than to use `.updateContents`
        // needs to be moved otherwise it will only be called once!
        guard utilityFileSystem.moveFile(atPath: modifiedContentsURL.path, toPath: url.path) else { return }
        hasChangesQuickLook = true
    }
}

extension NCViewerQuickLook: CropViewControllerDelegate {
    func cropViewControllerDidCrop(_ cropViewController: Mantis.CropViewController, cropped: UIImage, transformation: Mantis.Transformation, cropInfo: Mantis.CropInfo) {
        cropViewController.dismiss(animated: true)
        guard let data = cropped.jpegData(compressionQuality: 0.9) else { return }
        do {
            try data.write(to: self.url)
            hasChangesQuickLook = true
            reloadData()
        } catch {
            print(error)
        }
    }

    func cropViewControllerDidCancel(_ cropViewController: Mantis.CropViewController, original: UIImage) {
        cropViewController.dismiss(animated: true)
    }
}

class PreviewItem: NSObject, QLPreviewItem {
    var previewItemURL: URL?
}

class CropToolbarIcon: CropToolbarIconProvider {
    func getCropIcon() -> UIImage? {
        return NCUtility().loadImage(named: "checkmark.circle")
    }

    func getCancelIcon() -> UIImage? {
        return NCUtility().loadImage(named: "xmark.circle")
    }
}
