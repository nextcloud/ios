//
//  NCText.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 24/07/17.
//  Copyright © 2017 TWS. All rights reserved.
//

import Foundation

class NCText: UIViewController, UITextViewDelegate {

    @IBOutlet weak var cancelButton: UIBarButtonItem!
    @IBOutlet weak var nextButton: UIBarButtonItem!
    @IBOutlet weak var textView: UITextView!
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    var metadata: tableMetadata?
    var loadText: String?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.topItem?.title = NSLocalizedString("_title_new_text_file_", comment: "")
        self.navigationController?.navigationBar.barTintColor = NCBrandColor.sharedInstance.brand
        self.navigationController?.navigationBar.tintColor = NCBrandColor.sharedInstance.navigationBarText
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: NCBrandColor.sharedInstance.navigationBarText]
        
        self.navigationController?.toolbar.barTintColor = NCBrandColor.sharedInstance.navigationBarText
        self.navigationController?.toolbar.tintColor = NCBrandColor.sharedInstance.brand
        
        cancelButton.title = NSLocalizedString("_cancel_", comment: "")
        nextButton.title = NSLocalizedString("_next_", comment: "")
        
        if let metadata = metadata {
            
            let path = "\(appDelegate.directoryUser!)/\(metadata.fileID)"
            
            loadText = try? String(contentsOfFile: path, encoding: String.Encoding.utf8)
            textView.text = loadText
        }
        
        textView.isUserInteractionEnabled = true
        textView.becomeFirstResponder()
    }

    override func viewWillAppear(_ animated: Bool) {

        super.viewWillAppear(animated)
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
            
            //let formViewController = CreateFormUploadFile.init(self.titleMain, serverUrl: self.serverUrl, text: self.textView.text, fileName: self.fileName!)
            //self.navigationController?.pushViewController(formViewController, animated: true)
            
        } else {
            
            let formViewController = CreateFormUploadFile.init(NSLocalizedString("_untitled_txt_", comment: ""), serverUrl: appDelegate.activeMain.serverUrl, text: self.textView.text, fileName: NSLocalizedString("_untitled_txt_", comment: ""))
            self.navigationController?.pushViewController(formViewController, animated: true)
        }
        
        
        
        
    }
}
