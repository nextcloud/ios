//
//  AppDelegate+Menu.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 24.01.20.
//  Copyright © 2020 Philippe Weidmann. All rights reserved.
//  Copyright © 2020 Marino Faggiana All rights reserved.
//
//  Author Philippe Weidmann
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

extension AppDelegate {

    private func initMenu() -> [NCMenuAction] {
        var actions = [NCMenuAction]()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        var isNextcloudTextAvailable = false

        if appDelegate.reachability.isReachable() && NCBrandBeta.shared.directEditing && NCManageDatabase.sharedInstance.getDirectEditingCreators(account: appDelegate.activeAccount) != nil {
            isNextcloudTextAvailable = true
        }

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_upload_photos_videos_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "file_photo"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    appDelegate.activeMain.openAssetsPickerController()
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_upload_file_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "file"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    appDelegate.activeMain.openImportDocumentPicker()
                }
            )
        )

        if NCBrandOptions.sharedInstance.use_imi_viewer {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_im_create_new_file", tableName: "IMLocalizable", bundle: Bundle.main, value: "", comment: ""),
                    icon: CCGraphics.scale(UIImage(named: "imagemeter"), to: CGSize(width: 25, height: 25), isAspectRation: true),
                    action: { menuAction in
                        _ = IMCreate.init(serverUrl: appDelegate.activeMain.serverUrl)
                    }
                )
            )
        }

        if isNextcloudTextAvailable {
            actions.append(
                NCMenuAction(title: NSLocalizedString("_create_nextcloudtext_document_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "file_txt"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                            return
                        }
                        navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet

                        let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadDocuments
                        viewController.typeTemplate = k_nextcloudtext_document
                        viewController.serverUrl = appDelegate.activeMain.serverUrl
                        viewController.titleForm = NSLocalizedString("_create_nextcloudtext_document_", comment: "")

                        appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
                    }
                )
            )
        } else {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_upload_file_text_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "file_txt"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        let storyboard = UIStoryboard(name: "NCText", bundle: nil)
                        let controller = storyboard.instantiateViewController(withIdentifier: "NCText")
                        controller.modalPresentationStyle = UIModalPresentationStyle.pageSheet
                        appDelegate.activeMain.present(controller, animated: true, completion: nil)
                    }
                )
            )
        }

        #if !targetEnvironment(simulator)
            if #available(iOS 11.0, *) {
                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_scans_document_", comment: ""),
                        icon: CCGraphics.changeThemingColorImage(UIImage(named: "scan"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                        action: { menuAction in
                            NCCreateScanDocument.sharedInstance.openScannerDocument(viewController: appDelegate.activeMain)
                        }
                    )
                )
            }
        #endif

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_create_voice_memo_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "microphone"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    NCMainCommon.sharedInstance.startAudioRecorder()
                }
            )
        )

        actions.append(
            NCMenuAction(title: NSLocalizedString("_create_folder_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "folder"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    appDelegate.activeMain.createFolder()
                }
            )
        )

        if let capabilities = NCManageDatabase.sharedInstance.getCapabilites(account: appDelegate.activeAccount) {
            if (capabilities.versionMajor >= k_nextcloud_version_18_0 && (self.activeMain.richWorkspaceText == nil || self.activeMain.richWorkspaceText.count == 0)) {
                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_add_folder_info_", comment: ""),
                        icon: CCGraphics.changeThemingColorImage(UIImage(named: "addFolderInfo"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                        action: { menuAction in
                            self.activeMain.createRichWorkspace()
                        }
                    )
                )
            }
        }

        if let richdocumentsMimetypes = NCManageDatabase.sharedInstance.getRichdocumentsMimetypes(account: appDelegate.activeAccount) {
            if richdocumentsMimetypes.count > 0 {
                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_create_new_document_", comment: ""),
                        icon: UIImage(named: "create_file_document")!,
                        action: { menuAction in
                            guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                                return
                            }
                            navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet

                            let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadDocuments
                            viewController.typeTemplate = k_richdocument_document
                            viewController.serverUrl = appDelegate.activeMain.serverUrl
                            viewController.titleForm = NSLocalizedString("_create_new_document_", comment: "")

                            appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
                        }
                    )
                )

                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_create_new_spreadsheet_", comment: ""),
                        icon: UIImage(named: "create_file_xls")!,
                        action: { menuAction in
                            guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                                return
                            }
                            navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet

                            let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadDocuments
                            viewController.typeTemplate = k_richdocument_spreadsheet
                            viewController.serverUrl = appDelegate.activeMain.serverUrl
                            viewController.titleForm = NSLocalizedString("_create_new_spreadsheet_", comment: "")

                            appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
                        }
                    )
                )
                
                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_create_new_presentation_", comment: ""),
                        icon: UIImage(named: "create_file_ppt")!,
                        action: { menuAction in
                            guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                                return
                            }
                            navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet

                            let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadDocuments
                            viewController.typeTemplate = k_richdocument_presentation
                            viewController.serverUrl = appDelegate.activeMain.serverUrl
                            viewController.titleForm = NSLocalizedString("_create_new_presentation_", comment: "")

                            appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
                        }
                    )
                )
            }
        }

        return actions
    }

    @objc public func showMenuIn(viewController: UIViewController) {
        let mainMenuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateViewController(withIdentifier: "NCMainMenuTableViewController") as! NCMainMenuTableViewController
        mainMenuViewController.actions = self.initMenu()

        let menuPanelController = NCMenuPanelController()
        menuPanelController.parentPresenter = viewController
        menuPanelController.delegate = mainMenuViewController
        menuPanelController.set(contentViewController: mainMenuViewController)
        menuPanelController.track(scrollView: mainMenuViewController.tableView)

        viewController.present(menuPanelController, animated: true, completion: nil)
    }
}
