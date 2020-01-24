//
//  NCPhotosPickerViewController.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 11/11/2018.
//  Copyright (c) 2017 Marino Faggiana. All rights reserved.
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

class NCPhotosPickerViewController: NSObject {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var sourceViewController: UIViewController
    var maxSelectedAssets = 1

    @objc init (_ viewController: UIViewController, maxSelectedAssets: Int) {
        sourceViewController = viewController
        self.maxSelectedAssets = maxSelectedAssets
    }
    
    @objc func openPhotosPickerViewController(phAssets: @escaping ([PHAsset]) -> ()) {
        
        var selectedPhAssets = [PHAsset]()
        var configure = TLPhotosPickerConfigure()
        
        configure.cancelTitle = NSLocalizedString("_cancel_", comment: "")
        configure.doneTitle = NSLocalizedString("_done_", comment: "")
        configure.emptyMessage = NSLocalizedString("_no_albums_", comment: "")
        configure.tapHereToChange = NSLocalizedString("_tap_here_to_change_", comment: "")
        
        configure.maxSelectedAssets = self.maxSelectedAssets
        configure.selectedColor = NCBrandColor.sharedInstance.brand
        
        if maxSelectedAssets == 1 {
            configure.singleSelectedMode = true
        }
        
        let viewController = customPhotoPickerViewController(withTLPHAssets: { (assets) in
            
            for asset: TLPHAsset in assets {
                if asset.phAsset != nil {
                    selectedPhAssets.append(asset.phAsset!)
                }
            }
            
            phAssets(selectedPhAssets)
            
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
}

class customPhotoPickerViewController: TLPhotosPickerViewController {
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func makeUI() {
        super.makeUI()
        
        self.customNavItem.leftBarButtonItem?.tintColor = NCBrandColor.sharedInstance.textView
        self.customNavItem.rightBarButtonItem?.tintColor = NCBrandColor.sharedInstance.textView
        
        self.titleLabel.textColor = NCBrandColor.sharedInstance.icon
        self.subTitleLabel.textColor = NCBrandColor.sharedInstance.graySoft
        self.subTitleArrowImageView.image = CCGraphics.changeThemingColorImage(self.subTitleArrowImageView.image, multiplier: 1, color: NCBrandColor.sharedInstance.graySoft)
        
        self.collectionView.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        self.view.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        if CCUtility.getDarkMode() {
            self.navigationBar.barStyle = .black
        }
        self.titleLabel.textColor = NCBrandColor.sharedInstance.textView
        self.subTitleLabel.textColor = NCBrandColor.sharedInstance.textView
    }
}
