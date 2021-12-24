//
//  NCShare+Menu.swift
//  Nextcloud
//
//  Created by Henrik Storch on 13.12.21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import Foundation
import UIKit

extension NCShare {

    func toggleMenuShareLink(tableShare: tableShare, metadata: tableMetadata, icon: UIImage?) {
        
        var actions = [NCMenuAction]()
        let permissionIx: Int
        let hasPassword = tableShare.shareWith.count > 0

        if metadata.directory {
            // File Drop
            if tableShare.permissions == NCGlobal.shared.permissionCreateShare {
                permissionIx = 2
            } else {
                // Read Only
                if CCUtility.isAnyPermission(toEdit: tableShare.permissions) {
                    permissionIx = 1
                } else {
                    permissionIx = 0
                }
            }
        } else {
            // Allow editing
            if CCUtility.isAnyPermission(toEdit: tableShare.permissions) {
                permissionIx = 1
            } else {
                //default: read only
                permissionIx = 0
            }
        }
        
        
        
//        // Set expiration date
//        if tableShare.expirationDate != nil {
//            switchSetExpirationDate.setOn(true, animated: false)
//            fieldSetExpirationDate.isEnabled = true
//
//            let dateFormatter = DateFormatter()
//            dateFormatter.formatterBehavior = .behavior10_4
//            dateFormatter.dateStyle = .medium
//            fieldSetExpirationDate.text = dateFormatter.string(from: tableShare.expirationDate! as Date)
//        } else {
//            switchSetExpirationDate.setOn(false, animated: false)
//            fieldSetExpirationDate.isEnabled = false
//            fieldSetExpirationDate.text = ""
//        }


        let title = tableShare.label.isEmpty ? NSLocalizedString("_share_link", comment: "") : tableShare.label
        actions.append(NCMenuButton(title: title, icon: icon, action: nil))
        actions.append(NCMenuTextField(
            title: NSLocalizedString("_Link_name_", comment: ""),
            icon: nil,
            text: tableShare.label,
            placeholder: NSLocalizedString("_Link_name_", comment: ""),
            onCommit: { newName in
                self.networking?.updateShare(idShare: tableShare.idShare, password: nil, permissions: tableShare.permissions, note: nil, label: newName, expirationDate: nil, hideDownload: tableShare.hideDownload)
            }))

        let pemissionButtonGroup = NCMenuButtonGroup(title: "_permissions_", selectedIx: permissionIx, actions: [
            NCMenuButton(
                title: "_share_read_only_",
                icon: nil,
                action: { button in
                    let permissions = CCUtility.getPermissionsValue(byCanEdit: false, andCanCreate: false, andCanChange: false, andCanDelete: false, andCanShare: false, andIsFolder: metadata.directory)
                    print(button.title, permissions)
                }),
            NCMenuButton(
                title: "_share_allow_editing_",
                icon: nil,
                action: { button in
                    let permissions = CCUtility.getPermissionsValue(
                        byCanEdit: true,
                        andCanCreate: true,
                        andCanChange: true,
                        andCanDelete: true,
                        andCanShare: false,
                        andIsFolder: metadata.directory)
                    print(button.title, permissions)
                    //                self.networking?.updateShare(idShare: tableShare.idShare, password: nil, permissions: permissions, note: nil, label: nil, expirationDate: nil, hideDownload: tableShare.hideDownload)
                }),
            NCMenuButton(
                title: "_share_file_drop_",
                icon: nil,
                action: { button in
                    let permissions = NCGlobal.shared.permissionCreateShare
                    print(button.title, permissions)
                })
        ])
        
        actions.append(pemissionButtonGroup)
        
//        actions.append(NCMenuToggle(
//            title: NSLocalizedString("_share_allow_editing_", comment: ""),
//            icon: nil,
//            isOn: allowUploadAndEditing,
//            onChange: { isOn in
//                var permissions = CCUtility.getPermissionsValue(
//                    byCanEdit: isOn,
//                    andCanCreate: isOn,
//                    andCanChange: isOn,
//                    andCanDelete: isOn,
//                    andCanShare: false, andIsFolder: metadata.directory)
//
//                self.networking?.updateShare(idShare: tableShare.idShare, password: nil, permissions: permissions, note: nil, label: nil, expirationDate: nil, hideDownload: tableShare.hideDownload)
//            }))
//        actions.append(NCMenuToggle(
//            title: NSLocalizedString("_share_file_drop_", comment: ""),
//            icon: nil,
//            isOn: canDropFile,
//            onChange: { isOn in
//                if isOn, tableShare.permissions != NCGlobal.shared.permissionCreateShare {
//                    switchReadOnly.setOn(false, animated: false)
//                    switchAllowUploadAndEditing.setOn(false, animated: false)
//                    networking?.updateShare(idShare: tableShare.idShare, password: nil, permissions: permissions, note: nil, label: nil, expirationDate: nil, hideDownload: tableShare.hideDownload)
//                } else {
//                    sender.setOn(true, animated: false)
//                }
//            }))
        
        presentMenu(with: actions)
    }
}
