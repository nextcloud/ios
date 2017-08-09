//
//  NCText.swift
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 24/07/17.
//  Copyright (c) 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
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

class NCText: UIViewController, UITextViewDelegate {

    @IBOutlet weak var cancelButton: UIBarButtonItem!
    @IBOutlet weak var nextButton: UIBarButtonItem!
    @IBOutlet weak var textView: UITextView!
    
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    var metadata: tableMetadata?
    var loadText: String?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShowHandle(info:)), name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector:#selector(self.keyboardWillHideHandle), name: .UIKeyboardWillHide, object: nil)

        self.navigationController?.navigationBar.topItem?.title = NSLocalizedString("_untitled_txt_", comment: "")
        self.navigationController?.navigationBar.barTintColor = NCBrandColor.sharedInstance.brand
        self.navigationController?.navigationBar.tintColor = NCBrandColor.sharedInstance.navigationBarText
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: NCBrandColor.sharedInstance.navigationBarText]
        
        self.navigationController?.toolbar.barTintColor = NCBrandColor.sharedInstance.navigationBarText
        self.navigationController?.toolbar.tintColor = NCBrandColor.sharedInstance.brand
        
        cancelButton.title = NSLocalizedString("_cancel_", comment: "")
        nextButton.title = NSLocalizedString("_next_", comment: "")
        
        // Modify
        if let metadata = metadata {
            
            let path = "\(appDelegate.directoryUser!)/\(metadata.fileID)"
            
            loadText = try? String(contentsOfFile: path, encoding: String.Encoding.utf8)
            textView.text = loadText
            nextButton.title = NSLocalizedString("_save_", comment: "")
            self.navigationController?.navigationBar.topItem?.title = NSLocalizedString(metadata.fileNamePrint, comment: "")
            
        } else {
            
            loadText = ""
        }
        
        textView.isUserInteractionEnabled = true
        textView.becomeFirstResponder()
        textView.delegate = self
        textView.selectedTextRange = textView.textRange(from: textView.beginningOfDocument, to: textView.beginningOfDocument)

        textViewDidChange(textView)
    }

    func keyboardWillShowHandle(info:NSNotification) {
        
        let frameView = self.view.convert(self.view.bounds, to: self.view.window)
        let endView = frameView.origin.y + frameView.size.height
        
        if let keyboardSize = (info.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue, let _ = self.view.window?.frame {
            
            if endView - keyboardSize.origin.y > 0 {
                bottomConstraint.constant = endView - keyboardSize.origin.y
            } else {
                bottomConstraint.constant = 0
            }
        }
    }
    
    func keyboardWillHideHandle() {
        bottomConstraint.constant = 0
    }
    
    func textViewDidChange(_ textView: UITextView) {
        
        if textView.text.characters.count == 0 {
            nextButton.isEnabled = false
        } else {
            nextButton.isEnabled = true
        }
    }
    
    @IBAction func cancelButtonTapped(_ sender: AnyObject) {
        
        if textView.text != loadText {
            
            let alertController = UIAlertController(title: NSLocalizedString("_info_", comment: ""), message: NSLocalizedString("_save_exit_", comment: ""), preferredStyle: .alert)
            
            let actionYes = UIAlertAction(title: NSLocalizedString("_yes_", comment: ""), style: .default) { (action:UIAlertAction) in
                self.dismiss(animated: true, completion: nil)
            }
            
            let actionNo = UIAlertAction(title: NSLocalizedString("_no_", comment: ""), style: .cancel) { (action:UIAlertAction) in
                print("You've pressed No button")
            }
            
            alertController.addAction(actionYes)
            alertController.addAction(actionNo)
            
            self.present(alertController, animated: true, completion:nil)
            
        } else {
            
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    @IBAction func nextButtonTapped(_ sender: AnyObject) {
        
        if let metadata = metadata {
            
            if textView.text != loadText {
            
                let uploadID = k_uploadSessionID + CCUtility.createRandomString(16)
                let data = textView.text.data(using: .utf8)
                let success = FileManager.default.createFile(atPath: "\(self.appDelegate.directoryUser!)/\(uploadID)", contents: data, attributes: nil)
            
                if success {
                
                    // Prepare for send Metadata
                    metadata.sessionID = uploadID
                    metadata.session = k_upload_session
                    metadata.sessionTaskIdentifier = Int(k_taskIdentifierWaitStart)
                    _ = NCManageDatabase.sharedInstance.updateMetadata(metadata)
                    appDelegate.activeMain.clearDateReadDataSource(nil)
                
                    self.dismiss(animated: true, completion: {
                        
                        // Send file
                        CCNetworking.shared().verifyUploadInErrorOrWait()
                        
                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "detailBack"), object: nil)
                    })

                } else {
                    self.appDelegate.messageNotification("_error_", description: "_error_creation_file_", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.info, errorCode: 0)
                }
                
            } else {
                self.dismiss(animated: true, completion: nil)
            }
            
        } else {
            
            let formViewController = CreateFormUploadFile.init(serverUrl: appDelegate.activeMain.serverUrl, text: self.textView.text, fileName: NSLocalizedString("_untitled_txt_", comment: ""))            
            self.navigationController?.pushViewController(formViewController, animated: true)
        }
    }
}
