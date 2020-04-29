//
//  NCText.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 24/07/17.
//  Copyright (c) 2017 Marino Faggiana. All rights reserved.
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
import WebKit

@objc protocol NCTextDelegate {
    func dismissTextView()
}

class NCText: UIViewController, UITextViewDelegate {

    @IBOutlet weak var cancelButton: UIBarButtonItem!
    @IBOutlet weak var nextButton: UIBarButtonItem!
    @IBOutlet weak var textView: UITextView!
    
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    @objc var metadata: tableMetadata?
    @objc var delegate: NCTextDelegate?
    var loadText: String?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector:#selector(keyboardWillShowHandle(info:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector:#selector(keyboardWillHideHandle), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        self.navigationController?.navigationBar.topItem?.title = NSLocalizedString("_untitled_txt_", comment: "")
                
        cancelButton.title = NSLocalizedString("_cancel_", comment: "")
        nextButton.title = NSLocalizedString("_next_", comment: "")
        
        // Modify
        if let metadata = metadata {
            
            loadText = ""
            let path = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
            let data = NSData(contentsOfFile: path)
            
            if let data = data {
            
                let encodingCFName = NCUchardet.sharedNUCharDet().encodingCFStringDetect(with: data as Data)
                let se = CFStringConvertEncodingToNSStringEncoding(encodingCFName)
                let encoding = String.Encoding(rawValue: se)
                
                loadText = try? String(contentsOfFile: path, encoding: encoding)
                textView.text = loadText
                nextButton.title = NSLocalizedString("_save_", comment: "")
                self.navigationController?.navigationBar.topItem?.title = NSLocalizedString(metadata.fileNameView, comment: "")
            }
                
        } else {
            
            loadText = ""
        }
        
        textView.isUserInteractionEnabled = true
        textView.becomeFirstResponder()
        textView.delegate = self
        textView.selectedTextRange = textView.textRange(from: textView.beginningOfDocument, to: textView.beginningOfDocument)
        textView.font = UIFont(name: "NameOfTheFont", size: 20)

        // Theming view
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)
        changeTheming()
        
        textViewDidChange(textView)
    }

    @objc func keyboardWillShowHandle(info:NSNotification) {
        
        let frameView = self.view.convert(self.view.bounds, to: self.view.window)
        let endView = frameView.origin.y + frameView.size.height
        
        if let keyboardSize = (info.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue, let _ = self.view.window?.frame {
            
            if endView - keyboardSize.origin.y > 0 {
                bottomConstraint.constant = endView - keyboardSize.origin.y
            } else {
                bottomConstraint.constant = 0
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if appDelegate.activeDetail != nil && appDelegate.activeDetail.backgroundView?.subviews.first != nil {
            if appDelegate.activeDetail.backgroundView.subviews.first is WKWebView {
                appDelegate.activeDetail.viewUnload()
            }
        }
    }
    
    @objc func keyboardWillHideHandle() {
        bottomConstraint.constant = 0
    }
    
    func textViewDidChange(_ textView: UITextView) {
        
        if textView.text.count == 0 {
            nextButton.isEnabled = false
        } else {
            nextButton.isEnabled = true
        }
    }
    
    @objc func changeTheming() {
    
        appDelegate.changeTheming(self, tableView: nil, collectionView: nil, form: false)
        
        textView.backgroundColor = NCBrandColor.sharedInstance.backgroundForm
        textView.textColor = NCBrandColor.sharedInstance.textView
    }
    
    @IBAction func cancelButtonTapped(_ sender: AnyObject) {
        
        if textView.text != loadText {
            
            let alertController = UIAlertController(title: NSLocalizedString("_info_", comment: ""), message: NSLocalizedString("_save_exit_", comment: ""), preferredStyle: .alert)
            
            let actionYes = UIAlertAction(title: NSLocalizedString("_yes_", comment: ""), style: .default) { (action:UIAlertAction) in
                self.dismiss(animated: true, completion: {
                    self.delegate?.dismissTextView()
                })
            }
            
            let actionNo = UIAlertAction(title: NSLocalizedString("_no_", comment: ""), style: .cancel) { (action:UIAlertAction) in
                print("You've pressed No button")
            }
            
            alertController.addAction(actionYes)
            alertController.addAction(actionNo)
            
            self.present(alertController, animated: true, completion:nil)
            
        } else {
            
            self.dismiss(animated: true, completion: {
                self.delegate?.dismissTextView()
            })
        }
    }
    
    @IBAction func nextButtonTapped(_ sender: AnyObject) {
        
        let serverUrl = self.appDelegate.getTabBarControllerActiveServerUrl()
        
        if let metadata = metadata {
            
            if textView.text != loadText {
            
                let data = textView.text.data(using: .utf8)
                let success = FileManager.default.createFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView), contents: data, attributes: nil)
                if success {
                
                    appDelegate.activeMain.clearDateReadDataSource(nil)
                
                    self.dismiss(animated: true, completion: {
                        
                        metadata.session = k_upload_session
                        metadata.sessionSelector = selectorUploadFile
                        metadata.status = Int(k_metadataStatusWaitUpload)

                        NCManageDatabase.sharedInstance.addMetadata(metadata)
                        NCMainCommon.sharedInstance.reloadDatasource(ServerUrl: serverUrl, ocId: metadata.ocId, action: Int32(k_action_MOD))
                        
                        self.appDelegate.startLoadAutoDownloadUpload()

                        self.delegate?.dismissTextView()
                    })

                } else {
                    NCContentPresenter.shared.messageNotification("_error_", description: "_error_creation_file_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError))
                }
                
            } else {
                self.dismiss(animated: true, completion: {
                    self.delegate?.dismissTextView()
                })
            }
            
        } else {
            
            let formViewController = NCCreateFormUploadFileText.init(serverUrl: serverUrl!, text: self.textView.text, fileName: NSLocalizedString("_untitled_txt_", comment: ""))
            self.navigationController?.pushViewController(formViewController, animated: true)
        }
    }
}
