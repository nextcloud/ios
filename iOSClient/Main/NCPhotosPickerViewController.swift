//
//  NCPhotosPickerViewController.swift
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

import Foundation
import TLPhotoPicker

class NCPhotosPickerViewController: NSObject, createFormUploadAssetsDelegate {

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var sourceViewController: UIViewController
    var maxSelectedAssets = 1
    var singleSelectedMode = false

    @discardableResult
    init (viewController: UIViewController, maxSelectedAssets: Int, singleSelectedMode: Bool) {
        sourceViewController = viewController
        super.init()
        
        self.maxSelectedAssets = maxSelectedAssets
        self.singleSelectedMode = singleSelectedMode
        
        self.openPhotosPickerViewController { (assets) in
            guard let assets = assets else { return }
            if assets.count > 0 {
                
                let mutableAssets = NSMutableArray(array: assets)
                let form = NCCreateFormUploadAssets.init(serverUrl: self.appDelegate.activeServerUrl, assets: mutableAssets, cryptated: false, session: NCNetworking.shared.sessionIdentifierBackground, delegate: self)
                let navigationController = UINavigationController.init(rootViewController: form)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    viewController.present(navigationController, animated: true, completion: nil)
                }
            }
        }
    }
    
    private func openPhotosPickerViewController(completition: @escaping ([PHAsset]?) -> ()) {
        
        var selectedAssets: [PHAsset] = []
        var configure = TLPhotosPickerConfigure()
        
        configure.cancelTitle = NSLocalizedString("_cancel_", comment: "")
        configure.doneTitle = NSLocalizedString("_done_", comment: "")
        configure.emptyMessage = NSLocalizedString("_no_albums_", comment: "")
        configure.tapHereToChange = NSLocalizedString("_tap_here_to_change_", comment: "")
        
        configure.maxSelectedAssets = self.maxSelectedAssets
        configure.selectedColor = NCBrandColor.sharedInstance.brandElement
        configure.singleSelectedMode = singleSelectedMode
        
        let viewController = customPhotoPickerViewController(withTLPHAssets: { (assets) in
            
            for asset: TLPHAsset in assets {
                if asset.phAsset != nil {
                    selectedAssets.append(asset.phAsset!)
                }
            }
            
            completition(selectedAssets)
            
        }, didCancel: nil)
        
        viewController.didExceedMaximumNumberOfSelection = { (picker) in
            NCContentPresenter.shared.messageNotification("_info_", description: "_limited_dimension_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError))
        }
        
        viewController.handleNoAlbumPermissions = { (picker) in
            NCContentPresenter.shared.messageNotification("_info_", description: "_denied_album_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError))
        }
        
        viewController.handleNoCameraPermissions = { (picker) in
            NCContentPresenter.shared.messageNotification("_info_", description: "_denied_camera_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError))
        }
        
        viewController.configure = configure

        sourceViewController.present(viewController, animated: true, completion: nil)
    }
    
    func dismissFormUploadAssets() {
           
    }
}

class customPhotoPickerViewController: TLPhotosPickerViewController {
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func makeUI() {
        super.makeUI()
        
        self.customNavItem.leftBarButtonItem?.tintColor = NCBrandColor.sharedInstance.brandElement
        self.customNavItem.rightBarButtonItem?.tintColor = NCBrandColor.sharedInstance.brandElement
    }
}
