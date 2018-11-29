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
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    let fontButton = [NSAttributedString.Key.font:UIFont(name: "HelveticaNeue", size: 16)!, NSAttributedString.Key.foregroundColor: UIColor.black]
    let fontEncrypted = [NSAttributedString.Key.font:UIFont(name: "HelveticaNeue", size: 16)!, NSAttributedString.Key.foregroundColor: NCBrandColor.sharedInstance.encrypted as UIColor]
    let fontCancel = [NSAttributedString.Key.font:UIFont(name: "HelveticaNeue-Bold", size: 17)!, NSAttributedString.Key.foregroundColor: UIColor.black]
    let fontDisable = [NSAttributedString.Key.font:UIFont(name: "HelveticaNeue", size: 16)!, NSAttributedString.Key.foregroundColor: UIColor.darkGray]
    
    var colorIcon = NCBrandColor.sharedInstance.brandElement
    
    @objc init (themingColor : UIColor) {
        
        super.init()
        colorIcon = themingColor
    }
    
    @objc func createMenu(viewController: UIViewController, view : UIView) {
        
        var items = [ActionSheetItem]()
        
        items.append(ActionSheetItem(title: NSLocalizedString("_upload_photos_videos_", comment: ""), value: 1, image: CCGraphics.changeThemingColorImage(UIImage(named: "media"), multiplier:1, color: NCBrandColor.sharedInstance.icon)))
        
        items.append(ActionSheetItem(title: NSLocalizedString("_upload_file_", comment: ""), value: 2, image: CCGraphics.changeThemingColorImage(UIImage(named: "file"), multiplier:1, color: NCBrandColor.sharedInstance.icon)))
        
        items.append(ActionSheetItem(title: NSLocalizedString("_upload_file_text_", comment: ""), value: 3, image: CCGraphics.changeThemingColorImage(UIImage(named: "file_txt"), multiplier:1, color: NCBrandColor.sharedInstance.icon)))
        
#if !targetEnvironment(simulator)
        if #available(iOS 11.0, *) {
            items.append(ActionSheetItem(title: NSLocalizedString("_scans_document_", comment: ""), value: 4, image: CCGraphics.changeThemingColorImage(UIImage(named: "scan"), multiplier:2, color: NCBrandColor.sharedInstance.icon)))
        }
#endif
        
        items.append(ActionSheetItem(title: NSLocalizedString("_create_folder_", comment: ""), value: 5, image: CCGraphics.changeThemingColorImage(UIImage(named: "folder"), multiplier:1, color: colorIcon)))
        
        // items.append(ActionSheetSectionTitle(title: "Cheap"))
        // items.append(ActionSheetSectionMargin())
        
        /*
         let appearanceSectionMargin = ActionSheetAppearance.standard
         //appearanceSectionMargin. = 10
         appearanceSectionMargin.backgroundColor = UIColor.red
         let itemSectionMargin = ActionSheetSectionTitle(title: "Cheap")
         itemSectionMargin.customAppearance = appearanceSectionMargin
         items.append(itemSectionMargin)
         */
        
        if let richdocumentsMimetypes = NCManageDatabase.sharedInstance.getRichdocumentsMimetypes() {
            if richdocumentsMimetypes.count > 0 {
                items.append(ActionSheetItem(title: NSLocalizedString("_create_new_document_", comment: ""), value: 6, image: UIImage.init(named: "document_menu")))
                items.append(ActionSheetItem(title: NSLocalizedString("_create_new_spreadsheet_", comment: ""), value: 7, image: UIImage(named: "file_xls_menu")))
                items.append(ActionSheetItem(title: NSLocalizedString("_create_new_presentation_", comment: ""), value: 8, image: UIImage(named: "file_ppt_menu")))
            }
        }
        
        items.append(ActionSheetCancelButton(title: NSLocalizedString("_cancel_", comment: "")))
        
        let actionSheet = ActionSheet(items: items) { sheet, item in
            if item.value as? Int == 1 { self.appDelegate.activeMain.openAssetsPickerController() }
            if item.value as? Int == 2 { self.appDelegate.activeMain.openImportDocumentPicker() }
            if item.value as? Int == 3 {
                let storyboard = UIStoryboard(name: "NCText", bundle: nil)
                let controller = storyboard.instantiateViewController(withIdentifier: "NCText")
                controller.modalPresentationStyle = UIModalPresentationStyle.pageSheet
                self.appDelegate.activeMain.present(controller, animated: true, completion: nil)
            }
            if item.value as? Int == 4 {
                if #available(iOS 11.0, *) {
                    NCCreateScanDocument.sharedInstance.openScannerDocument(viewController: self.appDelegate.activeMain, openScan: true)
                }
            }
            if item.value as? Int == 5 { self.appDelegate.activeMain.createFolder() }
            
            if item.value as? Int == 6 {
                guard let navigationController = UIStoryboard(name: "NCCreateFormUploadRichdocuments", bundle: nil).instantiateInitialViewController() else {
                    return
                }
                navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet
                
                let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadRichdocuments
                viewController.typeTemplate = k_richdocument_document
                viewController.serverUrl = self.appDelegate.activeMain.serverUrl
                viewController.titleForm = NSLocalizedString("_create_new_document_", comment: "")
                
                self.appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
            }
            if item.value as? Int == 7 {
                guard let navigationController = UIStoryboard(name: "NCCreateFormUploadRichdocuments", bundle: nil).instantiateInitialViewController() else {
                    return
                }
                navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet
                
                let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadRichdocuments
                viewController.typeTemplate = k_richdocument_spreadsheet
                viewController.serverUrl = self.appDelegate.activeMain.serverUrl
                viewController.titleForm = NSLocalizedString("_create_new_spreadsheet_", comment: "")
                
                self.appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
            }
            if item.value as? Int == 8 {
                guard let navigationController = UIStoryboard(name: "NCCreateFormUploadRichdocuments", bundle: nil).instantiateInitialViewController() else {
                    return
                }
                navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet
                
                let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadRichdocuments
                viewController.typeTemplate = k_richdocument_presentation
                viewController.serverUrl = self.appDelegate.activeMain.serverUrl
                viewController.titleForm = NSLocalizedString("_create_new_presentation_", comment: "")
                
                self.appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
            }
            
            if item is ActionSheetCancelButton { print("Cancel buttons has the value `true`") }
        }
        
        actionSheet.present(in: viewController, from: view)
    }
}
