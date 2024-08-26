//
//  NCDocumentCamera.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 03/01/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
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
            let fileNamePath = utilityFileSystem.directoryScan + "/" + fileName
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
