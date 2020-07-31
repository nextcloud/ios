//
//  NCCapabilitiesViewController.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 28/07/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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

import UIKit
import NCCommunication

class NCCapabilitiesViewController: UIViewController, UIDocumentInteractionControllerDelegate {

    @IBOutlet weak var textView: UITextView!
    
    @IBOutlet weak var imageFileSharing: UIImageView!
    @IBOutlet weak var statusFileSharing: UILabel!
    
    @IBOutlet weak var imageExternalSite: UIImageView!
    @IBOutlet weak var statusExternalSite: UILabel!
    
    @IBOutlet weak var imageEndToEndEncryption: UIImageView!
    @IBOutlet weak var statusEndToEndEncryption: UILabel!
    
    @IBOutlet weak var imagePaginatedFileListing: UIImageView!
    @IBOutlet weak var statusPaginatedFileListing: UILabel!
    
    @IBOutlet weak var imageActivity: UIImageView!
    @IBOutlet weak var statusActivity: UILabel!
   
    @IBOutlet weak var imageNotification: UIImageView!
    @IBOutlet weak var statusNotification: UILabel!
    
    @IBOutlet weak var imageDeletedFiles: UIImageView!
    @IBOutlet weak var statusDeletedFiles: UILabel!
    
    @IBOutlet weak var imageText: UIImageView!
    @IBOutlet weak var statusText: UILabel!
    
    @IBOutlet weak var imageCollabora: UIImageView!
    @IBOutlet weak var statusCollabora: UILabel!
    
    @IBOutlet weak var imageOnlyOffice: UIImageView!
    @IBOutlet weak var statusOnlyOffice: UILabel!
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var documentController: UIDocumentInteractionController?
    private var account: String = ""
    private var capabilitiesText = ""
    private var timer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("_capabilities_", comment: "")
               
        let shareImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "shareFill"), width: 50, height: 50, color: .gray)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: shareImage, style: UIBarButtonItem.Style.plain, target: self, action: #selector(share))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_done_", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(close))

        textView.layer.cornerRadius = 15
        textView.backgroundColor = NCBrandColor.sharedInstance.graySoft
        
        statusFileSharing.layer.cornerRadius = 12.5
        statusFileSharing.layer.borderWidth = 0.5
        statusFileSharing.layer.borderColor = UIColor.black.cgColor
        statusFileSharing.layer.backgroundColor = NCBrandColor.sharedInstance.graySoft.withAlphaComponent(0.3).cgColor
        
        statusExternalSite.layer.cornerRadius = 10
        statusExternalSite.layer.borderWidth = 0.5
        statusExternalSite.layer.borderColor = UIColor.black.cgColor
        statusExternalSite.layer.backgroundColor = NCBrandColor.sharedInstance.graySoft.withAlphaComponent(0.3).cgColor
        
        statusEndToEndEncryption.layer.cornerRadius = 10
        statusEndToEndEncryption.layer.borderWidth = 0.5
        statusEndToEndEncryption.layer.borderColor = UIColor.black.cgColor
        statusEndToEndEncryption.layer.backgroundColor = NCBrandColor.sharedInstance.graySoft.withAlphaComponent(0.3).cgColor
        
        statusPaginatedFileListing.layer.cornerRadius = 10
        statusPaginatedFileListing.layer.borderWidth = 0.5
        statusPaginatedFileListing.layer.borderColor = UIColor.black.cgColor
        statusPaginatedFileListing.layer.backgroundColor = NCBrandColor.sharedInstance.graySoft.withAlphaComponent(0.3).cgColor
        
        statusActivity.layer.cornerRadius = 10
        statusActivity.layer.borderWidth = 0.5
        statusActivity.layer.borderColor = UIColor.black.cgColor
        statusActivity.layer.backgroundColor = NCBrandColor.sharedInstance.graySoft.withAlphaComponent(0.3).cgColor
        
        statusNotification.layer.cornerRadius = 10
        statusNotification.layer.borderWidth = 0.5
        statusNotification.layer.borderColor = UIColor.black.cgColor
        statusNotification.layer.backgroundColor = NCBrandColor.sharedInstance.graySoft.withAlphaComponent(0.3).cgColor
        
        statusDeletedFiles.layer.cornerRadius = 10
        statusDeletedFiles.layer.borderWidth = 0.5
        statusDeletedFiles.layer.borderColor = UIColor.black.cgColor
        statusDeletedFiles.layer.backgroundColor = NCBrandColor.sharedInstance.graySoft.withAlphaComponent(0.3).cgColor
        
        statusText.layer.cornerRadius = 10
        statusText.layer.borderWidth = 0.5
        statusText.layer.borderColor = UIColor.black.cgColor
        statusText.layer.backgroundColor = NCBrandColor.sharedInstance.graySoft.withAlphaComponent(0.3).cgColor

        statusCollabora.layer.cornerRadius = 10
        statusCollabora.layer.borderWidth = 0.5
        statusCollabora.layer.borderColor = UIColor.black.cgColor
        statusCollabora.layer.backgroundColor = NCBrandColor.sharedInstance.graySoft.withAlphaComponent(0.3).cgColor
 
        statusOnlyOffice.layer.cornerRadius = 10
        statusOnlyOffice.layer.borderWidth = 0.5
        statusOnlyOffice.layer.borderColor = UIColor.black.cgColor
        statusOnlyOffice.layer.backgroundColor = NCBrandColor.sharedInstance.graySoft.withAlphaComponent(0.3).cgColor
        
        imageFileSharing.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "share"), width: 100, height: 100, color: .gray)
        imageExternalSite.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "externalsites"), width: 100, height: 100, color: .gray)
        imageEndToEndEncryption.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "lock"), width: 100, height: 100, color: .gray)        
        imagePaginatedFileListing.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "application"), width: 100, height: 100, color: .gray)
        imageActivity.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "activity"), width: 100, height: 100, color: .gray)
        imageNotification.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "notification"), width: 100, height: 100, color: .gray)
        imageDeletedFiles.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "delete"), width: 100, height: 100, color: .gray)
        imageText.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "text"), width: 100, height: 100, color: .gray)
        imageCollabora.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "collabora"), width: 100, height: 100, color: .gray)
        imageOnlyOffice.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "onlyoffice"), width: 100, height: 100, color: .gray)

        guard let account = NCManageDatabase.sharedInstance.getAccountActive() else { return }
        self.account = account.account
        
        if let text = NCManageDatabase.sharedInstance.getCapabilities(account: account.account) {
            capabilitiesText = text
            updateCapabilities()
        } else {
            NCContentPresenter.shared.messageNotification("_error_", description: "_no_capabilities_found_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.info, errorCode: Int(k_CCErrorInternalError), forced: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }

    @objc func updateCapabilities() {
        
        NCCommunication.shared.getCapabilities() { (account, data, errorCode, errorDescription) in
            if errorCode == 0 && data != nil {
                NCManageDatabase.sharedInstance.addCapabilitiesJSon(data!, account: account)
                
                // EDITORS
                let serverVersionMajor = NCManageDatabase.sharedInstance.getCapabilitiesServerInt(account: account, elements: NCElementsJSON.shared.capabilitiesVersionMajor)
                if serverVersionMajor >= k_nextcloud_version_18_0 {
                    NCCommunication.shared.NCTextObtainEditorDetails() { (account, editors, creators, errorCode, errorMessage) in
                        if errorCode == 0 && account == self.appDelegate.activeAccount {
                            NCManageDatabase.sharedInstance.addDirectEditing(account: account, editors: editors, creators: creators)
                            self.readCapabilities()
                        }
                        if self.view.window != nil {
                            self.timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.updateCapabilities), userInfo: nil, repeats: false)
                        }
                    }
                } else {
                    if self.view.window != nil {
                        self.timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.updateCapabilities), userInfo: nil, repeats: false)
                    }
                }
                
                if let text = NCManageDatabase.sharedInstance.getCapabilities(account: account) {
                    self.capabilitiesText = text
                }
                self.readCapabilities()
            }
        }
        
        readCapabilities()
    }
    
    @objc func share() {
        timer?.invalidate()
        self.dismiss(animated: true) {
            let fileURL = NSURL.fileURL(withPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("capabilities.txt")
            NCMainCommon.sharedInstance.openIn(fileURL: fileURL, selector: nil)
        }
    }
    
    @objc func close() {
        timer?.invalidate()
        self.dismiss(animated: true, completion: nil)
    }
    
    func readCapabilities() {
        
        textView.text = capabilitiesText
        
        if NCManageDatabase.sharedInstance.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesFileSharingApiEnabled, exists: false) {
            statusFileSharing.text = "✓ " + NSLocalizedString("_available_", comment: "")
        } else {
            statusFileSharing.text = NSLocalizedString("_not_available_", comment: "")
        }
        
        if NCManageDatabase.sharedInstance.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesExternalSitesExists, exists: false) {
            statusExternalSite.text = "✓ " + NSLocalizedString("_available_", comment: "")
        } else {
            statusExternalSite.text = NSLocalizedString("_not_available_", comment: "")
        }
        
        let isE2EEEnabled = NCManageDatabase.sharedInstance.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesE2EEEnabled, exists: false)
        let versionE2EE = NCManageDatabase.sharedInstance.getCapabilitiesServerString(account: account, elements: NCElementsJSON.shared.capabilitiesE2EEApiVersion)
        
        if isE2EEEnabled && versionE2EE == k_E2EE_API {
            statusEndToEndEncryption.text = "✓ " + NSLocalizedString("_available_", comment: "")
        } else {
            statusEndToEndEncryption.text = NSLocalizedString("_not_available_", comment: "")
        }
        
        let paginationEndpoint = NCManageDatabase.sharedInstance.getCapabilitiesServerString(account: account, elements: NCElementsJSON.shared.capabilitiesPaginationEndpoint)
        if paginationEndpoint != nil {
            statusPaginatedFileListing.text = "✓ " + NSLocalizedString("_available_", comment: "")
        } else {
            statusPaginatedFileListing.text = NSLocalizedString("_not_available_", comment: "")
        }
        
        let activity = NCManageDatabase.sharedInstance.getCapabilitiesServerArray(account: account, elements: NCElementsJSON.shared.capabilitiesActivity)
        if activity != nil {
            statusActivity.text = "✓ " + NSLocalizedString("_available_", comment: "")
        } else {
            statusActivity.text = NSLocalizedString("_not_available_", comment: "")
        }
        
        let notification = NCManageDatabase.sharedInstance.getCapabilitiesServerArray(account: account, elements: NCElementsJSON.shared.capabilitiesNotification)
        if notification != nil {
            statusNotification.text = "✓ " + NSLocalizedString("_available_", comment: "")
        } else {
            statusNotification.text = NSLocalizedString("_not_available_", comment: "")
        }
        
        let deleteFiles = NCManageDatabase.sharedInstance.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesFilesUndelete, exists: false)
        if deleteFiles {
            statusDeletedFiles.text = "✓ " + NSLocalizedString("_available_", comment: "")
        } else {
            statusDeletedFiles.text = NSLocalizedString("_not_available_", comment: "")
        }
        
        var textEditor = false
        var onlyofficeEditors = false
        if let editors = NCManageDatabase.sharedInstance.getDirectEditingEditors(account: account) {
            for editor in editors {
                if editor.editor == k_editor_text {
                    textEditor = true
                } else if editor.editor == k_editor_onlyoffice {
                    onlyofficeEditors = true
                }
            }
        }
        
        if textEditor {
            statusText.text = "✓ " + NSLocalizedString("_available_", comment: "")
        } else {
            statusText.text = NSLocalizedString("_not_available_", comment: "")
        }
        
        let richdocumentsMimetypes = NCManageDatabase.sharedInstance.getCapabilitiesServerArray(account: account, elements: NCElementsJSON.shared.capabilitiesRichdocumentsMimetypes)
        if richdocumentsMimetypes != nil {
            statusCollabora.text = "✓ " + NSLocalizedString("_available_", comment: "")
        } else {
            statusCollabora.text = NSLocalizedString("_not_available_", comment: "")
        }
        
        if onlyofficeEditors {
            statusOnlyOffice.text = "✓ " + NSLocalizedString("_available_", comment: "")
        } else {
            statusOnlyOffice.text = NSLocalizedString("_not_available_", comment: "")
        }
        
        print("end.")
    }
}
