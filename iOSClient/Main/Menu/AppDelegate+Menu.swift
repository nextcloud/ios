//
//  AppDelegate+Menu.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 24.01.20.
//  Copyright © 2020 Philippe Weidmann. All rights reserved.
//  Copyright © 2020 Marino Faggiana All rights reserved.
//
//  Author Philippe Weidmann <philippe.weidmann@infomaniak.com>
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

extension AppDelegate {
    
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
    
    private func initMenu() -> [NCMenuAction] {
        
        var actions: [NCMenuAction] = []
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let directEditingCreators = NCManageDatabase.sharedInstance.getDirectEditingCreators(account: appDelegate.account)
        let isEncrypted = CCUtility.isFolderEncrypted(appDelegate.activeServerUrl, e2eEncrypted: false, account: appDelegate.account, urlBase: appDelegate.urlBase)
        let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, appDelegate.activeServerUrl))
        let serverVersionMajor = NCManageDatabase.sharedInstance.getCapabilitiesServerInt(account: appDelegate.account, elements: NCElementsJSON.shared.capabilitiesVersionMajor)
        
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_upload_photos_videos_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "file_photo"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    NCPhotosPickerViewController.init(viewController: appDelegate.window.rootViewController!, maxSelectedAssets: 0, singleSelectedMode: false)
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_upload_file_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "file"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    if let navigationController = (self.window.rootViewController as! UISplitViewController).viewControllers.first as? UINavigationController {
                        if let tabBarController = navigationController.topViewController as? UITabBarController {
                            self.documentPickerViewController = NCDocumentPickerViewController.init(tabBarController: tabBarController)
                        }
                    }
                }
            )
        )

        #if HC
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_im_create_new_file", tableName: "IMLocalizable", bundle: Bundle.main, value: "", comment: ""),
                icon: CCGraphics.scale(UIImage(named: "imagemeter"), to: CGSize(width: 25, height: 25), isAspectRation: true),
                action: { menuAction in
                    _ = IMCreate.init(serverUrl: appDelegate.activeServerUrl, imagemeterViewerDelegate: NCNetworkingMain.sharedInstance)
                }
            )
        )
        #endif
      
        if NCCommunication.shared.isNetworkReachable() && directEditingCreators != nil && directEditingCreators!.contains(where: { $0.editor == k_editor_text}) && !isEncrypted {
            let directEditingCreator = directEditingCreators!.first(where: { $0.editor == k_editor_text})!
            actions.append(
                NCMenuAction(title: NSLocalizedString("_create_nextcloudtext_document_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage(named: "file_txt"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                    guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                        return
                    }
                    navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet
                    
                    let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadDocuments
                    viewController.editorId = k_editor_text
                    viewController.creatorId = directEditingCreator.identifier
                    viewController.typeTemplate = k_template_document
                    viewController.serverUrl = appDelegate.activeServerUrl
                    viewController.titleForm = NSLocalizedString("_create_nextcloudtext_document_", comment: "")

                    appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
                })
            )
        } 
        
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_scans_document_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "scan"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    NCCreateScanDocument.sharedInstance.openScannerDocument(viewController: appDelegate.activeMain)
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_create_voice_memo_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "microphone"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    NCMainCommon.shared.startAudioRecorder()
                }
            )
        )

        actions.append(
            NCMenuAction(title: NSLocalizedString("_create_folder_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "folder"), width: 50, height: 50, color: NCBrandColor.sharedInstance.brandElement),
                action: { menuAction in
                    
                     guard let serverUrl = appDelegate.activeServerUrl else { return }
                    
                     let alertController = UIAlertController(title: NSLocalizedString("_create_folder_on_", comment: ""), message: nil, preferredStyle: .alert)
                    
                     alertController.addTextField { (textField) in
                         textField.autocapitalizationType = UITextAutocapitalizationType.sentences
                     }
                    
                     let cancelAction = UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: nil)
                     let okAction = UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { action in
                         if let fileNameFolder = alertController.textFields?.first?.text {
                             NCNetworking.shared.createFolder(fileName: fileNameFolder, serverUrl: serverUrl, account: appDelegate.account, urlBase: appDelegate.urlBase, overwrite: false) { (errorCode, errorDescription) in
                                 if errorCode != 0 {
                                     NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                                 }
                             }
                         }
                     })
                    
                     alertController.addAction(cancelAction)
                     alertController.addAction(okAction)

                     appDelegate.window.rootViewController?.present(alertController, animated: true, completion: nil)
                }
            )
        )

        if serverVersionMajor >= k_nextcloud_version_18_0 && directory?.richWorkspace == nil && !isEncrypted && NCCommunication.shared.isNetworkReachable() {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_add_folder_info_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "addFolderInfo"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        let richWorkspaceCommon = NCRichWorkspaceCommon()
                        if let viewController = appDelegate.window.rootViewController {
                            if NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView LIKE[c] %@", appDelegate.account, appDelegate.activeServerUrl, k_fileNameRichWorkspace.lowercased())) == nil {
                                richWorkspaceCommon.createViewerNextcloudText(serverUrl: appDelegate.activeServerUrl, viewController: viewController)
                            } else {
                                richWorkspaceCommon.openViewerNextcloudText(serverUrl: appDelegate.activeServerUrl, viewController: viewController)
                            }
                        }
                    }
                )
            )
        }
               
        if NCCommunication.shared.isNetworkReachable() && directEditingCreators != nil && directEditingCreators!.contains(where: { $0.editor == k_editor_onlyoffice && $0.identifier == k_onlyoffice_docx}) && !isEncrypted {
            let directEditingCreator = directEditingCreators!.first(where: { $0.editor == k_editor_onlyoffice && $0.identifier == k_onlyoffice_docx})!
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
                        viewController.editorId = k_editor_onlyoffice
                        viewController.creatorId = directEditingCreator.identifier
                        viewController.typeTemplate = k_template_document
                        viewController.serverUrl = appDelegate.activeServerUrl
                        viewController.titleForm = NSLocalizedString("_create_new_document_", comment: "")

                        appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
                    }
                )
            )
        }
        
        if NCCommunication.shared.isNetworkReachable() && directEditingCreators != nil && directEditingCreators!.contains(where: { $0.editor == k_editor_onlyoffice && $0.identifier == k_onlyoffice_xlsx}) && !isEncrypted {
            let directEditingCreator = directEditingCreators!.first(where: { $0.editor == k_editor_onlyoffice && $0.identifier == k_onlyoffice_xlsx})!
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
                        viewController.editorId = k_editor_onlyoffice
                        viewController.creatorId = directEditingCreator.identifier
                        viewController.typeTemplate = k_template_spreadsheet
                        viewController.serverUrl = appDelegate.activeServerUrl
                        viewController.titleForm = NSLocalizedString("_create_new_spreadsheet_", comment: "")

                        appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
                    }
                )
            )
        }
        
        if NCCommunication.shared.isNetworkReachable() && directEditingCreators != nil && directEditingCreators!.contains(where: { $0.editor == k_editor_onlyoffice && $0.identifier == k_onlyoffice_pptx}) && !isEncrypted {
            let directEditingCreator = directEditingCreators!.first(where: { $0.editor == k_editor_onlyoffice && $0.identifier == k_onlyoffice_pptx})!
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
                        viewController.editorId = k_editor_onlyoffice
                        viewController.creatorId = directEditingCreator.identifier
                        viewController.typeTemplate = k_template_presentation
                        viewController.serverUrl = appDelegate.activeServerUrl
                        viewController.titleForm = NSLocalizedString("_create_new_presentation_", comment: "")

                        appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
                    }
                )
            )
        }
        
        if let richdocumentsMimetypes = NCManageDatabase.sharedInstance.getCapabilitiesServerArray(account: appDelegate.account, elements: NCElementsJSON.shared.capabilitiesRichdocumentsMimetypes) {
            if richdocumentsMimetypes.count > 0 &&  NCCommunication.shared.isNetworkReachable() && !isEncrypted {
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
                            viewController.editorId = k_editor_collabora
                            viewController.typeTemplate = k_template_document
                            viewController.serverUrl = appDelegate.activeServerUrl
                            viewController.titleForm = NSLocalizedString("_create_nextcloudtext_document_", comment: "")

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
                            viewController.editorId = k_editor_collabora
                            viewController.typeTemplate = k_template_spreadsheet
                            viewController.serverUrl = appDelegate.activeServerUrl
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
                            viewController.editorId = k_editor_collabora
                            viewController.typeTemplate = k_template_presentation
                            viewController.serverUrl = appDelegate.activeServerUrl
                            viewController.titleForm = NSLocalizedString("_create_new_presentation_", comment: "")

                            appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
                        }
                    )
                )
            }
        }

        return actions
    }
}
