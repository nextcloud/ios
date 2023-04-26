//
//  UIAlertController+Extension.swift
//  Nextcloud
//
//  Created by Henrik Storch on 27.01.22.
//  Copyright © 2022 Henrik Storch. All rights reserved.
//
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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
import NextcloudKit

extension UIAlertController {
    /// Creates a alert controller with a textfield, asking to create a new folder
    /// - Parameters:
    ///   - serverUrl: Server url of the location where the folder should be created
    ///   - urlBase: UrlBase object
    ///   - completion: If not` nil` it overrides the default behavior which shows an error using `NCContentPresenter`
    /// - Returns: The presentable alert controller
    static func createFolder(serverUrl: String, urlBase: NCUserBaseUrl, markE2ee: Bool = false, completion: ((_ error: NKError) -> Void)? = nil) -> UIAlertController {
        let alertController = UIAlertController(title: NSLocalizedString("_create_folder_", comment: ""), message: nil, preferredStyle: .alert)

        let okAction = UIAlertAction(title: NSLocalizedString("_save_", comment: ""), style: .default, handler: { _ in
            guard let fileNameFolder = alertController.textFields?.first?.text else { return }
            if markE2ee {
                Task {
                    let error = await NCNetworkingE2EECreateFolder.shared.createFolderAndMarkE2EE(fileName: fileNameFolder, serverUrl: serverUrl, account: urlBase.account)
                    if error != .success {
                        NCContentPresenter.shared.showError(error: error)
                    }
                }
            } else {
                NCNetworking.shared.createFolder(fileName: fileNameFolder, serverUrl: serverUrl, account: urlBase.account, urlBase: urlBase.urlBase, userId: urlBase.userId, overwrite: false, withPush: true) { error in
                    if let completion = completion {
                        completion(error)
                    } else if error != .success {
                        NCContentPresenter.shared.showError(error: error)
                    } // else: successful, no action
                }
            }
        })

        // text field is initially empty, no action
        okAction.isEnabled = false
        let cancelAction = UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel)

        alertController.addTextField { textField in
            textField.autocapitalizationType = .words
        }

        // only allow saving if folder name exists
        NotificationCenter.default.addObserver(
            forName: UITextField.textDidChangeNotification,
            object: alertController.textFields?.first,
            queue: .main) { _ in
                guard let text = alertController.textFields?.first?.text,
                      let folderName = CCUtility.removeForbiddenCharactersServer(text)?.trimmingCharacters(in: .whitespaces) else { return }
                okAction.isEnabled = !folderName.isEmpty && folderName != "." && folderName != ".."
            }

        alertController.addAction(cancelAction)
        alertController.addAction(okAction)
        return alertController
    }

    static func withTextField(titleKey: String, textFieldConfiguration: ((UITextField) -> Void)?, completion: @escaping (String?) -> Void) -> UIAlertController {
        let alertController = UIAlertController(title: NSLocalizedString(titleKey, comment: ""), message: "", preferredStyle: .alert)
        alertController.addTextField { textField in
            textFieldConfiguration?(textField)
        }
        alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .default) { _ in })
        let okAction = UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default) { _ in
            completion(alertController.textFields?.first?.text)
        }

        alertController.addAction(okAction)
        return alertController
    }

    static func password(titleKey: String, completion: @escaping (String?) -> Void) -> UIAlertController {
        return .withTextField(titleKey: titleKey, textFieldConfiguration: { textField in
            textField.isSecureTextEntry = true
            textField.placeholder = NSLocalizedString("_password_", comment: "")
        }, completion: completion)

    }
}
