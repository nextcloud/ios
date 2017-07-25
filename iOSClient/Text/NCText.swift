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

    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.topItem?.title = NSLocalizedString("_title_new_text_file_", comment: "")
        self.navigationController?.navigationBar.barTintColor = NCBrandColor.sharedInstance.brand
        self.navigationController?.navigationBar.tintColor = NCBrandColor.sharedInstance.navigationBarText
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: NCBrandColor.sharedInstance.navigationBarText]
        
        cancelButton.title = NSLocalizedString("_cancel_", comment: "")
        nextButton.title = NSLocalizedString("_next_", comment: "")
        
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        
    }
    
}
