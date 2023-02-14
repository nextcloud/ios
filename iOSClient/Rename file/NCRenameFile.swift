//
//  NCRenameFile.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 26/02/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
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
import NextcloudKit

public protocol NCRenameFileDelegate: AnyObject {
    func rename(fileName: String, fileNameNew: String)
}

// optional func
public extension NCRenameFileDelegate {
    func rename(fileName: String, fileNameNew: String) {}
}

class NCRenameFile: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var previewFile: UIImageView!
    @IBOutlet weak var fileNameNoExtension: UITextField!
    @IBOutlet weak var point: UILabel!
    @IBOutlet weak var ext: UITextField!
    @IBOutlet weak var fileNameNoExtensionTrailingContraint: NSLayoutConstraint!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var renameButton: UIButton!

    let width: CGFloat = 300
    let height: CGFloat = 310

    var metadata: tableMetadata?
    var fileName: String?
    var imagePreview: UIImage?
    var disableChangeExt: Bool = false
    weak var delegate: NCRenameFileDelegate?

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        if let metadata = self.metadata {

            if metadata.directory {
                titleLabel.text = NSLocalizedString("_rename_folder_", comment: "")
            } else {
                titleLabel.text = NSLocalizedString("_rename_file_", comment: "")
            }

            fileNameNoExtension.text = (metadata.fileNameView as NSString).deletingPathExtension
            fileNameNoExtension.delegate = self
            fileNameNoExtension.becomeFirstResponder()

            ext.text = metadata.fileExtension
            ext.delegate = self
            if disableChangeExt {
                ext.isEnabled = false
                ext.textColor = .lightGray
            }

            previewFile.image = imagePreview
            previewFile.layer.cornerRadius = 10
            previewFile.layer.masksToBounds = true

            if metadata.directory {

                if imagePreview == nil {
                    previewFile.image = NCBrandColor.cacheImages.folder
                }

                ext.isHidden = true
                point.isHidden = true
                fileNameNoExtensionTrailingContraint.constant = 20

            } else {

                if imagePreview == nil {
                    previewFile.image = NCBrandColor.cacheImages.file
                }

                fileNameNoExtensionTrailingContraint.constant = 90
            }

        } else if let fileName = self.fileName {

            titleLabel.text = NSLocalizedString("_rename_file_", comment: "")

            fileNameNoExtension.text = (fileName as NSString).deletingPathExtension
            fileNameNoExtension.delegate = self
            fileNameNoExtension.becomeFirstResponder()
            fileNameNoExtensionTrailingContraint.constant = 90

            ext.text = (fileName as NSString).pathExtension
            ext.delegate = self

            if imagePreview == nil {
                previewFile.image = NCBrandColor.cacheImages.file
            } else {
                previewFile.image = imagePreview
            }
            previewFile.layer.cornerRadius = 10
            previewFile.layer.masksToBounds = true
        }

        cancelButton.setTitle(NSLocalizedString("_cancel_", comment: ""), for: .normal)
        renameButton.setTitle(NSLocalizedString("_rename_", comment: ""), for: .normal)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if metadata == nil && fileName == nil {
            dismiss(animated: true)
        }

        fileNameNoExtension.selectAll(nil)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {

        textField.resignFirstResponder()
        renameFile(textField)
        return true
    }

    // MARK: - Action

    @IBAction func cancel(_ sender: Any) {

        dismiss(animated: true)
    }

    @IBAction func renameFile(_ sender: Any) {

        var fileNameNoExtensionNew = ""
        var extNew = ""
        var fileNameNew = ""

        if let metadata = self.metadata {

            let extCurrent = (metadata.fileNameView as NSString).pathExtension

            if fileNameNoExtension.text == nil || fileNameNoExtension.text?.count == 0 {
                self.fileNameNoExtension.text = (metadata.fileNameView as NSString).deletingPathExtension
                return
            } else {
                fileNameNoExtensionNew = fileNameNoExtension.text!
            }

            if metadata.directory {

                fileNameNew = fileNameNoExtensionNew
                renameMetadata(metadata, fileNameNew: fileNameNew)

            } else {

                if ext.text == nil || ext.text?.count == 0 {
                    self.ext.text = metadata.fileExtension
                    return
                } else {
                    extNew = ext.text!
                }

                if extNew != extCurrent {

                    let message = String(format: NSLocalizedString("_rename_ext_message_", comment: ""), extNew, extCurrent)
                    let alertController = UIAlertController(title: NSLocalizedString("_rename_ext_title_", comment: ""), message: message, preferredStyle: .alert)

                    var title = NSLocalizedString("_use_", comment: "") + " ." + extNew
                    alertController.addAction(UIAlertAction(title: title, style: .default, handler: { _ in

                        fileNameNew = fileNameNoExtensionNew + "." + extNew
                        self.renameMetadata(metadata, fileNameNew: fileNameNew)
                    }))

                    title = NSLocalizedString("_keep_", comment: "") + " ." + extCurrent
                    alertController.addAction(UIAlertAction(title: title, style: .default, handler: { _ in
                        self.ext.text = metadata.fileExtension
                    }))

                    self.present(alertController, animated: true)

                } else {

                    fileNameNew = fileNameNoExtensionNew + "." + extNew
                    renameMetadata(metadata, fileNameNew: fileNameNew)
                }
            }

        } else if let fileName = self.fileName {

            if fileNameNoExtension.text == nil || fileNameNoExtension.text?.count == 0 {
                fileNameNoExtension.text = (fileName as NSString).deletingPathExtension
                return
            } else if ext.text == nil || ext.text?.count == 0 {
                ext.text = (fileName as NSString).pathExtension
                return
            }

            fileNameNew = (fileNameNoExtension.text ?? "") + "." + (ext.text ?? "")
            self.dismiss(animated: true) {
                self.delegate?.rename(fileName: fileName, fileNameNew: fileNameNew)
            }
        }
    }

    // MARK: - Networking

    func renameMetadata(_ metadata: tableMetadata, fileNameNew: String) {

        // verify if already exists
        if NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", metadata.account, metadata.serverUrl, fileNameNew)) != nil {
            NCContentPresenter.shared.showError(error: NKError(errorCode: 0, errorDescription: "_rename_already_exists_"))
            return
        }

        NCActivityIndicator.shared.start()

        NCNetworking.shared.renameMetadata(metadata, fileNameNew: fileNameNew, viewController: self) { error in

            NCActivityIndicator.shared.stop()

            if error == .success {

                self.dismiss(animated: true)

            } else {

                NCContentPresenter.shared.showError(error: error)
            }
        }
    }
}
