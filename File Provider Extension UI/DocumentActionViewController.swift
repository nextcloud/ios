//
//  DocumentActionViewController.swift
//  File Provider Extension UI
//
//  Created by Marino Faggiana on 30/01/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
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
import FileProviderUI

class DocumentActionViewController: FPUIActionExtensionViewController {

    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var titleError: UILabel!

    override func loadView() {
        super.loadView()

        view.backgroundColor = NCBrandColor.shared.customer
        titleError.textColor = NCBrandColor.shared.customerText
        cancelButton.setTitleColor(NCBrandColor.shared.customerText, for: .normal)

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
