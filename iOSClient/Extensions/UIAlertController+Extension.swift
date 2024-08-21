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

import Foundation
import UIKit
import NextcloudKit

extension UIAlertController {
    /// Creates a alert controller with a textfield, asking to create a new folder
    /// - Parameters:
    ///   - serverUrl: Server url of the location where the folder should be created
    ///   - urlBase: UrlBase object
    ///   - completion: If not` nil` it overrides the default behavior which shows an error using `NCContentPresenter`
    /// - Returns: The presentable alert controller
    static func createFolder(serverUrl: String, userBaseUrl: NCUserBaseUrl, markE2ee: Bool = false, sceneIdentifier: String? = nil, completion: ((_ error: NKError) -> Void)? = nil) -> UIAlertController {
        let alertController = UIAlertController(title: NSLocalizedString("_create_folder_", comment: ""), message: nil, preferredStyle: .alert)

        let okAction = UIAlertAction(title: NSLocalizedString("_save_", comment: ""), style: .default, handler: { _ in
            guard let fileNameFolder = alertController.textFields?.first?.text else { return }
            if markE2ee {
                Task {
                    let createFolderResults = await NCNetworking.shared.createFolder(serverUrlFileName: serverUrl + "/" + fileNameFolder, account: userBaseUrl.account)
                    if createFolderResults.error == .success {
                        let error = await NCNetworkingE2EEMarkFolder().markFolderE2ee(account: userBaseUrl.account, fileName: fileNameFolder, serverUrl: serverUrl, userId: userBaseUrl.userId)
                        if error != .success {
                            NCContentPresenter().showError(error: error)
                        }
                    } else {
                        NCContentPresenter().showError(error: createFolderResults.error)
                    }
                }
            } else {
                NCNetworking.shared.createFolder(fileName: fileNameFolder, serverUrl: serverUrl, account: userBaseUrl.account, urlBase: userBaseUrl.urlBase, userId: userBaseUrl.userId, overwrite: false, withPush: true, sceneIdentifier: sceneIdentifier) { error in
                    if let completion = completion {
                        completion(error)
                    } else if error != .success {
                        NCContentPresenter().showError(error: error)
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
                guard let text = alertController.textFields?.first?.text else { return }
                let folderName = text.trimmingCharacters(in: .whitespaces)

                let textCheck = FileNameValidator.shared.checkFileName(folderName)
                okAction.isEnabled = textCheck?.error == nil && !folderName.isEmpty
                alertController.message = textCheck?.error.localizedDescription
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

    static func deleteFileOrFolder(titleString: String, message: String?, canDeleteServer: Bool, selectedMetadatas: [tableMetadata], completion: @escaping (_ cancelled: Bool) -> Void) -> UIAlertController {
        let alertController = UIAlertController(
            title: titleString,
            message: message,
            preferredStyle: .alert)
        if canDeleteServer {
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_", comment: ""), style: .destructive) { (_: UIAlertAction) in
                Task {
                    var error = NKError()
                    var ocId: [String] = []
                    for metadata in selectedMetadatas where error == .success {
                        error = await NCNetworking.shared.deleteMetadata(metadata, onlyLocalCache: false)
                        if error == .success {
                            ocId.append(metadata.ocId)
                        }
                    }
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDeleteFile, userInfo: ["ocId": ocId, "onlyLocalCache": false, "error": error])
                }
                completion(false)
            })
        }

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_remove_local_file_", comment: ""), style: .default) { (_: UIAlertAction) in
            Task {
                var error = NKError()
                var ocId: [String] = []
                for metadata in selectedMetadatas where error == .success {
                    error = await NCNetworking.shared.deleteMetadata(metadata, onlyLocalCache: true)
                    if error == .success {
                        ocId.append(metadata.ocId)
                    }
                }
                if error != .success {
                    NCContentPresenter().showError(error: error)
                }
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDeleteFile, userInfo: ["ocId": ocId, "onlyLocalCache": true, "error": error])
            }
            completion(false)
        })

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel) { (_: UIAlertAction) in
            completion(true)
        })
        return alertController
    }

    static func renameFile(fileName: String, completion: @escaping (_ newFileName: String) -> Void) -> UIAlertController {
        let alertController = UIAlertController(title: NSLocalizedString("_rename_", comment: ""), message: nil, preferredStyle: .alert)

        let okAction = UIAlertAction(title: NSLocalizedString("_save_", comment: ""), style: .default, handler: { _ in
            guard let newFileName = alertController.textFields?.first?.text else { return }

            completion(newFileName)
        })

        // text field is initially empty, no action
        okAction.isEnabled = false
        let cancelAction = UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel)

        alertController.addTextField { textField in
            textField.text = fileName
            textField.autocapitalizationType = .words
        }

        // only allow saving if folder name exists
        NotificationCenter.default.addObserver(
            forName: UITextField.textDidBeginEditingNotification,
            object: alertController.textFields?.first,
            queue: .main) { _ in
                guard let textField = alertController.textFields?.first else { return }

                if let start = textField.position(from: textField.beginningOfDocument, offset: 0),
                   let end = textField.position(from: start, offset: textField.text?.withRemovedFileExtension.count ?? 0) {
                    textField.selectedTextRange = textField.textRange(from: start, to: end)
                }
            }

        NotificationCenter.default.addObserver(
            forName: UITextField.textDidChangeNotification,
            object: alertController.textFields?.first,
            queue: .main) { _ in
                guard let text = alertController.textFields?.first?.text else { return }

                let textCheck = FileNameValidator.shared.checkFileName(text)
                okAction.isEnabled = textCheck?.error == nil && !text.isEmpty
                alertController.message = textCheck?.error.localizedDescription
            }

        alertController.addAction(cancelAction)
        alertController.addAction(okAction)
        return alertController
    }

    static func renameFile(metadata: tableMetadata, indexPath: IndexPath) -> UIAlertController {
        let alertController = UIAlertController(title: NSLocalizedString("_rename_", comment: ""), message: nil, preferredStyle: .alert)

        let okAction = UIAlertAction(title: NSLocalizedString("_save_", comment: ""), style: .default, handler: { _ in
            guard let newFileName = alertController.textFields?.first?.text else { return }

            // verify if already exists
            if NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", metadata.account, metadata.serverUrl, newFileName)) != nil {
                NCContentPresenter().showError(error: NKError(errorCode: 0, errorDescription: "_rename_already_exists_"))
                return
            }

            NCActivityIndicator.shared.start()

            NCNetworking.shared.renameMetadata(metadata, fileNameNew: newFileName, indexPath: indexPath) { error in

                NCActivityIndicator.shared.stop()

                if error != .success {
                    NCContentPresenter().showError(error: error)
                }
            }
        })

        // text field is initially empty, no action
        okAction.isEnabled = false
        let cancelAction = UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel)

        alertController.addTextField { textField in
            textField.text = metadata.fileName
            textField.autocapitalizationType = .words
        }

        // only allow saving if folder name exists
        NotificationCenter.default.addObserver(
            forName: UITextField.textDidBeginEditingNotification,
            object: alertController.textFields?.first,
            queue: .main) { _ in
                guard let textField = alertController.textFields?.first else { return }

                if let start = textField.position(from: textField.beginningOfDocument, offset: 0),
                   let end = textField.position(from: start, offset: textField.text?.withRemovedFileExtension.count ?? 0) {
                    textField.selectedTextRange = textField.textRange(from: start, to: end)
                }
            }

        NotificationCenter.default.addObserver(
            forName: UITextField.textDidChangeNotification,
            object: alertController.textFields?.first,
            queue: .main) { _ in
                guard let text = alertController.textFields?.first?.text else { return }

                let textCheck = FileNameValidator.shared.checkFileName(text)
                okAction.isEnabled = textCheck?.error == nil && !text.isEmpty
                alertController.message = textCheck?.error.localizedDescription
            }

        alertController.addAction(cancelAction)
        alertController.addAction(okAction)
        return alertController
    }

    static func warning(title: String? = nil, message: String? = nil) -> UIAlertController {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let okAction = UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default)

        alertController.addAction(okAction)

        return alertController
    }
}
