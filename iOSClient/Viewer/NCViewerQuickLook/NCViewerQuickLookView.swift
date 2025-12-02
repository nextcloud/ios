// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import QuickLook
import Mantis
import NextcloudKit

struct NCViewerQuickLookView: UIViewControllerRepresentable {
    let url: URL
    @Binding var index: Int
    @Binding var isPresentedQuickLook: Bool
    @ObservedObject var model: NCUploadAssetsModel

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = QLPreviewController()

        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        context.coordinator.viewController = controller

        let buttonDone = UIBarButtonItem(barButtonSystemItem: .done, target: context.coordinator, action: #selector(context.coordinator.dismiss))
        let buttonCrop = UIBarButtonItem(image: NCUtility().loadImage(named: "crop"), style: .plain, target: context.coordinator, action: #selector(context.coordinator.crop))
        controller.navigationItem.leftBarButtonItems = [buttonDone, buttonCrop]

        model.startTimer(navigationItem: controller.navigationItem)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if model.previewStore[index].assetType == .livePhoto && model.previewStore[index].asset.type == .livePhoto && model.previewStore[index].data == nil {
                let error = NKError(errorCode: NCGlobal.shared.errorCharactersForbidden, errorDescription: "_message_disable_livephoto_")
                NCContentPresenter().showInfo(error: error)
            }
        }

        let navigationController = UINavigationController(rootViewController: controller)
        return navigationController
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate, CropViewControllerDelegate {
        weak var viewController: QLPreviewController?
        let parent: NCViewerQuickLookView
        var image: UIImage?
        var hasChange = false

        init(parent: NCViewerQuickLookView) {
            self.parent = parent
            super.init()

            NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
                parent.model.stopTimer()
            }

            NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] _ in
                guard let self = self,
                      let navigationItem = self.viewController?.navigationItem else {
                    return
                }
                parent.model.startTimer(navigationItem: navigationItem)
            }
        }

        @objc func dismiss() {
            parent.model.stopTimer()
            parent.isPresentedQuickLook = false
            if let imageData = image,
               let image = image?.resizeImage(size: CGSize(width: 240, height: 240), isAspectRation: true) {
                parent.model.previewStore[parent.index].image = image
                parent.model.previewStore[parent.index].data = imageData.jpegData(compressionQuality: 0.9)
            }
        }

        // MARK: -

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        func previewController(_ controller: QLPreviewController, editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode {
            return .createCopy
        }

        func previewController(_ controller: QLPreviewController, didSaveEditedCopyOf previewItem: QLPreviewItem, at modifiedContentsURL: URL) {
            guard NCUtilityFileSystem().moveFile(atPath: modifiedContentsURL.path, toPath: parent.url.path) else { return }
            if let image = UIImage(contentsOfFile: parent.url.path) {
                self.image = image
                self.hasChange = true
            }
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.url as NSURL
        }

        // MARK: -

        func cropViewControllerDidCrop(_ cropViewController: Mantis.CropViewController, cropped: UIImage, transformation: Mantis.Transformation, cropInfo: Mantis.CropInfo) {
            cropViewController.dismiss(animated: true)
            guard let data = cropped.pngData() else { return }
            do {
                try data.write(to: parent.url)
                self.image = cropped
                self.hasChange = true
                viewController?.reloadData()
            } catch {  }
        }
        func cropViewControllerDidCancel(_ cropViewController: Mantis.CropViewController, original: UIImage) {
            cropViewController.dismiss(animated: true)
        }

        func cropViewControllerDidFailToCrop(_ cropViewController: Mantis.CropViewController, original: UIImage) {}
        func cropViewControllerDidBeginResize(_ cropViewController: Mantis.CropViewController) {}
        func cropViewControllerDidEndResize(_ cropViewController: Mantis.CropViewController, original: UIImage, cropInfo: Mantis.CropInfo) {}
        func cropViewControllerDidImageTransformed(_ cropViewController: Mantis.CropViewController) { }

        @objc func crop() {

            guard let image = UIImage(contentsOfFile: parent.url.path) else { return }

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

            viewController?.present(cropViewController, animated: true)
        }
    }

    class CropToolbarIcon: CropToolbarIconProvider {
        func getCropIcon() -> UIImage? {
            return NCUtility().loadImage(named: "checkmark.circle")
        }

        func getCancelIcon() -> UIImage? {
            return NCUtility().loadImage(named: "xmark.circle")
        }
    }
}
