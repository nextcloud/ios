//
//  MainMenuManager.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 16.01.20.
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

extension CCMain {

    private func initSortMenu() -> [MenuAction] {
        var actions = [MenuAction]()

        actions.append(MenuAction(
            title: NSLocalizedString("_order_by_name_a_z_", comment: ""),
            icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "sortFileNameAZ"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
            onTitle: NSLocalizedString("_order_by_name_z_a_", comment: ""),
            onIcon: CCGraphics.changeThemingColorImage(UIImage.init(named: "sortFileNameZA"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
            selected: CCUtility.getOrderSettings() == "fileName",
            on: CCUtility.getAscendingSettings(),
            action: { menuAction in
                if(CCUtility.getOrderSettings() == "fileName" && CCUtility.getAscendingSettings()) {
                    CCUtility.setAscendingSettings(!CCUtility.getAscendingSettings())
                } else {
                    CCUtility.setOrderSettings("fileName")
                    CCUtility.setAscendingSettings(true)
                }

                NotificationCenter.default.post(name: Notification.Name.init(rawValue: "clearDateReadDataSource"), object: nil)
            }))

        actions.append(MenuAction(
            title: NSLocalizedString("_order_by_date_more_recent_", comment: ""),
            icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "sortDateMoreRecent"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
            onTitle: NSLocalizedString("_order_by_date_less_recent_", comment: ""),
            onIcon: CCGraphics.changeThemingColorImage(UIImage.init(named: "sortDateLessRecent"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
            selected: CCUtility.getOrderSettings() == "date",
            on: CCUtility.getAscendingSettings(),
            action: { menuAction in
                if(CCUtility.getOrderSettings() == "date" && CCUtility.getAscendingSettings()) {
                    CCUtility.setAscendingSettings(!CCUtility.getAscendingSettings())
                } else {
                    CCUtility.setOrderSettings("date")
                    CCUtility.setAscendingSettings(true)
                }

                NotificationCenter.default.post(name: Notification.Name.init(rawValue: "clearDateReadDataSource"), object: nil)
            }))

        actions.append(MenuAction(
            title: NSLocalizedString("_order_by_size_smallest_", comment: ""),
            icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "sortSmallest"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
            onTitle: NSLocalizedString("_order_by_size_largest_", comment: ""),
            onIcon: CCGraphics.changeThemingColorImage(UIImage.init(named: "sortLargest"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
            selected: CCUtility.getOrderSettings() == "size",
            on: CCUtility.getAscendingSettings(),
            action: { menuAction in
                if(CCUtility.getOrderSettings() == "size" && CCUtility.getAscendingSettings()) {
                    CCUtility.setAscendingSettings(!CCUtility.getAscendingSettings())
                } else {
                    CCUtility.setOrderSettings("size")
                    CCUtility.setAscendingSettings(true)
                }

                NotificationCenter.default.post(name: Notification.Name.init(rawValue: "clearDateReadDataSource"), object: nil)
            }))

        actions.append(MenuAction(
            title: NSLocalizedString("_directory_on_top_no_", comment: ""),
            icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "foldersOnTop"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
            selected: CCUtility.getDirectoryOnTop(),
            on: CCUtility.getDirectoryOnTop(),
            action: { menuAction in
                CCUtility.setDirectoryOnTop(!CCUtility.getDirectoryOnTop())
                NotificationCenter.default.post(name: Notification.Name.init(rawValue: "clearDateReadDataSource"), object: nil)
            }))

        return actions
    }

    @objc func toggleMenu(viewController: UIViewController) {
        let mainMenuViewController = UIStoryboard.init(name: "Menu", bundle: nil).instantiateViewController(withIdentifier: "MainMenuTableViewController") as! MainMenuTableViewController
        mainMenuViewController.actions = self.initSortMenu()

        let menuPanelController = MenuPanelController()
        menuPanelController.panelWidth = Int(viewController.view.frame.width)
        menuPanelController.delegate = mainMenuViewController
        menuPanelController.set(contentViewController: mainMenuViewController)
        menuPanelController.track(scrollView: mainMenuViewController.tableView)
        
        viewController.present(menuPanelController, animated: true, completion: nil)
    }

    @objc func toggleSelectMenu(viewController: UIViewController) {
        let mainMenuViewController = UIStoryboard.init(name: "Menu", bundle: nil).instantiateViewController(withIdentifier: "MainMenuTableViewController") as! MainMenuTableViewController
        mainMenuViewController.actions = self.initSelectMenu()

        let menuPanelController = MenuPanelController()
        menuPanelController.panelWidth = Int(viewController.view.frame.width)
        menuPanelController.delegate = mainMenuViewController
        menuPanelController.set(contentViewController: mainMenuViewController)
        menuPanelController.track(scrollView: mainMenuViewController.tableView)
        
        viewController.present(menuPanelController, animated: true, completion: nil)
    }


    private func initSelectMenu() -> [MenuAction] {
        var actions = [MenuAction]()

        actions.append(MenuAction(title: NSLocalizedString("_select_all_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "selectFull"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                self.didSelectAll()
            }))

        actions.append(MenuAction(title: NSLocalizedString("_move_selected_files_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "move"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                self.moveOpenWindow(self.tableView.indexPathsForSelectedRows)
            }))

        actions.append(MenuAction(title: NSLocalizedString("_download_selected_files_folders_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "downloadSelectedFiles"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                self.downloadSelectedFilesFolders()
            }))

        actions.append(MenuAction(title: NSLocalizedString("_save_selected_files_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "saveSelectedFiles"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                self.saveSelectedFiles()
            }))

        actions.append(MenuAction(title: NSLocalizedString("_delete_selected_files_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "trash"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                self.deleteFile()
            }))

        return actions
    }

    private func initMoreMenu(indexPath: IndexPath, metadata: tableMetadata, metadataFolder: tableMetadata) -> [MenuAction] {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let autoUploadFileName = NCManageDatabase.sharedInstance.getAccountAutoUploadFileName()
        let autoUploadDirectory = NCManageDatabase.sharedInstance.getAccountAutoUploadDirectory(appDelegate.activeUrl)

        var actions = [MenuAction]()

        if (metadata.directory) {
            var lockDirectory = false
            var isOffline = false
            let isFolderEncrypted = CCUtility.isFolderEncrypted("\(self.serverUrl ?? "")/\(metadata.fileName)", account: appDelegate.activeAccount)
            var passcodeTitle = NSLocalizedString("_protect_passcode_", comment: "")


            let dirServerUrl = CCUtility.stringAppendServerUrl(self.metadata.serverUrl, addFileName: metadata.fileName)!

            if let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.activeAccount, dirServerUrl)) {
                if (CCUtility.getBlockCode() != nil && appDelegate.sessionePasscodeLock == nil) {
                    lockDirectory = true
                }
                if (directory.lock) {
                    passcodeTitle = NSLocalizedString("_protect_passcode_", comment: "")
                }

                isOffline = directory.offline
            }



            actions.append(MenuAction(title: metadata.fileNameView, icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), width: 50, height: 50, color: NCBrandColor.sharedInstance.brandElement), action: { menuAction in
                }))

            actions.append(MenuAction(title: metadata.favorite ? NSLocalizedString("_remove_favorites_", comment: "") : NSLocalizedString("_add_favorites_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "favorite"), width: 50, height: 50, color: NCBrandColor.sharedInstance.yellowFavorite), action: { menuAction in
                    self.settingFavorite(metadata, favorite: !metadata.favorite)
                }))

            if (!lockDirectory && !isFolderEncrypted) {
                actions.append(MenuAction(title: NSLocalizedString("_details_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "details"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                        NCMainCommon.sharedInstance.openShare(ViewController: self, metadata: metadata, indexPage: 0)
                    }))
            }

            if(!(metadata.fileName == autoUploadFileName && metadata.serverUrl == autoUploadDirectory) && !lockDirectory && !metadata.e2eEncrypted) {
                actions.append(MenuAction(title: NSLocalizedString("_rename_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "rename"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                        let alertController = UIAlertController(title: NSLocalizedString("_rename_", comment: ""), message: nil, preferredStyle: .alert)

                        alertController.addTextField { (textField) in
                            textField.text = metadata.fileNameView
                            textField.delegate = self as? UITextFieldDelegate
                            textField.addTarget(self, action: #selector(self.minCharTextFieldDidChange(_:)
                                ), for: UIControl.Event.editingChanged)
                        }

                        let cancelAction = UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: nil)

                        let okAction = UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { action in
                                let fileName = alertController.textFields![0].text
                                self.perform(#selector(self.renameFile(_:)), on: .main, with: [metadata, fileName!], waitUntilDone: false)

                            })
                        okAction.isEnabled = false
                        alertController.addAction(cancelAction)
                        alertController.addAction(okAction)

                        self.present(alertController, animated: true, completion: nil)
                    }))


            }

            if (!(metadata.fileName == autoUploadFileName && metadata.serverUrl == autoUploadDirectory) && !lockDirectory && !isFolderEncrypted) {
                actions.append(MenuAction(title: NSLocalizedString("_move_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "move"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                        self.moveOpenWindow([indexPath])
                    }))
            }

            if (!isFolderEncrypted) {
                actions.append(MenuAction(title: isOffline ? NSLocalizedString("_remove_available_offline_", comment: "") : NSLocalizedString("_set_available_offline_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "offline"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                        NCManageDatabase.sharedInstance.setDirectory(serverUrl: dirServerUrl, offline: !isOffline, account: appDelegate.activeAccount)
                        if(isOffline) {
                            CCSynchronize.shared()?.readFolder(dirServerUrl, selector: selectorReadFolderWithDownload, account: appDelegate.activeAccount)
                        }
                        DispatchQueue.main.async {
                            self.tableView.reloadRows(at: [indexPath], with: .none)
                        }
                    }))
            }

            actions.append(MenuAction(title: passcodeTitle, icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "settingsPasscodeYES"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                    self.perform(#selector(self.comandoLockPassword))
                }))

            if (!metadata.e2eEncrypted && CCUtility.isEnd(toEndEnabled: appDelegate.activeAccount)) {
                actions.append(MenuAction(title: NSLocalizedString("_remove_available_offline_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "lock"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                        DispatchQueue.global(qos: .userInitiated).async {
                            let error = NCNetworkingEndToEnd.sharedManager()?.markFolderEncrypted(onServerUrl: "\(self.serverUrl ?? "")/\(metadata.fileName)", ocId: metadata.ocId, user: appDelegate.activeUser, userID: appDelegate.activeUserID, password: appDelegate.activePassword, url: appDelegate.activeUrl)
                            DispatchQueue.main.async {
                                if(error != nil) {
                                    NCContentPresenter.shared.messageNotification(NSLocalizedString("_e2e_error_mark_folder_", comment: ""), description: error?.localizedDescription, delay: TimeInterval(k_dismissAfterSecond), type: .error, errorCode: (error! as NSError).code)
                                } else {
                                    NCManageDatabase.sharedInstance.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.activeAccount, "\(self.serverUrl ?? "")/\(metadata.fileName)"))
                                    self.readFolder(self.serverUrl)
                                }
                            }
                        }
                    }))
            }

            if (metadata.e2eEncrypted && !metadataFolder.e2eEncrypted && CCUtility.isEnd(toEndEnabled: appDelegate.activeAccount)) {
                actions.append(MenuAction(title: NSLocalizedString("_e2e_remove_folder_encrypted_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "lock"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                        DispatchQueue.global(qos: .userInitiated).async {
                            let error = NCNetworkingEndToEnd.sharedManager()?.deletemarkEndToEndFolderEncrypted(onServerUrl: "\(self.serverUrl ?? "")/\(metadata.fileName)", ocId: metadata.ocId, user: appDelegate.activeUser, userID: appDelegate.activeUserID, password: appDelegate.activePassword, url: appDelegate.activeUrl)
                            DispatchQueue.main.async {
                                if(error != nil) {
                                    NCContentPresenter.shared.messageNotification(NSLocalizedString("_e2e_error_delete_mark_folder_", comment: ""), description: error?.localizedDescription, delay: TimeInterval(k_dismissAfterSecond), type: .error, errorCode: (error! as NSError).code)
                                } else {
                                    NCManageDatabase.sharedInstance.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.activeAccount, "\(self.serverUrl ?? "")/\(metadata.fileName)"))
                                    self.readFolder(self.serverUrl)
                                }
                            }
                        }
                    }))
            }


        } else {
            var iconHeader: UIImage!
            if let icon = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileNameView)) {
                iconHeader = icon
            } else {
                iconHeader = UIImage(named: metadata.iconName)
            }

            actions.append(MenuAction(title: metadata.fileNameView, icon: iconHeader, action: { menuAction in

            }))

            actions.append(MenuAction(title: metadata.favorite ? NSLocalizedString("_remove_favorites_", comment: "") : NSLocalizedString("_add_favorites_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "favorite"), width: 50, height: 50, color: NCBrandColor.sharedInstance.yellowFavorite), action: { menuAction in
                    self.settingFavorite(metadata, favorite: !metadata.favorite)
                }))

            if (!metadataFolder.e2eEncrypted) {
                actions.append(MenuAction(title: NSLocalizedString("_details_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "details"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                        NCMainCommon.sharedInstance.openShare(ViewController: self, metadata: metadata, indexPage: 0)
                    }))
            }

            if(!NCBrandOptions.sharedInstance.disable_openin_file) {
                actions.append(MenuAction(title: NSLocalizedString("_open_in_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "openFile"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                        self.perform(#selector(self.openinFile(_:)))
                    }))
            }

            actions.append(MenuAction(title: NSLocalizedString("_rename_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "rename"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                    let alertController = UIAlertController(title: NSLocalizedString("_rename_", comment: ""), message: nil, preferredStyle: .alert)

                    alertController.addTextField { (textField) in
                        textField.text = metadata.fileNameView
                        textField.delegate = self as? UITextFieldDelegate
                        textField.addTarget(self, action: #selector(self.minCharTextFieldDidChange(_:)
                            ), for: UIControl.Event.editingChanged)
                    }

                    let cancelAction = UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: nil)

                    let okAction = UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { action in
                            let fileName = alertController.textFields![0].text
                            self.perform(#selector(self.renameFile(_:)), on: .main, with: [metadata, fileName!], waitUntilDone: false)

                        })
                    okAction.isEnabled = false
                    alertController.addAction(cancelAction)
                    alertController.addAction(okAction)

                    self.present(alertController, animated: true, completion: nil)
                }))

            if (!metadataFolder.e2eEncrypted) {
                actions.append(MenuAction(title: NSLocalizedString("_move_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "move"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                        self.moveOpenWindow([indexPath])
                    }))
            }

            if(NCUtility.sharedInstance.isEditImage(metadata.fileNameView as NSString) != nil && !metadataFolder.e2eEncrypted && metadata.status == k_metadataStatusNormal) {
                actions.append(MenuAction(title: NSLocalizedString("_modify_photo_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "modifyPhoto"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                        metadata.session = k_download_session
                        metadata.sessionError = ""
                        metadata.sessionSelector = selectorDownloadEditPhoto
                        metadata.status = Int(k_metadataStatusWaitDownload)

                        _ = NCManageDatabase.sharedInstance.addMetadata(metadata)
                        appDelegate.startLoadAutoDownloadUpload()
                    }))
            }

            if (!metadataFolder.e2eEncrypted) {
                let localFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                var title: String!
                if (localFile == nil || localFile!.offline == false) {
                    title = NSLocalizedString("_set_available_offline_", comment: "")
                } else {
                    title = NSLocalizedString("_remove_available_offline_", comment: "");
                }

                actions.append(MenuAction(title: title, icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "offline"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                        if (localFile == nil || !CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView)) {
                            metadata.session = k_download_session
                            metadata.sessionError = ""
                            metadata.sessionSelector = selectorLoadOffline
                            metadata.status = Int(k_metadataStatusWaitDownload)

                            _ = NCManageDatabase.sharedInstance.addMetadata(metadata)
                            NCMainCommon.sharedInstance.reloadDatasource(ServerUrl: self.serverUrl, ocId: metadata.ocId, action: k_action_MOD)
                            appDelegate.startLoadAutoDownloadUpload()
                        } else {
                            NCManageDatabase.sharedInstance.setLocalFile(ocId: metadata.ocId, offline: !localFile!.offline)
                            DispatchQueue.main.async {
                                self.tableView.reloadRows(at: [indexPath], with: .none)
                            }
                        }

                    }))
            }
        }

        actions.append(MenuAction(title: NSLocalizedString("_delete_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "trash"), width: 50, height: 50, color: .red), action: { menuAction in
                self.actionDelete(indexPath)
            }))

        return actions
    }

    @objc func toggleMoreMenu(viewController: UIViewController, indexPath: IndexPath, metadata: tableMetadata, metadataFolder: tableMetadata) {
        let mainMenuViewController = UIStoryboard.init(name: "Menu", bundle: nil).instantiateViewController(withIdentifier: "MainMenuTableViewController") as! MainMenuTableViewController
        mainMenuViewController.actions = self.initMoreMenu(indexPath: indexPath, metadata: metadata, metadataFolder: metadataFolder)

        let menuPanelController = MenuPanelController()
        menuPanelController.panelWidth = Int(viewController.view.frame.width)
        menuPanelController.delegate = mainMenuViewController
        menuPanelController.set(contentViewController: mainMenuViewController)
        menuPanelController.track(scrollView: mainMenuViewController.tableView)
        
        viewController.present(menuPanelController, animated: true, completion: nil)
    }

}

extension CCFavorites {

    private func initMoreMenu(indexPath: IndexPath, metadata: tableMetadata) -> [MenuAction] {
        var actions = [MenuAction]()
        
        var iconHeader: UIImage!
        if let icon = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileNameView)) {
            iconHeader = icon
        } else {
            if(metadata.directory){
                iconHeader = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)
            } else {
                iconHeader = UIImage(named: metadata.iconName)
            }
        }

        actions.append(MenuAction(title: metadata.fileNameView, icon: iconHeader, action: { menuAction in
        }))

        if(self.serverUrl == nil) {
            actions.append(MenuAction(title: NSLocalizedString("_remove_favorites_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "favorite"), width: 50, height: 50, color: NCBrandColor.sharedInstance.yellowFavorite), action: { menuAction in
                self.settingFavorite(metadata, favorite: false)
                }))
        }

        actions.append(MenuAction(title: NSLocalizedString("_details_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "details"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                NCMainCommon.sharedInstance.openShare(ViewController: self, metadata: metadata, indexPage: 0)
            }))

        if(!metadata.directory && !NCBrandOptions.sharedInstance.disable_openin_file) {
            actions.append(MenuAction(title: NSLocalizedString("_open_in_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "openFile"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                    self.tableView.setEditing(false, animated: true)
                    NCMainCommon.sharedInstance.downloadOpen(metadata: metadata, selector: selectorOpenIn)
                }))
        }

        actions.append(MenuAction(title: NSLocalizedString("_delete_", comment: ""), icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "trash"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), action: { menuAction in
                self.actionDelete(indexPath)
            }))

        return actions
    }

    @objc func toggleMoreMenu(viewController: UIViewController, indexPath: IndexPath, metadata: tableMetadata) {
        let mainMenuViewController = UIStoryboard.init(name: "Menu", bundle: nil).instantiateViewController(withIdentifier: "MainMenuTableViewController") as! MainMenuTableViewController
        mainMenuViewController.actions = self.initMoreMenu(indexPath: indexPath, metadata: metadata)

        let menuPanelController = MenuPanelController()
        menuPanelController.panelWidth = Int(viewController.view.frame.width)
        menuPanelController.delegate = mainMenuViewController
        menuPanelController.set(contentViewController: mainMenuViewController)
        menuPanelController.track(scrollView: mainMenuViewController.tableView)
        
        viewController.present(menuPanelController, animated: true, completion: nil)
    }
}
