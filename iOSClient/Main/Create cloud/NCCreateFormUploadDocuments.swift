//
//  NCCreateFormUploadDocuments.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 14/11/18.
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
import NCCommunication

// MARK: -

@objc class NCCreateFormUploadDocuments: XLFormViewController, NCSelectDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, NCCreateFormUploadConflictDelegate {
    
    var editorId = ""
    var creatorId = ""
    var typeTemplate = ""
    var templateIdentifier = ""
    var serverUrl = ""
    var fileNameFolder = ""
    var fileName = ""
    var fileNameExtension = ""
    var titleForm = ""
    var listOfTemplate: [NCCommunicationEditorTemplates] = []
    var selectTemplate: NCCommunicationEditorTemplates?
    
    @IBOutlet weak var indicator: UIActivityIndicatorView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewHeigth: NSLayoutConstraint!
    
    // Layout
    let numItems = 2
    let sectionInsets: CGFloat = 10
    let highLabelName: CGFloat = 20
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if serverUrl == NCUtility.shared.getHomeServer(urlBase: appDelegate.urlBase, account: appDelegate.account) {
            fileNameFolder = "/"
        } else {
            fileNameFolder = (serverUrl as NSString).lastPathComponent
        }
        
        self.tableView.separatorStyle = UITableViewCell.SeparatorStyle.none
                
        let cancelButton : UIBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(cancel))
        let saveButton : UIBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_save_", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(save))
        
        self.navigationItem.leftBarButtonItem = cancelButton
        self.navigationItem.rightBarButtonItem = saveButton
        self.navigationItem.rightBarButtonItem?.isEnabled = false
        
        // title 
        self.title = titleForm
      
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)

        changeTheming()
        
        // load the templates available
        getTemplate()
    }
    
    @objc func changeTheming() {
        appDelegate.changeTheming(self, tableView: tableView, collectionView: collectionView, form: false)
        initializeForm()
    }
    
    // MARK: - Tableview (XLForm)

    func initializeForm() {
        
        let form : XLFormDescriptor = XLFormDescriptor() as XLFormDescriptor
        form.rowNavigationOptions = XLFormRowNavigationOptions.stopDisableRow
        
        var section : XLFormSectionDescriptor
        var row : XLFormRowDescriptor
        
        // Section: Destination Folder
        
        section = XLFormSectionDescriptor.formSection(withTitle: NSLocalizedString("_save_path_", comment: "").uppercased())
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "ButtonDestinationFolder", rowType: XLFormRowDescriptorTypeButton, title: fileNameFolder)
        row.action.formSelector = #selector(changeDestinationFolder(_:))
        row.value = fileNameFolder
        row.cellConfig["backgroundColor"] = NCBrandColor.sharedInstance.backgroundForm

        row.cellConfig["imageView.image"] = CCGraphics.changeThemingColorImage(UIImage(named: "folder")!, width: 50, height: 50, color: NCBrandColor.sharedInstance.brandElement) as UIImage
        
        row.cellConfig["textLabel.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textLabel.textColor"] = NCBrandColor.sharedInstance.textView

        section.addFormRow(row)
        
        // Section: File Name
        
        section = XLFormSectionDescriptor.formSection(withTitle: NSLocalizedString("_filename_", comment: "").uppercased())
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "fileName", rowType: XLFormRowDescriptorTypeAccount, title: NSLocalizedString("_filename_", comment: ""))
        row.value = fileName
        row.cellConfig["backgroundColor"] = NCBrandColor.sharedInstance.backgroundForm
        
        row.cellConfig["textField.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["textField.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textField.textColor"] = NCBrandColor.sharedInstance.textView
        
        row.cellConfig["textLabel.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textLabel.textColor"] = NCBrandColor.sharedInstance.textView
        
        section.addFormRow(row)
        
        self.form = form
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header: UITableViewHeaderFooterView = view as! UITableViewHeaderFooterView
        header.textLabel?.font = UIFont.systemFont(ofSize: 13.0)
        header.textLabel?.textColor = .gray
        header.tintColor = NCBrandColor.sharedInstance.backgroundForm
    }

    // MARK: - CollectionView
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return listOfTemplate.count
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {

        let itemWidth: CGFloat = (collectionView.frame.width - (sectionInsets * 4) - CGFloat(numItems)) / CGFloat(numItems)
        let itemHeight: CGFloat = itemWidth + highLabelName
        
        collectionViewHeigth.constant = itemHeight + sectionInsets
        
        return CGSize(width: itemWidth, height: itemHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        
        let template = listOfTemplate[indexPath.row]
        
        // image
        let imagePreview = cell.viewWithTag(100) as! UIImageView
        if template.preview != "" {
            let fileNameLocalPath = CCUtility.getDirectoryUserData() + "/" + template.name + ".png"
            if FileManager.default.fileExists(atPath: fileNameLocalPath) {
                let imageURL = URL(fileURLWithPath: fileNameLocalPath)
                if let image = UIImage(contentsOfFile: imageURL.path) {
                    imagePreview.image = image
                }
            } else {
                getImageFromTemplate(name: template.name, preview: template.preview, indexPath: indexPath)
            }
        }
        
        // name
        let name = cell.viewWithTag(200) as! UILabel
        name.text = template.name
        name.textColor = NCBrandColor.sharedInstance.backgroundView
        
        // select
        let imageSelect = cell.viewWithTag(300) as! UIImageView
        if selectTemplate != nil && selectTemplate?.name == template.name {
            cell.backgroundColor = NCBrandColor.sharedInstance.textView
            imageSelect.image = UIImage(named: "plus100")
            imageSelect.isHidden = false
        } else {
            cell.backgroundColor = NCBrandColor.sharedInstance.backgroundView
            imageSelect.isHidden = true
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let template = listOfTemplate[indexPath.row]
        
        selectTemplate = template
        fileNameExtension = template.ext
        
        collectionView.reloadData()
    }
    
    // MARK: - Action
    
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, array: [Any], buttonType: String, overwrite: Bool) {
        
        guard let serverUrl = serverUrl else {
            return
        }
        
        self.serverUrl = serverUrl
        if serverUrl == NCUtility.shared.getHomeServer(urlBase: appDelegate.urlBase, account: appDelegate.account) {
            fileNameFolder = "/"
        } else {
            fileNameFolder = (serverUrl as NSString).lastPathComponent
        }
        
        let buttonDestinationFolder : XLFormRowDescriptor  = self.form.formRow(withTag: "ButtonDestinationFolder")!
        buttonDestinationFolder.title = fileNameFolder
        
        self.tableView.reloadData()
    }
    
    @objc func changeDestinationFolder(_ sender: XLFormRowDescriptor) {
        
        self.deselectFormRow(sender)
        
        let storyboard = UIStoryboard(name: "NCSelect", bundle: nil)
        let navigationController = storyboard.instantiateInitialViewController() as! UINavigationController
        let viewController = navigationController.topViewController as! NCSelect
        
        viewController.delegate = self
        viewController.hideButtonCreateFolder = false
        viewController.includeDirectoryE2EEncryption = false
        viewController.includeImages = false
        viewController.keyLayout = k_layout_view_move
        viewController.selectFile = false
        viewController.titleButtonDone = NSLocalizedString("_select_", comment: "")
        viewController.type = ""

        navigationController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        self.present(navigationController, animated: true, completion: nil)
    }
    
    @objc func save() {
        
        guard let selectTemplate = self.selectTemplate else {
            return
        }
        templateIdentifier = selectTemplate.identifier

        let rowFileName : XLFormRowDescriptor  = self.form.formRow(withTag: "fileName")!
        guard var fileNameForm = rowFileName.value else {
            return
        }
        
        if fileNameForm as! String == "" {
            return
        } else {
            
            let result = NCCommunicationCommon.shared.getInternalContenType(fileName: fileNameForm as! String, contentType: "", directory: false)
            if NCUtility.shared.isDirectEditing(account: appDelegate.account, contentType: result.contentType) == nil {
                fileNameForm = (fileNameForm as! NSString).deletingPathExtension + "." + fileNameExtension
            }
            
            if NCUtility.shared.getMetadataConflict(account: appDelegate.account, serverUrl: serverUrl, fileName: String(describing: fileNameForm)) != nil {
                
                let metadataForUpload = NCManageDatabase.sharedInstance.createMetadata(account: appDelegate.account, fileName: String(describing: fileNameForm), ocId: "", serverUrl: serverUrl, urlBase: appDelegate.urlBase, url: "", contentType: "", livePhoto: false)
                
                guard let conflictViewController = UIStoryboard(name: "NCCreateFormUploadConflict", bundle: nil).instantiateInitialViewController() as? NCCreateFormUploadConflict else { return }
                conflictViewController.textLabelDetailNewFile = NSLocalizedString("_now_", comment: "")
                conflictViewController.alwaysNewFileNameNumber = true
                conflictViewController.serverUrl = serverUrl
                conflictViewController.metadatasUploadInConflict = [metadataForUpload]
                conflictViewController.delegate = self
                
                self.present(conflictViewController, animated: true, completion: nil)
                
            } else {
                                
                let fileNamePath = CCUtility.returnFileNamePath(fromFileName: String(describing: fileNameForm), serverUrl: serverUrl, urlBase: appDelegate.urlBase, account: appDelegate.account)!
                createDocument(fileNamePath: fileNamePath, fileName: String(describing: fileNameForm))
            }
        }
    }
    
    func dismissCreateFormUploadConflict(metadatas: [tableMetadata]?) {
        
        if metadatas == nil || metadatas?.count == 0 {
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.cancel()
            }
            
        } else {
            
            let fileName = metadatas![0].fileName
            let fileNamePath = CCUtility.returnFileNamePath(fromFileName: fileName, serverUrl: serverUrl, urlBase: appDelegate.urlBase, account: appDelegate.account)!
            
            createDocument(fileNamePath: fileNamePath, fileName: fileName)
        }
    }
    
    func createDocument(fileNamePath: String, fileName: String) {
        
        if self.editorId == k_editor_text || self.editorId == k_editor_onlyoffice {
             
            var customUserAgent: String?
            
            if self.editorId == k_editor_onlyoffice {
                customUserAgent = NCUtility.shared.getCustomUserAgentOnlyOffice()
            }
            
            NCCommunication.shared.NCTextCreateFile(fileNamePath: fileNamePath, editorId: editorId, creatorId: creatorId, templateId: templateIdentifier, customUserAgent: customUserAgent) { (account, url, errorCode, errorMessage) in
                
                if errorCode == 0 && account == self.appDelegate.account {
                    
                    if url != nil && url!.count > 0 {
                        let result = NCCommunicationCommon.shared.getInternalContenType(fileName: fileName, contentType: "", directory: false)
                        
                        self.dismiss(animated: true, completion: {
                            let metadata = NCManageDatabase.sharedInstance.createMetadata(account: self.appDelegate.account, fileName: fileName, ocId: CCUtility.createRandomString(12), serverUrl: self.serverUrl, urlBase: self.appDelegate.urlBase, url: url ?? "", contentType: result.contentType, livePhoto: false)
                            
                            if self.appDelegate.activeViewController is CCMain {
                                (self.appDelegate.activeViewController as! CCMain).shouldPerformSegue(metadata, selector: "")
                            } else if self.appDelegate.activeViewController is NCFavorite {
                                (self.appDelegate.activeViewController as! NCFavorite).segue(metadata: metadata)
                            } else if self.appDelegate.activeViewController is NCOffline {
                                (self.appDelegate.activeViewController as! NCOffline).segue(metadata: metadata)
                            }
                        })
                    }
                    
                } else if errorCode != 0 {
                    NCContentPresenter.shared.messageNotification("_error_", description: errorMessage, delay: TimeInterval(k_dismissAfterSecond), type:NCContentPresenter.messageType.error, errorCode: errorCode)
                } else {
                   print("[LOG] It has been changed user during networking process, error.")
                }
            }
        }
        
        if self.editorId == k_editor_collabora {
            
            NCCommunication.shared.createRichdocuments(path: fileNamePath, templateId: templateIdentifier) { (account, url, errorCode, errorDescription) in
                
                if errorCode == 0 && account == self.appDelegate.account && url != nil {
                   
                    self.dismiss(animated: true, completion: {
                    
                        let metadata = NCManageDatabase.sharedInstance.createMetadata(account: self.appDelegate.account, fileName: (fileName as NSString).deletingPathExtension + "." + self.fileNameExtension, ocId: CCUtility.createRandomString(12), serverUrl: self.serverUrl, urlBase: self.appDelegate.urlBase, url: url!, contentType: "", livePhoto: false)
                    
                        if self.appDelegate.activeViewController is CCMain {
                            (self.appDelegate.activeViewController as! CCMain).shouldPerformSegue(metadata, selector: "")
                        } else if self.appDelegate.activeViewController is NCFavorite {
                            (self.appDelegate.activeViewController as! NCFavorite).segue(metadata: metadata)
                        } else if self.appDelegate.activeViewController is NCOffline {
                            (self.appDelegate.activeViewController as! NCOffline).segue(metadata: metadata)
                        }
                   })
                   
                    
                } else if errorCode != 0 {
                    NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                } else {
                    print("[LOG] It has been changed user during networking process, error.")
                }
            }
        }
    }
    
    @objc func cancel() {
        
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: NC API
    
    func getTemplate() {
     
        indicator.color = NCBrandColor.sharedInstance.brandElement
        indicator.startAnimating()
        
        if self.editorId == k_editor_text || self.editorId == k_editor_onlyoffice {
            
            fileNameExtension = "md"            
            var customUserAgent: String?
                       
            if self.editorId == k_editor_onlyoffice {
                customUserAgent = NCUtility.shared.getCustomUserAgentOnlyOffice()
            }
            
            NCCommunication.shared.NCTextGetListOfTemplates(customUserAgent: customUserAgent) { (account, templates, errorCode, errorMessage) in
                
                self.indicator.stopAnimating()
                
                if errorCode == 0 && account == self.appDelegate.account {
                    
                    for template in templates {
                        
                        let temp = NCCommunicationEditorTemplates()
                                               
                        temp.identifier = template.identifier
                        temp.ext = template.ext
                        temp.name = template.name
                        temp.preview = template.preview
                                               
                        self.listOfTemplate.append(temp)
                                               
                        // default: template empty
                        if temp.preview == "" {
                            self.selectTemplate = temp
                            self.fileNameExtension = template.ext
                            self.navigationItem.rightBarButtonItem?.isEnabled = true
                        }
                    }
                    
                    // NOT ALIGNED getTemplatesRichdocuments
                    if templates.count == 0 {
                        let temp = NCCommunicationEditorTemplates()
                        
                        temp.identifier = ""
                        if self.editorId == k_editor_text {
                            temp.ext = "md"
                        } else if self.editorId == k_editor_onlyoffice && self.typeTemplate == k_template_document {
                            temp.ext = "docx"
                        } else if self.editorId == k_editor_onlyoffice && self.typeTemplate == k_template_spreadsheet {
                            temp.ext = "xlsx"
                        } else if self.editorId == k_editor_onlyoffice && self.typeTemplate == k_template_presentation {
                            temp.ext = "pptx"
                        }
                        temp.name = "Empty"
                        temp.preview = ""
                                                                      
                        self.listOfTemplate.append(temp)
                        
                        self.selectTemplate = temp
                        self.fileNameExtension = temp.ext
                        self.navigationItem.rightBarButtonItem?.isEnabled = true
                    }
                    
                    self.collectionView.reloadData()
                                        
                } else if errorCode != 0 {
                    NCContentPresenter.shared.messageNotification("_error_", description: errorMessage, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                } else {
                    print("[LOG] It has been changed user during networking process, error.")
                }
            }
            
        }
        
        if self.editorId == k_editor_collabora  {
                        
            NCCommunication.shared.getTemplatesRichdocuments(typeTemplate: typeTemplate) { (account, templates, errorCode, errorDescription) in
                
                self.indicator.stopAnimating()

                if errorCode == 0 && account == self.appDelegate.account {
                    
                    for template in templates! {
                        
                        let temp = NCCommunicationEditorTemplates()
                        temp.identifier = "\(template.templateId)"
                        temp.delete = template.delete
                        temp.ext = template.ext
                        temp.name = template.name
                        temp.preview = template.preview
                        temp.type = template.type
                        
                        self.listOfTemplate.append(temp)
                        
                        // default: template empty
                        if temp.preview == "" {
                            self.selectTemplate = temp
                            self.fileNameExtension = temp.ext
                            self.navigationItem.rightBarButtonItem?.isEnabled = true
                        }
                    }
                    
                    self.collectionView.reloadData()
                    
                } else if errorCode != 0 {
                    NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                } else {
                    print("[LOG] It has been changed user during networking process, error.")
                }
            }
        }
    }
    
    func getImageFromTemplate(name: String, preview: String, indexPath: IndexPath) {
        
        let fileNameLocalPath = CCUtility.getDirectoryUserData() + "/" + name + ".png"

        NCCommunication.shared.download(serverUrlFileName: preview, fileNameLocalPath: fileNameLocalPath, requestHandler: { (_) in
            
        }, progressHandler: { (_) in
            
        }) { (account, etag, date, lenght, error, errorCode, errorDescription) in
            
            if errorCode == 0 && account == self.appDelegate.account {
                self.collectionView.reloadItems(at: [indexPath])
            } else if errorCode != 0 {
                print("\(errorCode)")
            } else {
                print("[LOG] It has been changed user during networking process, error.")
            }
        }
    }
}
