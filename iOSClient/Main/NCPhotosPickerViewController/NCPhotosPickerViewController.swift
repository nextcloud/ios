//
//  NCPhotosPickerViewController.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 11/11/2018.
//  Copyright (c) 2017 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
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

class NCPhotosPickerViewController: NSObject {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var sourceViewController : UIViewController

    @objc init (_ viewController : UIViewController) {
        sourceViewController = viewController
    }
    
    @objc func openPhotosPickerViewController(phAssets: @escaping ([PHAsset]) -> ()) {
        
        var selectedPhAssets = [PHAsset]()
        var configure = TLPhotosPickerConfigure()
        
        configure.cancelTitle = NSLocalizedString("_cancel_", comment: "")
        configure.defaultCameraRollTitle = NSLocalizedString("_camera_roll_", comment: "")
        configure.doneTitle = NSLocalizedString("_done_", comment: "")
        configure.emptyMessage = NSLocalizedString("_no_albums_", comment: "")
        configure.tapHereToChange = NSLocalizedString("_tap_here_to_change_", comment: "")
        
        configure.maxSelectedAssets = Int(k_pickerControllerMax)
        configure.selectedColor = NCBrandColor.sharedInstance.brand
        
        let viewController = TLPhotosPickerViewController(withTLPHAssets: { (assets) in
            
            for asset: TLPHAsset in assets {
                if asset.phAsset != nil {
                    selectedPhAssets.append(asset.phAsset!)
                }
            }
            
            phAssets(selectedPhAssets)
            
        }, didCancel: nil)
        
        viewController.didExceedMaximumNumberOfSelection = { (picker) in
            self.appDelegate.messageNotification("_info_", description: "_limited_dimension_", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: Int(k_CCErrorInternalError))
        }
        
        viewController.handleNoAlbumPermissions = { (picker) in
            self.appDelegate.messageNotification("_info_", description: "_denied_album_", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: Int(k_CCErrorInternalError))
        }
        
        viewController.handleNoCameraPermissions = { (picker) in
            self.appDelegate.messageNotification("_info_", description: "_denied_camera_", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: Int(k_CCErrorInternalError))
        }
        
        viewController.configure = configure
        
        sourceViewController.present(viewController, animated: true, completion: nil)
    }
}
