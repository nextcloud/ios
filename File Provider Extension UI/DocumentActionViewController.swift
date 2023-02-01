//
//  DocumentActionViewController.swift
//  File Provider Extension UI
//
//  Created by Marino Faggiana on 30/01/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import UIKit
import FileProviderUI

class DocumentActionViewController: FPUIActionExtensionViewController {

    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var titleError: UILabel!

    override func loadView() {
        super.loadView()

        view.backgroundColor = NCBrandColor.shared.brand
        titleError.textColor = NCBrandColor.shared.brandText
        cancelButton.setTitleColor(NCBrandColor.shared.brandText, for: .normal)

        titleError.text = ""
    }
    override func prepare(forAction actionIdentifier: String, itemIdentifiers: [NSFileProviderItemIdentifier]) {
    }

    override func prepare(forError error: Error) {
        if let userInfo = (error as NSError).userInfo as NSDictionary?,
           let code = userInfo["code"] as? Int {
            if code == NCGlobal.shared.errorUnauthorizedFilesPasscode {
                titleError?.text = NSLocalizedString("_unauthorizedFilesPasscode_", comment: "")
            } else if code == NCGlobal.shared.errorDisableFilesApp {
                titleError?.text = NSLocalizedString("_disableFilesApp_", comment: "")
            }
        } else {
            titleError?.text = error.localizedDescription
        }
    }

    @IBAction func doneButtonTapped(_ sender: Any) {
        // Perform the action and call the completion block. If an unrecoverable error occurs you must still call the completion block with an error. Use the error code FPUIExtensionErrorCode.failed to signal the failure.
        extensionContext.completeRequest()
    }

    @IBAction func cancelButtonTapped(_ sender: Any) {
        extensionContext.cancelRequest(withError: NSError(domain: FPUIErrorDomain, code: Int(FPUIExtensionErrorCode.userCancelled.rawValue), userInfo: nil))
    }
}
