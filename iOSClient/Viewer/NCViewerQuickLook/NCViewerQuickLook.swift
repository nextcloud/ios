// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana, 2022 Henrik Storch, 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import QuickLook
import NextcloudKit
import Mantis
import SwiftUI
import LucidBanner
import Alamofire

public protocol NCViewerQuickLookDelegate: AnyObject {
    func dismissQuickLook(fileNameSource: String, hasChangesQuickLook: Bool)
}

/// Optional implementation
public extension NCViewerQuickLookDelegate {
    func dismissQuickLook(fileNameSource: String, hasChangesQuickLook: Bool) {}
}

/// Flag indicating If the document has any changes
private var hasChangesQuickLook: Bool = false

@objc class NCViewerQuickLook: QLPreviewController {
    private let url: URL
    private let fileNameSource: String
    private var previewItems: [PreviewItem] = []
    private var isEditingEnabled: Bool
    private var metadata: tableMetadata?
    private var timer: Timer?
    /// Used to display the save alert
    private var viewController: UIViewController?
    private let utilityFileSystem = NCUtilityFileSystem()
    private let database = NCManageDatabase.shared

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
        guard isEditingEnabled else {
            return
        }

        if metadata?.isLivePhoto == true {
            Task {
                let windowScene = viewController?.view.window?.windowScene
                await showWarningBanner(windowScene: windowScene,
                                        subtitle: "_message_disable_overwrite_livephoto_",
                                        systemImage: "livephoto.slash",
                                        imageAnimation: .bounce,
                                        errorCode: NSURLErrorNotConnectedToInternet)
            }
        }

        if let metadata = metadata, metadata.isImage {
            let buttonDone = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissView(_:)))
            let buttonCrop = UIBarButtonItem(image: NCUtility().loadImage(named: "crop"), style: .plain, target: self, action: #selector(crop(_:)))
            navigationItem.leftBarButtonItems = [buttonDone, buttonCrop]
            startTimer(navigationItem: navigationItem)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // needs to be saved bc in didDisappear presentingVC is already nil
        self.viewController = presentingViewController
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if let metadata = metadata, metadata.classFile != NKTypeClassFile.image.rawValue {
            dismissView(nil)
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

    private func showSaveAlert() {
        guard let metadata = metadata else { return }

        let alertController = UIAlertController(title: NSLocalizedString("_save_changes_", comment: ""), message: nil, preferredStyle: .alert)
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

        self.viewController?.present(alertController, animated: true)
    }

    @objc private func dismissView(_ sender: Any?) {
        dismiss(animated: true) {
            if hasChangesQuickLook {
                self.showSaveAlert()
            }
        }
    }

    @objc private func crop(_ sender: Any?) {
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
        return isEditingEnabled ? .createCopy : .disabled // File is in private storage, so .updateContents is not possible and will still act as .createCopy.
    }

    fileprivate func saveModifiedFile(override: Bool) {
        guard let metadata = self.metadata else {
            return
        }
        if !uploadMetadata {
            return self.dismiss(animated: true)
        }

        Task { @MainActor in
            var fileName: String
            var uploadRequest: UploadRequest?
            var banner: LucidBanner?
            var token: Int?
            let windowScene = viewController?.view.window?.windowScene
            var error = NKError()
            let serverUrl = metadata.serverUrl

            if override {
                fileName = metadata.fileName
            } else {
                fileName = utilityFileSystem.createFileName(metadata.fileNameView, serverUrl: serverUrl, account: metadata.account)
            }
            let serverUrlFileName = utilityFileSystem.createServerUrl(serverUrl: metadata.serverUrl, fileName: fileName)

            (banner, token) = showHudBanner(windowScene: windowScene,
                                            title: "_upload_in_progress_",
                                            stage: .button,
                                            onButtonTap: {
                if let request = uploadRequest {
                    request.cancel()
                }
            })

            let results = await NextcloudKit.shared.uploadAsync(
                serverUrlFileName: serverUrlFileName,
                fileNameLocalPath: url.path,
                autoMkcol: true,
                account: metadata.account) { request in
                    uploadRequest = request
                } progressHandler: { progress in
                    Task {@MainActor in
                        banner?.update(
                            payload: LucidBannerPayload.Update(progress: Double(progress.fractionCompleted)),
                            for: token)
                    }
                }
            error = results.error

            if error == .success {
                let results = await NCNetworking.shared.readFileAsync(serverUrlFileName: serverUrlFileName, account: metadata.account)
                error = results.error

                if results.error == .success, let metadata = results.metadata {
                    // clean dir
                    let directory = utilityFileSystem.cleanDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase)
                    // copy new file
                    utilityFileSystem.copyFile(atPath: url.path, toPath: directory + "/" + metadata.fileName)
                    // add new metadata
                    await self.database.addMetadataAsync(metadata)
                    // reload datasource
                    await NCNetworking.shared.transferDispatcher.notifyAllDelegatesAsync { delegate in
                        delegate.transferReloadDataSource(serverUrl: serverUrl, requestData: false, status: nil)
                    }
                }
            }

            if let banner {
                await banner.dismissAsync()
            }

            if error != .success {
                await showErrorBanner(windowScene: windowScene, text: error.errorDescription, errorCode: error.errorCode)
            }

            self.dismiss(animated: true)
        }
    }

    func previewController(_ controller: QLPreviewController, didSaveEditedCopyOf previewItem: QLPreviewItem, at modifiedContentsURL: URL) {
        guard utilityFileSystem.copyFile(atPath: modifiedContentsURL.path, toPath: url.path) else { return }
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
