//
//  NCCreateMenuAdd.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 14/11/2018.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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
import Sheeeeeeeeet

class NCCreateMenuAdd: NSObject {

    weak var appDelegate = UIApplication.shared.delegate as! AppDelegate
    var isNextcloudTextAvailable = false

    @objc init(viewController: UIViewController, view: UIView) {
        super.init()

        if self.appDelegate.reachability.isReachable() && NCBrandBeta.shared.directEditing && NCManageDatabase.sharedInstance.getDirectEditingCreators(account: self.appDelegate.activeAccount) != nil {
            isNextcloudTextAvailable = true
        }

        var items = [MenuItem]()

        ActionSheetTableView.appearance().backgroundColor = NCBrandColor.sharedInstance.backgroundForm
        ActionSheetTableView.appearance().separatorColor = NCBrandColor.sharedInstance.separator
        ActionSheetItemCell.appearance().backgroundColor = NCBrandColor.sharedInstance.backgroundForm
        ActionSheetItemCell.appearance().titleColor = NCBrandColor.sharedInstance.textView

        items.append(MenuItem(title: NSLocalizedString("_upload_photos_videos_", comment: ""), value: 10, image: CCGraphics.changeThemingColorImage(UIImage(named: "file_photo"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)))

        items.append(MenuItem(title: NSLocalizedString("_upload_file_", comment: ""), value: 20, image: CCGraphics.changeThemingColorImage(UIImage(named: "file"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)))

        if NCBrandOptions.sharedInstance.use_imi_viewer {
            items.append(MenuItem(title: NSLocalizedString("_im_create_new_file", tableName: "IMLocalizable", bundle: Bundle.main, value: "", comment: ""), value: 21, image: CCGraphics.scale(UIImage(named: "imagemeter"), to: CGSize(width: 25, height: 25), isAspectRation: true)))
        }

        if isNextcloudTextAvailable {
            items.append(MenuItem(title: NSLocalizedString("_create_nextcloudtext_document_", comment: ""), value: 31, image: CCGraphics.changeThemingColorImage(UIImage(named: "file_txt"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)))
        } else {
            items.append(MenuItem(title: NSLocalizedString("_upload_file_text_", comment: ""), value: 30, image: CCGraphics.changeThemingColorImage(UIImage(named: "file_txt"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)))
        }

#if !targetEnvironment(simulator)
        if #available(iOS 11.0, *) {
            items.append(MenuItem(title: NSLocalizedString("_scans_document_", comment: ""), value: 40, image: CCGraphics.changeThemingColorImage(UIImage(named: "scan"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)))
        }
#endif

        items.append(MenuItem(title: NSLocalizedString("_create_voice_memo_", comment: ""), value: 50, image: CCGraphics.changeThemingColorImage(UIImage(named: "microphone"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)))

        items.append(MenuItem(title: NSLocalizedString("_create_folder_", comment: ""), value: 60, image: CCGraphics.changeThemingColorImage(UIImage(named: "folder"), width: 50, height: 50, color: NCBrandColor.sharedInstance.brandElement)))

        if let richdocumentsMimetypes = NCManageDatabase.sharedInstance.getRichdocumentsMimetypes(account: appDelegate.activeAccount) {
            if richdocumentsMimetypes.count > 0 {
                items.append(MenuItem(title: NSLocalizedString("_create_new_document_", comment: ""), value: 70, image: UIImage(named: "create_file_document")))
                items.append(MenuItem(title: NSLocalizedString("_create_new_spreadsheet_", comment: ""), value: 80, image: UIImage(named: "create_file_xls")))
                items.append(MenuItem(title: NSLocalizedString("_create_new_presentation_", comment: ""), value: 90, image: UIImage(named: "create_file_ppt")))
            }
        }

        items.append(CancelButton(title: NSLocalizedString("_cancel_", comment: "")))

        let actionSheet = ActionSheet(menu: Menu(items: items), action: { _, item in

            if item.value as? Int == 10 { self.appDelegate.activeMain.openAssetsPickerController() }
            if item.value as? Int == 20 { self.appDelegate.activeMain.openImportDocumentPicker() }
            if item.value as? Int == 21 {
                _ = IMCreate(serverUrl: self.appDelegate.activeMain.serverUrl)
            }
            if item.value as? Int == 30 {
                let storyboard = UIStoryboard(name: "NCText", bundle: nil)
                let controller = storyboard.instantiateViewController(withIdentifier: "NCText")
                controller.modalPresentationStyle = UIModalPresentationStyle.pageSheet
                self.appDelegate.activeMain.present(controller, animated: true, completion: nil)
            }
            if item.value as? Int == 31 {
                guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                    return
                }
                navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet

                let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadDocuments
                viewController.typeTemplate = k_template_document
                viewController.serverUrl = self.appDelegate.activeMain.serverUrl
                viewController.titleForm = NSLocalizedString("_create_nextcloudtext_document_", comment: "")

                self.appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
            }
            if item.value as? Int == 40 {
                if #available(iOS 11.0, *) {
                    NCCreateScanDocument.sharedInstance.openScannerDocument(viewController: self.appDelegate.activeMain)
                }
            }

            if item.value as? Int == 50 { NCMainCommon.sharedInstance.startAudioRecorder() }

            if item.value as? Int == 60 { self.appDelegate.activeMain.createFolder() }

            if item.value as? Int == 70 {
                guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                    return
                }
                navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet

                let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadDocuments
                viewController.typeTemplate = k_template_document
                viewController.serverUrl = self.appDelegate.activeMain.serverUrl
                viewController.titleForm = NSLocalizedString("_create_new_document_", comment: "")

                self.appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
            }
            if item.value as? Int == 80 {
                guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                    return
                }
                navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet

                let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadDocuments
                viewController.typeTemplate = k_template_spreadsheet
                viewController.serverUrl = self.appDelegate.activeMain.serverUrl
                viewController.titleForm = NSLocalizedString("_create_new_spreadsheet_", comment: "")

                self.appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
            }
            if item.value as? Int == 90 {
                guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                    return
                }
                navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet

                let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadDocuments
                viewController.typeTemplate = k_template_presentation
                viewController.serverUrl = self.appDelegate.activeMain.serverUrl
                viewController.titleForm = NSLocalizedString("_create_new_presentation_", comment: "")

                self.appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
            }

            if item is CancelButton { print("Cancel buttons has the value `true`") }
        })

        actionSheet.present(in: viewController, from: view)

    }
}
