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

extension AppDelegate: NCAudioRecorderViewControllerDelegate {
    
    @objc public func showMenuIn(viewController: UIViewController) {
        
        let mainMenuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateViewController(withIdentifier: "NCMainMenuTableViewController") as! NCMainMenuTableViewController
        mainMenuViewController.actions = self.initMenu(viewController: viewController)

        let menuPanelController = NCMenuPanelController()
        menuPanelController.parentPresenter = viewController
        menuPanelController.delegate = mainMenuViewController
        menuPanelController.set(contentViewController: mainMenuViewController)
        menuPanelController.track(scrollView: mainMenuViewController.tableView)

        viewController.present(menuPanelController, animated: true, completion: nil)
    }
    
    private func initMenu(viewController: UIViewController) -> [NCMenuAction] {
        
        var actions: [NCMenuAction] = []
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let directEditingCreators = NCManageDatabase.shared.getDirectEditingCreators(account: appDelegate.account)
        let isEncrypted = CCUtility.isFolderEncrypted(appDelegate.activeServerUrl, e2eEncrypted: false, account: appDelegate.account, urlBase: appDelegate.urlBase)
        let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, appDelegate.activeServerUrl))
        let serverVersionMajor = NCManageDatabase.shared.getCapabilitiesServerInt(account: appDelegate.account, elements: NCElementsJSON.shared.capabilitiesVersionMajor)
        
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_upload_photos_videos_", comment: ""), icon: UIImage(named: "file_photo")!.image(color: NCBrandColor.shared.icon, size: 50), action: { menuAction in
                    NCPhotosPickerViewController.init(viewController: appDelegate.window.rootViewController!, maxSelectedAssets: 0, singleSelectedMode: false)
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_upload_file_", comment: ""), icon: UIImage(named: "file")!.image(color: NCBrandColor.shared.icon, size: 50), action: { menuAction in
                    if let tabBarController = self.window.rootViewController as? UITabBarController {
                        self.documentPickerViewController = NCDocumentPickerViewController.init(tabBarController: tabBarController)
                    }
                }
            )
        )

        #if HC
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_im_create_new_file", tableName: "IMLocalizable", bundle: Bundle.main, value: "", comment: ""), icon: UIImage(named: "imagemeter")!.image(color: NCBrandColor.shared.icon, size: 50), action: { menuAction in
                    _ = IMCreate.init(serverUrl: appDelegate.activeServerUrl, imagemeterViewerDelegate: NCNetworkingMain.shared)
                }
            )
        )
        #endif
      
        if NCCommunication.shared.isNetworkReachable() && directEditingCreators != nil && directEditingCreators!.contains(where: { $0.editor == NCBrandGlobal.shared.editorText}) && !isEncrypted {
            let directEditingCreator = directEditingCreators!.first(where: { $0.editor == NCBrandGlobal.shared.editorText})!
            actions.append(
                NCMenuAction(title: NSLocalizedString("_create_nextcloudtext_document_", comment: ""), icon: UIImage(named: "file_txt")!.image(color: NCBrandColor.shared.icon, size: 50), action: { menuAction in
                    guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                        return
                    }
                    navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet
                    
                    let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadDocuments
                    viewController.editorId = NCBrandGlobal.shared.editorText
                    viewController.creatorId = directEditingCreator.identifier
                    viewController.typeTemplate = NCBrandGlobal.shared.templateDocument
                    viewController.serverUrl = appDelegate.activeServerUrl
                    viewController.titleForm = NSLocalizedString("_create_nextcloudtext_document_", comment: "")

                    appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
                })
            )
        } 
        
        if #available(iOS 13.0, *) {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_scans_document_", comment: ""), icon: UIImage(named: "scan")!.image(color: NCBrandColor.shared.icon, size: 50), action: { menuAction in
                        NCCreateScanDocument.shared.openScannerDocument(viewController: appDelegate.window.rootViewController!)
                    }
                )
            )
        }
        
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_create_voice_memo_", comment: ""), icon: UIImage(named: "microphone")!.image(color: NCBrandColor.shared.icon, size: 50), action: { menuAction in
                    
                    NCAskAuthorization.shared.askAuthorizationAudioRecord(viewController: viewController) { (permissions) in
                        if permissions {
                            let fileName = CCUtility.createFileNameDate(NSLocalizedString("_voice_memo_filename_", comment: ""), extension: "m4a")!
                            let viewController = UIStoryboard(name: "NCAudioRecorderViewController", bundle: nil).instantiateInitialViewController() as! NCAudioRecorderViewController
                        
                            viewController.delegate = self
                            viewController.createRecorder(fileName: fileName)
                            viewController.modalTransitionStyle = .crossDissolve
                            viewController.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
                        
                            appDelegate.window.rootViewController?.present(viewController, animated: true, completion: nil)
                        }
                    }
                }
            )
        )

        actions.append(
            NCMenuAction(title: NSLocalizedString("_create_folder_", comment: ""),
                icon: UIImage(named: "folder")!.image(color: NCBrandColor.shared.brandElement, size: 50), action: { menuAction in
                    
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
                                    NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCBrandGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
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

        if serverVersionMajor >= NCBrandGlobal.shared.nextcloudVersion18 && directory?.richWorkspace == nil && !isEncrypted && NCCommunication.shared.isNetworkReachable() {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_add_folder_info_", comment: ""), icon: UIImage(named: "addFolderInfo")!.image(color: NCBrandColor.shared.icon, size: 50), action: { menuAction in
                        let richWorkspaceCommon = NCRichWorkspaceCommon()
                        if let viewController = self.activeViewController {
                            if NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView LIKE[c] %@", appDelegate.account, appDelegate.activeServerUrl, NCBrandGlobal.shared.fileNameRichWorkspace.lowercased())) == nil {
                                richWorkspaceCommon.createViewerNextcloudText(serverUrl: appDelegate.activeServerUrl, viewController: viewController)
                            } else {
                                richWorkspaceCommon.openViewerNextcloudText(serverUrl: appDelegate.activeServerUrl, viewController: viewController)
                            }
                        }
                    }
                )
            )
        }
               
        if NCCommunication.shared.isNetworkReachable() && directEditingCreators != nil && directEditingCreators!.contains(where: { $0.editor == NCBrandGlobal.shared.editorOnlyoffice && $0.identifier == NCBrandGlobal.shared.onlyofficeDocx}) && !isEncrypted {
            let directEditingCreator = directEditingCreators!.first(where: { $0.editor == NCBrandGlobal.shared.editorOnlyoffice && $0.identifier == NCBrandGlobal.shared.onlyofficeDocx})!
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_create_new_document_", comment: ""), icon: UIImage(named: "create_file_document")!, action: { menuAction in
                        guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                            return
                        }
                        navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet

                        let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadDocuments
                        viewController.editorId = NCBrandGlobal.shared.editorOnlyoffice
                        viewController.creatorId = directEditingCreator.identifier
                        viewController.typeTemplate = NCBrandGlobal.shared.templateDocument
                        viewController.serverUrl = appDelegate.activeServerUrl
                        viewController.titleForm = NSLocalizedString("_create_new_document_", comment: "")

                        appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
                    }
                )
            )
        }
        
        if NCCommunication.shared.isNetworkReachable() && directEditingCreators != nil && directEditingCreators!.contains(where: { $0.editor == NCBrandGlobal.shared.editorOnlyoffice && $0.identifier == NCBrandGlobal.shared.onlyofficeXlsx}) && !isEncrypted {
            let directEditingCreator = directEditingCreators!.first(where: { $0.editor == NCBrandGlobal.shared.editorOnlyoffice && $0.identifier == NCBrandGlobal.shared.onlyofficeXlsx})!
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_create_new_spreadsheet_", comment: ""), icon: UIImage(named: "create_file_xls")!, action: { menuAction in
                        guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                            return
                        }
                        navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet

                        let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadDocuments
                        viewController.editorId = NCBrandGlobal.shared.editorOnlyoffice
                        viewController.creatorId = directEditingCreator.identifier
                        viewController.typeTemplate = NCBrandGlobal.shared.templateSpreadsheet
                        viewController.serverUrl = appDelegate.activeServerUrl
                        viewController.titleForm = NSLocalizedString("_create_new_spreadsheet_", comment: "")

                        appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
                    }
                )
            )
        }
        
        if NCCommunication.shared.isNetworkReachable() && directEditingCreators != nil && directEditingCreators!.contains(where: { $0.editor == NCBrandGlobal.shared.editorOnlyoffice && $0.identifier == NCBrandGlobal.shared.onlyofficePptx}) && !isEncrypted {
            let directEditingCreator = directEditingCreators!.first(where: { $0.editor == NCBrandGlobal.shared.editorOnlyoffice && $0.identifier == NCBrandGlobal.shared.onlyofficePptx})!
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_create_new_presentation_", comment: ""), icon: UIImage(named: "create_file_ppt")!, action: { menuAction in
                        guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                            return
                        }
                        navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet

                        let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadDocuments
                        viewController.editorId = NCBrandGlobal.shared.editorOnlyoffice
                        viewController.creatorId = directEditingCreator.identifier
                        viewController.typeTemplate = NCBrandGlobal.shared.templatePresentation
                        viewController.serverUrl = appDelegate.activeServerUrl
                        viewController.titleForm = NSLocalizedString("_create_new_presentation_", comment: "")

                        appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
                    }
                )
            )
        }
        
        if let richdocumentsMimetypes = NCManageDatabase.shared.getCapabilitiesServerArray(account: appDelegate.account, elements: NCElementsJSON.shared.capabilitiesRichdocumentsMimetypes) {
            if richdocumentsMimetypes.count > 0 &&  NCCommunication.shared.isNetworkReachable() && !isEncrypted {
                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_create_new_document_", comment: ""), icon: UIImage(named: "create_file_document")!, action: { menuAction in
                            guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                                return
                            }
                            navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet

                            let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadDocuments
                            viewController.editorId = NCBrandGlobal.shared.editorCollabora
                            viewController.typeTemplate = NCBrandGlobal.shared.templateDocument
                            viewController.serverUrl = appDelegate.activeServerUrl
                            viewController.titleForm = NSLocalizedString("_create_nextcloudtext_document_", comment: "")

                            appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
                        }
                    )
                )

                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_create_new_spreadsheet_", comment: ""), icon: UIImage(named: "create_file_xls")!, action: { menuAction in
                            guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                                return
                            }
                            navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet

                            let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadDocuments
                            viewController.editorId = NCBrandGlobal.shared.editorCollabora
                            viewController.typeTemplate = NCBrandGlobal.shared.templateSpreadsheet
                            viewController.serverUrl = appDelegate.activeServerUrl
                            viewController.titleForm = NSLocalizedString("_create_new_spreadsheet_", comment: "")

                            appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
                        }
                    )
                )
                
                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_create_new_presentation_", comment: ""), icon: UIImage(named: "create_file_ppt")!, action: { menuAction in
                            guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                                return
                            }
                            navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet

                            let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadDocuments
                            viewController.editorId = NCBrandGlobal.shared.editorCollabora
                            viewController.typeTemplate = NCBrandGlobal.shared.templatePresentation
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
    
    // MARK: - NCAudioRecorder ViewController Delegate

    func didFinishRecording(_ viewController: NCAudioRecorderViewController, fileName: String) {
        
        guard let navigationController = UIStoryboard(name: "NCCreateFormUploadVoiceNote", bundle: nil).instantiateInitialViewController() else { return }
        navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadVoiceNote
        viewController.setup(serverUrl: appDelegate.activeServerUrl, fileNamePath: NSTemporaryDirectory() + fileName, fileName: fileName)
        appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
    }
    
    func didFinishWithoutRecording(_ viewController: NCAudioRecorderViewController, fileName: String) { }
}
