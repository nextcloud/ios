//
//  AppDelegate+Menu.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 24.01.20.
//  Copyright © 2020 TWS. All rights reserved.
//

import FloatingPanel

extension AppDelegate {

    private func initMenu() -> [MenuAction] {
        var actions = [MenuAction]()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        var isNextcloudTextAvailable = false

        if appDelegate.reachability.isReachable() && NCBrandBeta.shared.directEditing && NCManageDatabase.sharedInstance.getDirectEditingCreators(account: appDelegate.activeAccount) != nil {
            isNextcloudTextAvailable = true
        }

        actions.append(MenuAction(title: NSLocalizedString("_upload_photos_videos_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "file_photo"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                appDelegate.activeMain.openAssetsPickerController()
            }))

        actions.append(MenuAction(title: NSLocalizedString("_upload_file_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "file"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
            action: { menuAction in
                appDelegate.activeMain.openImportDocumentPicker()
            }))

        if NCBrandOptions.sharedInstance.use_imi_viewer {
            actions.append(MenuAction(title: NSLocalizedString("_im_create_new_file", tableName: "IMLocalizable", bundle: Bundle.main, value: "", comment: ""), icon: CCGraphics.scale(UIImage.init(named: "imagemeter"), to: CGSize(width: 25, height: 25), isAspectRation: true), action: { menuAction in
                    _ = IMCreate.init(serverUrl: appDelegate.activeMain.serverUrl)
                }))
        }

        if isNextcloudTextAvailable {
            actions.append(MenuAction(title: NSLocalizedString("_create_nextcloudtext_document_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "file_txt"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                    guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                        return
                    }
                    navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet

                    let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadDocuments
                    viewController.typeTemplate = k_nextcloudtext_document
                    viewController.serverUrl = appDelegate.activeMain.serverUrl
                    viewController.titleForm = NSLocalizedString("_create_nextcloudtext_document_", comment: "")

                    appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
                }))
        } else {
            actions.append(MenuAction(title: NSLocalizedString("_upload_file_text_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "file_txt"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                    let storyboard = UIStoryboard(name: "NCText", bundle: nil)
                    let controller = storyboard.instantiateViewController(withIdentifier: "NCText")
                    controller.modalPresentationStyle = UIModalPresentationStyle.pageSheet
                    appDelegate.activeMain.present(controller, animated: true, completion: nil)
                }))
        }

        #if !targetEnvironment(simulator)
            if #available(iOS 11.0, *) {
                actions.append(MenuAction(title: NSLocalizedString("_scans_document_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "scan"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)), action: { menuAction in
                        if #available(iOS 11.0, *) {
                            NCCreateScanDocument.sharedInstance.openScannerDocument(viewController: appDelegate.activeMain)
                        }
                    })
            }
        #endif

        actions.append(MenuAction(title: NSLocalizedString("_create_voice_memo_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "microphone"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                NCMainCommon.sharedInstance.startAudioRecorder()
            }))

        actions.append(MenuAction(title: NSLocalizedString("_create_folder_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                appDelegate.activeMain.createFolder()
            }))

        if let richdocumentsMimetypes = NCManageDatabase.sharedInstance.getRichdocumentsMimetypes(account: appDelegate.activeAccount) {
            if richdocumentsMimetypes.count > 0 {
                actions.append(MenuAction(title: NSLocalizedString("_create_new_document_", comment: ""), icon: UIImage.init(named: "create_file_document")!,
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
                    }))
                actions.append(MenuAction(title: NSLocalizedString("_create_new_spreadsheet_", comment: ""), icon: UIImage(named: "create_file_xls")!,
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
                    }))
                actions.append(MenuAction(title: NSLocalizedString("_create_new_presentation_", comment: ""), icon: UIImage(named: "create_file_ppt")!,
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
                    }))
            }
        }

        return actions
    }

    @objc public func showMenuIn(viewController: UIViewController) {
        let mainMenuViewController = UIStoryboard.init(name: "Menu", bundle: nil).instantiateViewController(withIdentifier: "MainMenuTableViewController") as! MainMenuTableViewController
        mainMenuViewController.actions = self.initMenu()

        let menuPanelController = MenuPanelController()
        menuPanelController.panelWidth = Int(viewController.view.frame.width)
        menuPanelController.delegate = mainMenuViewController
        menuPanelController.set(contentViewController: mainMenuViewController)
        menuPanelController.track(scrollView: mainMenuViewController.tableView)
        
        viewController.present(menuPanelController, animated: true, completion: nil)
    }
}
