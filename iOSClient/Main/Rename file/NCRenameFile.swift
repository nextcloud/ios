//
//  NCRenameFile.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 26/02/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import Foundation

class NCRenameFile: UIViewController {

    @IBOutlet weak var image: UIImageView!
    
    @IBOutlet weak var fileName: UITextField!
    @IBOutlet weak var fileExtension: UITextField!

    var metadata: tableMetadata?
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let metadata = self.metadata {
            fileName.text = metadata.fileNameWithoutExt
            fileExtension.text = metadata.ext
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
        
    }
}
