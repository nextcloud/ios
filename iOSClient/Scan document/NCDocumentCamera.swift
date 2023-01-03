//
//  NCDocumentCamera.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 03/01/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import Foundation
import VisionKit

class NCDocumentCamera: NSObject, VNDocumentCameraViewControllerDelegate {
    static let shared: NCDocumentCamera = {
        let instance = NCDocumentCamera()
        return instance
    }()

    var viewController: UIViewController?

    func openScannerDocument(viewController: UIViewController) {

        self.viewController = viewController

        guard VNDocumentCameraViewController.isSupported else { return }

        let controller = VNDocumentCameraViewController()
        controller.delegate = self

        self.viewController?.present(controller, animated: true)
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {

        for pageNumber in 0..<scan.pageCount {
            let fileName = CCUtility.createFileName("scan.png",
                                                    fileDate: Date(),
                                                    fileType: PHAssetMediaType.image,
                                                    keyFileName: NCGlobal.shared.keyFileNameMask,
                                                    keyFileNameType: NCGlobal.shared.keyFileNameType,
                                                    keyFileNameOriginal: NCGlobal.shared.keyFileNameOriginal,
                                                    forcedNewFileName: true)!
            let fileNamePath = CCUtility.getDirectoryScan() + "/" + fileName
            let image = scan.imageOfPage(at: pageNumber)
            do {
                try image.pngData()?.write(to: NSURL.fileURL(withPath: fileNamePath))
            } catch { }
        }

        controller.dismiss(animated: true) {
            if let viewController = self.viewController as? NCScan {
                viewController.loadImage()
            } else {
                let storyboard = UIStoryboard(name: "NCScan", bundle: nil)
                let controller = storyboard.instantiateInitialViewController()!

                controller.modalPresentationStyle = UIModalPresentationStyle.pageSheet
                self.viewController?.present(controller, animated: true, completion: nil)
            }
        }
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
}
