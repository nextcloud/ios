//
//  NCRenameFile.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 26/02/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import Foundation
import NCCommunication

class NCRenameFile: UIViewController {

    @IBOutlet weak var image: UIImageView!
    
    @IBOutlet weak var fileNameWithoutExt: UITextField!
    @IBOutlet weak var ext: UITextField!

    var metadata: tableMetadata?
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let metadata = self.metadata {
            fileNameWithoutExt.text = metadata.fileNameWithoutExt
            ext.text = metadata.ext
        }
        
        title = NSLocalizedString("_rename_file_", comment: "")
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_rename_", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(rename))
    }

    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if metadata == nil {
            dismiss(animated: true)
        }
    }
    
    // MARK: - Action
    
    @objc func cancel() {
        dismiss(animated: true)
    }
    
    @objc func rename() {
        
        guard let metadata = metadata else { return }
        var newFileNameWithoutExt = ""
        var newExt = ""
        
        if fileNameWithoutExt.text == nil || fileNameWithoutExt.text?.count == 0 {
            self.fileNameWithoutExt.text = metadata.fileNameWithoutExt
            return
        } else {
            newFileNameWithoutExt = fileNameWithoutExt.text!
        }
        
        if ext.text == nil || ext.text?.count == 0 {
            self.ext.text = metadata.ext
            return
        } else {
            newExt = ext.text!
        }
        
        let fileNameNew = newFileNameWithoutExt + "." + newExt
        
        NCNetworking.shared.renameMetadata(metadata, fileNameNew: fileNameNew, urlBase: metadata.urlBase, viewController: self) { (errorCode, errorDescription) in
            if errorCode == 0 {
                self.dismiss(animated: true)
            } else {
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
            }
        }
    }
}
