// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import Photos
import VisionKit

class NCDocumentCamera: NSObject, VNDocumentCameraViewControllerDelegate {
    static let shared: NCDocumentCamera = {
        let instance = NCDocumentCamera()
        return instance
    }()
    var viewController: UIViewController?
    let utilityFileSystem = NCUtilityFileSystem()

    func openScannerDocument(viewController: UIViewController?) {
        guard VNDocumentCameraViewController.isSupported else { return }
        self.viewController = viewController
        let controller = VNDocumentCameraViewController()

        controller.delegate = self
        viewController?.present(controller, animated: true)
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        for pageNumber in 0..<scan.pageCount {
            let fileName = utilityFileSystem.createFileName("scan.png", fileDate: Date(), fileType: PHAssetMediaType.image, notUseMask: true)
            let fileNamePath = utilityFileSystem.createServerUrl(serverUrl: utilityFileSystem.directoryScan, fileName: fileName)
            let image = scan.imageOfPage(at: pageNumber)
            do {
                try image.pngData()?.write(to: NSURL.fileURL(withPath: fileNamePath))
            } catch { }
        }

        controller.dismiss(animated: true) {
            if let viewController = self.viewController as? NCScan {
                viewController.loadImage()
            } else if let controller = self.viewController as? NCMainTabBarController {
                if let navigationController = UIStoryboard(name: "NCScan", bundle: nil).instantiateInitialViewController() {
                    navigationController.modalPresentationStyle = UIModalPresentationStyle.pageSheet
                    if let viewController = navigationController.topMostViewController() as? NCScan {
                        viewController.serverUrl = controller.currentServerUrl()
                        viewController.controller = controller
                    }
                    self.viewController?.present(navigationController, animated: true, completion: nil)
                }
            }
        }
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
}
