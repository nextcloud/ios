//
//  NCCapabilitiesViewController.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 28/07/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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

class NCCapabilitiesViewController: UIViewController, UIDocumentInteractionControllerDelegate {

    @IBOutlet weak var textView: UITextView!

    @IBOutlet weak var imageFileSharing: UIImageView!
    @IBOutlet weak var statusFileSharing: UILabel!

    @IBOutlet weak var imageExternalSite: UIImageView!
    @IBOutlet weak var statusExternalSite: UILabel!

    @IBOutlet weak var imageEndToEndEncryption: UIImageView!
    @IBOutlet weak var statusEndToEndEncryption: UILabel!

    @IBOutlet weak var imageActivity: UIImageView!
    @IBOutlet weak var statusActivity: UILabel!

    @IBOutlet weak var imageNotification: UIImageView!
    @IBOutlet weak var statusNotification: UILabel!

    @IBOutlet weak var imageDeletedFiles: UIImageView!
    @IBOutlet weak var statusDeletedFiles: UILabel!

    @IBOutlet weak var imageUserStatus: UIImageView!
    @IBOutlet weak var statusUserStatus: UILabel!

    @IBOutlet weak var imageComments: UIImageView!
    @IBOutlet weak var statusComments: UILabel!

    @IBOutlet weak var imageText: UIImageView!
    @IBOutlet weak var statusText: UILabel!

    @IBOutlet weak var imageCollabora: UIImageView!
    @IBOutlet weak var statusCollabora: UILabel!

    @IBOutlet weak var imageOnlyOffice: UIImageView!
    @IBOutlet weak var statusOnlyOffice: UILabel!

    @IBOutlet weak var homeImage: UIImageView!
    @IBOutlet weak var homeServer: UILabel!

    @IBOutlet weak var imageLockFile: UIImageView!
    @IBOutlet weak var statusLockFile: UILabel!

    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var documentController: UIDocumentInteractionController?
    private var account: String = ""
    private var capabilitiesText = ""
    // private var timer: Timer?

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("_capabilities_", comment: "")

        let shareImage = UIImage(named: "shareFill")!.image(color: .gray, size: 25)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: shareImage, style: UIBarButtonItem.Style.plain, target: self, action: #selector(share))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_done_", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(close))

        textView.layer.cornerRadius = 15
        textView.layer.masksToBounds = true
        textView.backgroundColor = .secondarySystemBackground

        statusFileSharing.layer.cornerRadius = 12.5
        statusFileSharing.layer.borderWidth = 0.5
        statusFileSharing.layer.borderColor = UIColor.systemGray.cgColor
        statusFileSharing.layer.masksToBounds = true
        statusFileSharing.backgroundColor = .secondarySystemBackground

        statusExternalSite.layer.cornerRadius = 12.5
        statusExternalSite.layer.borderWidth = 0.5
        statusExternalSite.layer.borderColor = UIColor.systemGray.cgColor
        statusExternalSite.layer.masksToBounds = true
        statusExternalSite.backgroundColor = .secondarySystemBackground

        statusEndToEndEncryption.layer.cornerRadius = 12.5
        statusEndToEndEncryption.layer.borderWidth = 0.5
        statusEndToEndEncryption.layer.borderColor = UIColor.systemGray.cgColor
        statusEndToEndEncryption.layer.masksToBounds = true
        statusEndToEndEncryption.backgroundColor = .secondarySystemBackground

        statusActivity.layer.cornerRadius = 12.5
        statusActivity.layer.borderWidth = 0.5
        statusActivity.layer.borderColor = UIColor.systemGray.cgColor
        statusActivity.layer.masksToBounds = true
        statusActivity.backgroundColor = .secondarySystemBackground

        statusNotification.layer.cornerRadius = 12.5
        statusNotification.layer.borderWidth = 0.5
        statusNotification.layer.borderColor = UIColor.systemGray.cgColor
        statusNotification.layer.masksToBounds = true
        statusNotification.backgroundColor = .secondarySystemBackground

        statusDeletedFiles.layer.cornerRadius = 12.5
        statusDeletedFiles.layer.borderWidth = 0.5
        statusDeletedFiles.layer.borderColor = UIColor.systemGray.cgColor
        statusDeletedFiles.layer.masksToBounds = true
        statusDeletedFiles.backgroundColor = .secondarySystemBackground

        statusText.layer.cornerRadius = 12.5
        statusText.layer.borderWidth = 0.5
        statusText.layer.borderColor = UIColor.systemGray.cgColor
        statusText.layer.masksToBounds = true
        statusText.backgroundColor = .secondarySystemBackground

        statusCollabora.layer.cornerRadius = 12.5
        statusCollabora.layer.borderWidth = 0.5
        statusCollabora.layer.borderColor = UIColor.systemGray.cgColor
        statusCollabora.layer.masksToBounds = true
        statusCollabora.backgroundColor = .secondarySystemBackground

        statusOnlyOffice.layer.cornerRadius = 12.5
        statusOnlyOffice.layer.borderWidth = 0.5
        statusOnlyOffice.layer.borderColor = UIColor.systemGray.cgColor
        statusOnlyOffice.layer.masksToBounds = true
        statusOnlyOffice.backgroundColor = .secondarySystemBackground

        statusUserStatus.layer.cornerRadius = 12.5
        statusUserStatus.layer.borderWidth = 0.5
        statusUserStatus.layer.borderColor = UIColor.systemGray.cgColor
        statusUserStatus.layer.masksToBounds = true
        statusUserStatus.backgroundColor = .secondarySystemBackground

        statusComments.layer.cornerRadius = 12.5
        statusComments.layer.borderWidth = 0.5
        statusComments.layer.borderColor = UIColor.systemGray.cgColor
        statusComments.layer.masksToBounds = true
        statusComments.backgroundColor = .secondarySystemBackground

        statusLockFile.layer.cornerRadius = 12.5
        statusLockFile.layer.borderWidth = 0.5
        statusLockFile.layer.borderColor = UIColor.systemGray.cgColor
        statusLockFile.layer.masksToBounds = true
        statusLockFile.backgroundColor = .secondarySystemBackground

        imageFileSharing.image = UIImage(named: "share")!.image(color: UIColor.systemGray, size: 50)
        imageExternalSite.image = NCUtility.shared.loadImage(named: "network", color: UIColor.systemGray)
        imageEndToEndEncryption.image = NCUtility.shared.loadImage(named: "lock", color: UIColor.systemGray)
        imageActivity.image = UIImage(named: "bolt")!.image(color: UIColor.systemGray, size: 50)
        imageNotification.image = NCUtility.shared.loadImage(named: "bell", color: UIColor.systemGray)
        imageDeletedFiles.image = NCUtility.shared.loadImage(named: "trash", color: UIColor.systemGray)
        imageText.image = UIImage(named: "text")!.image(color: UIColor.systemGray, size: 50)
        imageCollabora.image = UIImage(named: "collabora")!.image(color: UIColor.systemGray, size: 50)
        imageOnlyOffice.image = UIImage(named: "onlyoffice")!.image(color: UIColor.systemGray, size: 50)
        imageUserStatus.image = UIImage(named: "userStatusAway")!.image(color: UIColor.systemGray, size: 50)
        imageComments.image = UIImage(named: "comments")!.image(color: UIColor.systemGray, size: 50)
        imageLockFile.image = UIImage(named: "lock")!.image(color: UIColor.systemGray, size: 50)

        guard let activeAccount = NCManageDatabase.shared.getActiveAccount() else { return }
        self.account = activeAccount.account

        if let text = NCManageDatabase.shared.getCapabilities(account: activeAccount.account) {
            capabilitiesText = text
            updateCapabilities()
        } else {
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_capabilities_found_")
            NCContentPresenter.shared.showError(error: error, priority: .max)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.dismiss(animated: true, completion: nil)
            }
        }

        homeImage.image = UIImage(named: "home")!.image(color: UIColor.systemGray, size: 50)
        homeServer.text = NCUtilityFileSystem.shared.getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId) + "/"
    }

    @objc func updateCapabilities() {

        NextcloudKit.shared.getCapabilities { account, data, error in
            if error == .success && data != nil {
                NCManageDatabase.shared.addCapabilitiesJSon(data!, account: account)

                // EDITORS
                let serverVersionMajor = NCManageDatabase.shared.getCapabilitiesServerInt(account: account, elements: NCElementsJSON.shared.capabilitiesVersionMajor)
                if serverVersionMajor >= NCGlobal.shared.nextcloudVersion18 {
                    NextcloudKit.shared.NCTextObtainEditorDetails { account, editors, creators, data, error in
                        if error == .success && account == self.appDelegate.account {
                            NCManageDatabase.shared.addDirectEditing(account: account, editors: editors, creators: creators)
                            self.readCapabilities()
                        }
                        if self.view.window != nil {
                            // self.timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.updateCapabilities), userInfo: nil, repeats: false)
                        }
                    }
                } else {
                    if self.view.window != nil {
                        // self.timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.updateCapabilities), userInfo: nil, repeats: false)
                    }
                }

                if let text = NCManageDatabase.shared.getCapabilities(account: account) {
                    self.capabilitiesText = text
                }
                self.readCapabilities()
            }
        }

        readCapabilities()
    }

    @objc func share() {
        // timer?.invalidate()
        self.dismiss(animated: true) {
            let fileURL = NSURL.fileURL(withPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("capabilities.txt")
            do {
                try self.capabilitiesText.write(to: fileURL, atomically: true, encoding: .utf8)

                if let view = self.appDelegate.window?.rootViewController?.view {
                    self.documentController = UIDocumentInteractionController(url: fileURL)
                    self.documentController?.delegate = self
                    self.documentController?.presentOptionsMenu(from: CGRect.zero, in: view, animated: true)
                }
            } catch { }
        }
    }

    @objc func close() {
        // timer?.invalidate()
        self.dismiss(animated: true, completion: nil)
    }

    func readCapabilities() {

        textView.text = capabilitiesText

        if NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesFileSharingApiEnabled, exists: false) {
            statusFileSharing.text = "✓ " + NSLocalizedString("_available_", comment: "")
        } else {
            statusFileSharing.text = NSLocalizedString("_not_available_", comment: "")
        }

        if NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesExternalSitesExists, exists: true) {
            statusExternalSite.text = "✓ " + NSLocalizedString("_available_", comment: "")
        } else {
            statusExternalSite.text = NSLocalizedString("_not_available_", comment: "")
        }

        let isE2EEEnabled = NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesE2EEEnabled, exists: false)
        // let versionE2EE = NCManageDatabase.shared.getCapabilitiesServerString(account: account, elements: NCElementsJSON.shared.capabilitiesE2EEApiVersion)

        if isE2EEEnabled {
            statusEndToEndEncryption.text = "✓ " + NSLocalizedString("_available_", comment: "")
        } else {
            statusEndToEndEncryption.text = NSLocalizedString("_not_available_", comment: "")
        }

        let activity = NCManageDatabase.shared.getCapabilitiesServerArray(account: account, elements: NCElementsJSON.shared.capabilitiesActivity)
        if activity != nil {
            statusActivity.text = "✓ " + NSLocalizedString("_available_", comment: "")
        } else {
            statusActivity.text = NSLocalizedString("_not_available_", comment: "")
        }

        let notification = NCManageDatabase.shared.getCapabilitiesServerArray(account: account, elements: NCElementsJSON.shared.capabilitiesNotification)
        if notification != nil {
            statusNotification.text = "✓ " + NSLocalizedString("_available_", comment: "")
        } else {
            statusNotification.text = NSLocalizedString("_not_available_", comment: "")
        }

        let deleteFiles = NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesFilesUndelete, exists: false)
        if deleteFiles {
            statusDeletedFiles.text = "✓ " + NSLocalizedString("_available_", comment: "")
        } else {
            statusDeletedFiles.text = NSLocalizedString("_not_available_", comment: "")
        }

        var textEditor = false
        var onlyofficeEditors = false
        if let editors = NCManageDatabase.shared.getDirectEditingEditors(account: account) {
            for editor in editors {
                if editor.editor == NCGlobal.shared.editorText {
                    textEditor = true
                } else if editor.editor == NCGlobal.shared.editorOnlyoffice {
                    onlyofficeEditors = true
                }
            }
        }

        if textEditor {
            statusText.text = "✓ " + NSLocalizedString("_available_", comment: "")
        } else {
            statusText.text = NSLocalizedString("_not_available_", comment: "")
        }

        let richdocumentsMimetypes = NCManageDatabase.shared.getCapabilitiesServerArray(account: account, elements: NCElementsJSON.shared.capabilitiesRichdocumentsMimetypes)
        if richdocumentsMimetypes != nil {
            statusCollabora.text = "✓ " + NSLocalizedString("_available_", comment: "")
        } else {
            statusCollabora.text = NSLocalizedString("_not_available_", comment: "")
        }

        if onlyofficeEditors {
            statusOnlyOffice.text = "✓ " + NSLocalizedString("_available_", comment: "")
        } else {
            statusOnlyOffice.text = NSLocalizedString("_not_available_", comment: "")
        }

        let userStatus = NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesUserStatusEnabled, exists: false)
        if userStatus {
            statusUserStatus.text = "✓ " + NSLocalizedString("_available_", comment: "")
        } else {
            statusUserStatus.text = NSLocalizedString("_not_available_", comment: "")
        }

        let comments = NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesFilesComments, exists: false)
        if comments {
            statusComments.text = "✓ " + NSLocalizedString("_available_", comment: "")
        } else {
            statusComments.text = NSLocalizedString("_not_available_", comment: "")
        }

        let hasLockCapability = NCManageDatabase.shared.getCapabilitiesServerInt(account: appDelegate.account, elements: NCElementsJSON.shared.capabilitiesFilesLockVersion) >= 1
        if hasLockCapability {
            statusLockFile.text = "✓ " + NSLocalizedString("_available_", comment: "")
        } else {
            statusLockFile.text = NSLocalizedString("_not_available_", comment: "")
        }

        print("end.")
    }
}
