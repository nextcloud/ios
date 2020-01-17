//
//  MainMenuTableViewController.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 16.01.20.
//  Copyright © 2020 TWS. All rights reserved.
//

import UIKit
import FloatingPanel

class MainMenuTableViewController: UITableViewController{
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var isNextcloudTextAvailable = false
    var actions = [MenuAction]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if self.appDelegate.reachability.isReachable() && NCBrandBeta.shared.directEditing && NCManageDatabase.sharedInstance.getDirectEditingCreators(account: self.appDelegate.activeAccount) != nil {
            isNextcloudTextAvailable = true
        }
        
        actions.append(MenuAction(title: NSLocalizedString("_upload_photos_videos_", comment: ""), value: 10, icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "file_photo"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)))
        
        actions.append(MenuAction(title: NSLocalizedString("_upload_file_", comment: ""), value: 20, icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "file"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)))
        
        if NCBrandOptions.sharedInstance.use_imi_viewer {
            actions.append(MenuAction(title: NSLocalizedString("_im_create_new_file", tableName: "IMLocalizable", bundle: Bundle.main, value: "", comment: ""), value: 21, icon: CCGraphics.scale(UIImage.init(named: "imagemeter"), to: CGSize(width: 25, height: 25), isAspectRation: true)))
        }
        
        if isNextcloudTextAvailable {
            actions.append(MenuAction(title: NSLocalizedString("_create_nextcloudtext_document_", comment: ""), value: 31, icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "file_txt"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)))
        } else {
            actions.append(MenuAction(title: NSLocalizedString("_upload_file_text_", comment: ""), value: 30, icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "file_txt"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)))
        }
        
        #if !targetEnvironment(simulator)
                if #available(iOS 11.0, *) {
                    actions.append(MenuAction(title: NSLocalizedString("_scans_document_", comment: ""), value: 40, icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "scan"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)))
                }
        #endif
        
        actions.append(MenuAction(title: NSLocalizedString("_create_voice_memo_", comment: ""), value: 50, icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "microphone"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)))

        actions.append(MenuAction(title: NSLocalizedString("_create_folder_", comment: ""), value: 60, icon: CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), width: 50, height: 50, color: NCBrandColor.sharedInstance.brandElement)))
        
        if let richdocumentsMimetypes = NCManageDatabase.sharedInstance.getRichdocumentsMimetypes(account: appDelegate.activeAccount) {
            if richdocumentsMimetypes.count > 0 {
                actions.append(MenuAction(title: NSLocalizedString("_create_new_document_", comment: ""), value: 70, icon: UIImage.init(named: "create_file_document")!))
                actions.append(MenuAction(title: NSLocalizedString("_create_new_spreadsheet_", comment: ""), value: 80, icon: UIImage(named: "create_file_xls")!))
                actions.append(MenuAction(title: NSLocalizedString("_create_new_presentation_", comment: ""), value: 90, icon: UIImage(named: "create_file_ppt")!))
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let action = actions[indexPath.row]
        
        self.dismiss(animated: true, completion: nil)
        if action.value == 10 {
            self.appDelegate.activeMain.openAssetsPickerController()
        }
        if action.value == 20 { self.appDelegate.activeMain.openImportDocumentPicker() }
        if action.value == 21 {
            _ = IMCreate.init(serverUrl: self.appDelegate.activeMain.serverUrl)
        }
        if action.value == 30 {
            let storyboard = UIStoryboard(name: "NCText", bundle: nil)
            let controller = storyboard.instantiateViewController(withIdentifier: "NCText")
            controller.modalPresentationStyle = UIModalPresentationStyle.pageSheet
            self.appDelegate.activeMain.present(controller, animated: true, completion: nil)
        }
        if action.value == 31 {
            guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                return
            }
            navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet
            
            let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadDocuments
            viewController.typeTemplate = k_nextcloudtext_document
            viewController.serverUrl = self.appDelegate.activeMain.serverUrl
            viewController.titleForm = NSLocalizedString("_create_nextcloudtext_document_", comment: "")
            
            self.appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
        }
        if action.value == 40 {
            if #available(iOS 11.0, *) {
                NCCreateScanDocument.sharedInstance.openScannerDocument(viewController: self.appDelegate.activeMain)
            }
        }
        
        if action.value == 50 { NCMainCommon.sharedInstance.startAudioRecorder() }
        
        if action.value == 60 { self.appDelegate.activeMain.createFolder() }
        
        if action.value == 70 {
            guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                return
            }
            navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet
            
            let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadDocuments
            viewController.typeTemplate = k_richdocument_document
            viewController.serverUrl = self.appDelegate.activeMain.serverUrl
            viewController.titleForm = NSLocalizedString("_create_new_document_", comment: "")
            
            self.appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
        }
        if action.value == 80 {
            guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                return
            }
            navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet
            
            let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadDocuments
            viewController.typeTemplate = k_richdocument_spreadsheet
            viewController.serverUrl = self.appDelegate.activeMain.serverUrl
            viewController.titleForm = NSLocalizedString("_create_new_spreadsheet_", comment: "")
            
            self.appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
        }
        if action.value == 90 {
            guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                return
            }
            navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet
            
            let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadDocuments
            viewController.typeTemplate = k_richdocument_presentation
            viewController.serverUrl = self.appDelegate.activeMain.serverUrl
            viewController.titleForm = NSLocalizedString("_create_new_presentation_", comment: "")
            
            self.appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
        }
                
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return actions.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "menuActionCell", for: indexPath)
        
        let action = actions[indexPath.row]
        let actionIconView = cell.viewWithTag(1) as! UIImageView
        let actionNameLabel = cell.viewWithTag(2) as! UILabel
            
        actionIconView.image = action.icon
        actionNameLabel.text = action.title
            
        return cell
    }

}
extension MainMenuTableViewController: FloatingPanelControllerDelegate{
    
    func floatingPanel(_ vc: FloatingPanelController, layoutFor newCollection: UITraitCollection) -> FloatingPanelLayout? {
        return MainMenuFloatingPanelLayout(height: self.actions.count * 60)
    }
    
    func floatingPanel(_ vc: FloatingPanelController, behaviorFor newCollection: UITraitCollection) -> FloatingPanelBehavior? {
        return MainMenuFloatingPanelBehavior()
    }

}

class MainMenuFloatingPanelLayout: FloatingPanelLayout {
    
    let height: CGFloat
    
    init(height: Int){
        self.height = CGFloat(height)
    }
    
    var initialPosition: FloatingPanelPosition {
        return .tip
    }
    
    var supportedPositions: Set<FloatingPanelPosition> {
        return [.half]
    }
    
    func insetFor(position: FloatingPanelPosition) -> CGFloat? {
        switch position {
        case .half: return height
        case .tip: return height
        default: return nil
        }
    }
    

    func backdropAlphaFor(position: FloatingPanelPosition) -> CGFloat {
        return 0.5
    }
}

public class MainMenuFloatingPanelBehavior: FloatingPanelBehavior {

    public func addAnimator(_ fpc: FloatingPanelController, to: FloatingPanelPosition) -> UIViewPropertyAnimator {
        return UIViewPropertyAnimator(duration: 0.1, curve: .easeInOut)
    }

    public func removeAnimator(_ fpc: FloatingPanelController, from: FloatingPanelPosition) -> UIViewPropertyAnimator {
        return UIViewPropertyAnimator(duration: 0.1, curve: .easeInOut)
    }

    public func moveAnimator(_ fpc: FloatingPanelController, from: FloatingPanelPosition, to: FloatingPanelPosition) -> UIViewPropertyAnimator {
        return UIViewPropertyAnimator(duration: 0.1, curve: .easeInOut)
    }

}
