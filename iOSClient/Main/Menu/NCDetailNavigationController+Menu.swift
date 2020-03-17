//
//  NCDetailNavigationController+Menu.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 07/02/2020.
//  Copyright © 2020 Marino Faggiana All rights reserved.
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

import FloatingPanel
import NCCommunication

extension NCDetailNavigationController {

    private func initMoreMenu(viewController: UIViewController, metadata: tableMetadata) -> [NCMenuAction] {
        var actions = [NCMenuAction]()
        let fileNameExtension = (metadata.fileNameView as NSString).pathExtension.uppercased()
        let directEditingCreators = NCManageDatabase.sharedInstance.getDirectEditingCreators(account: appDelegate.activeAccount)

        actions.append(
            NCMenuAction(title: NSLocalizedString("_open_in_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "openFile"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    NCMainCommon.sharedInstance.downloadOpen(metadata: metadata, selector: selectorOpenInDetail)
                }
            )
        )

        actions.append(
            NCMenuAction(title: NSLocalizedString("_share_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "share"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    NCMainCommon.sharedInstance.openShare(ViewController: viewController, metadata: metadata, indexPage: 0)
                }
            )
        )
        
        actions.append(
            NCMenuAction(title: NSLocalizedString("_delete_", comment: ""),
                         icon: CCGraphics.changeThemingColorImage(UIImage(named: "trash"), width: 50, height: 50, color: .red),
                action: { menuAction in
                    
                    let alertController = UIAlertController(title: "", message: NSLocalizedString("_want_delete_", comment: ""), preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_delete_", comment: ""), style: .default) { (action:UIAlertAction) in
                        NCNetworking.sharedInstance.deleteMetadata(metadata, user: self.appDelegate.activeUser, userID: self.appDelegate.activeUserID, password: self.appDelegate.activePassword, url: self.appDelegate.activeUrl) { (errorCode, errorDescription) in }
                    })
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_delete_", comment: ""), style: .default) { (action:UIAlertAction) in })
                                        
                    self.present(alertController, animated: true, completion:nil)
                }
            )
        )
        
        if appDelegate.activeDetail.viewerImageViewController != nil && !CCUtility.fileProviderStorageExists(appDelegate.activeDetail.metadata?.ocId, fileNameView: appDelegate.activeDetail.metadata?.fileNameView) && metadata.session == "" && metadata.typeFile == k_metadataTypeFile_image {
            actions.append(
                NCMenuAction(title: NSLocalizedString("_download_image_max_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "downloadImageFullRes"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        self.appDelegate.activeDetail.downloadImage()
                    }
                )
            )
        }
        
        if appDelegate.activeDetail.viewerImageViewController != nil {
            if let metadataMov = appDelegate.activeDetail.hasMOV(metadata: metadata) {
                if CCUtility.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView) > 0 && CCUtility.fileProviderStorageSize(metadataMov.ocId, fileNameView: metadataMov.fileNameView) > 0 {
                    actions.append(
                        NCMenuAction(title: NSLocalizedString("_xxxxxxx_", comment: ""),
                            icon: CCGraphics.changeThemingColorImage(UIImage(named: "livePhoto"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                            action: { menuAction in
                                self.appDelegate.activeDetail.saveLivePhoto(metadata: metadata, metadataMov: metadataMov)
                            }
                        )
                    )
                }
            }
        }
                
        if CCUtility.isDocumentModifiableExtension(fileNameExtension) && (directEditingCreators == nil || !appDelegate.reachability.isReachable()) {
            actions.append(
                NCMenuAction(title: NSLocalizedString("_internal_modify_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "edit"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        if let navigationController = UIStoryboard(name: "NCText", bundle: nil).instantiateViewController(withIdentifier: "NCText") as? UINavigationController {
                            navigationController.modalPresentationStyle = .pageSheet
                            navigationController.modalTransitionStyle = .crossDissolve
                            if let textViewController = navigationController.topViewController as? NCText {
                                textViewController.metadata = metadata;
                                viewController.present(navigationController, animated: true, completion: nil)
                            }
                        }
                    }
                )
            )
        }
        
        actions.append(
            NCMenuAction(title: NSLocalizedString("_close_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "exit"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    self.appDelegate.activeDetail.viewUnload()
                }
            )
        )
        
        return actions
    }

    @objc func toggleMoreMenu(viewController: UIViewController, metadata: tableMetadata) {
        if appDelegate.activeDetail.subViewActive() != nil {
            let mainMenuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateViewController(withIdentifier: "NCMainMenuTableViewController") as! NCMainMenuTableViewController
            mainMenuViewController.actions = self.initMoreMenu(viewController: viewController, metadata: metadata)

            let menuPanelController = NCMenuPanelController()
            menuPanelController.parentPresenter = viewController
            menuPanelController.delegate = mainMenuViewController
            menuPanelController.set(contentViewController: mainMenuViewController)
            menuPanelController.track(scrollView: mainMenuViewController.tableView)

            viewController.present(menuPanelController, animated: true, completion: nil)
        }
    }
}

