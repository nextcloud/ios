//
//  NCViewerRichWorkspace.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 14/01/2020.
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

import Foundation
import NCCommunication

@objc class NCViewerRichWorkspace: UIViewController, UIAdaptivePresentationControllerDelegate {

    @IBOutlet weak var viewRichWorkspace: NCViewRichWorkspace!
    @IBOutlet weak var editItem: UIBarButtonItem!
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    @objc public var richWorkspace: String = ""
    @objc public var serverUrl: String = ""
    @objc public var titleCloseItem: String = ""
   
    override func viewDidLoad() {
        super.viewDidLoad()
        
        presentationController?.delegate = self
        let closeItem = UIBarButtonItem(title: titleCloseItem, style: .plain, target: self, action: #selector(closeItemTapped(_:)))
        self.navigationItem.leftBarButtonItem = closeItem
        editItem.image = UIImage(named: "actionSheetModify")

        viewRichWorkspace.setRichWorkspaceText(richWorkspace, gradient: false)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeTheming), name: NSNotification.Name(rawValue: "changeTheming"), object: nil)
        changeTheming()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NCCommunication.sharedInstance.readFileOrFolder(serverUrlFileName: serverUrl, depth: "0", account: appDelegate.activeAccount) { (account, files, errorCode, errorMessage) in
            
            if errorCode == 0 && account == self.appDelegate.activeAccount {
                
                var metadataFolder = tableMetadata()
                _ = NCNetworking.sharedInstance.convertFiles(files!, urlString: self.appDelegate.activeUrl, serverUrl: self.serverUrl, user: self.appDelegate.activeUser, metadataFolder: &metadataFolder)
                NCManageDatabase.sharedInstance.setDirectory(ocId: metadataFolder.ocId, serverUrl: metadataFolder.serverUrl, richWorkspace: metadataFolder.richWorkspace, account: account)
                self.richWorkspace = metadataFolder.richWorkspace
                self.viewRichWorkspace.setRichWorkspaceText(self.richWorkspace, gradient: false)
            }
        }
    }
    
    public func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        self.viewWillAppear(true)
    }
    
    @objc func changeTheming() {
        appDelegate.changeTheming(self, tableView: nil, collectionView: nil, form: false)
    }
    
    @objc func closeItemTapped(_ sender: UIBarButtonItem) {
        self.dismiss(animated: false, completion: nil)
    }
    
    @IBAction func editItemAction(_ sender: Any) {
        
        if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView LIKE[c] %@", appDelegate.activeAccount, serverUrl, k_fileNameRichWorkspace.lowercased())) {
            
            if metadata.url == "" {
                NCUtility.sharedInstance.startActivityIndicator(view: self.view, bottom: 0)
                let fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, activeUrl: appDelegate.activeUrl)!
                NCCommunication.sharedInstance.NCTextOpenFile(urlString: appDelegate.activeUrl, fileNamePath: fileNamePath, editor: "text", account: appDelegate.activeAccount) { (account, url, errorCode, errorMessage) in
                    
                    NCUtility.sharedInstance.stopActivityIndicator()
                    
                    if errorCode == 0 && account == self.appDelegate.activeAccount {
                        
                        if let viewerNextcloudText = UIStoryboard.init(name: "NCViewerRichWorkspace", bundle: nil).instantiateViewController(withIdentifier: "NCViewerNextcloudText") as? NCViewerNextcloudText {
                            
                            viewerNextcloudText.url = url!
                            viewerNextcloudText.metadata = metadata
                            viewerNextcloudText.presentationController?.delegate = self
                            
                            self.present(viewerNextcloudText, animated: true, completion: nil)
                        }
                        
                    } else if errorCode != 0 {
                        NCContentPresenter.shared.messageNotification("_error_", description: errorMessage, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.info, errorCode: errorCode)
                    }
                }
                
            } else {
                
                if let viewerNextcloudText = UIStoryboard.init(name: "NCViewerRichWorkspace", bundle: nil).instantiateViewController(withIdentifier: "NCViewerNextcloudText") as? NCViewerNextcloudText {
                    
                    viewerNextcloudText.url = metadata.url
                    viewerNextcloudText.metadata = metadata
                    viewerNextcloudText.presentationController?.delegate = self
                    
                    self.present(viewerNextcloudText, animated: true, completion: nil)
                }
            }
        }
    }
}
