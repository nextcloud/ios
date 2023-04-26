//
//  NCShareNewUserAddComment.swift
//  Nextcloud
//
//  Created by TSI-mc on 21/06/21.
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
import SVGKit

class NCShareNewUserAddComment: UIViewController, NCShareDetail {

    @IBOutlet weak var headerContainerView: UIView!
    @IBOutlet weak var sharingLabel: UILabel!
    @IBOutlet weak var noteTextField: UITextView!

    let contentInsets: CGFloat = 16
    var onDismiss: (() -> Void)?

    public var share: NCTableShareable!
    public var metadata: tableMetadata!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setNavigationTitle()

        NotificationCenter.default.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)

        sharingLabel.text = NSLocalizedString("_share_note_recipient_", comment: "")

        noteTextField.textContainerInset = UIEdgeInsets(top: contentInsets, left: contentInsets, bottom: contentInsets, right: contentInsets)
        noteTextField.text = share.note
        let toolbar = UIToolbar.toolbar {
            self.noteTextField.resignFirstResponder()
            self.noteTextField.text = ""
            self.share.note = ""
        } completion: {
            self.noteTextField.resignFirstResponder()
            self.share.note = self.noteTextField.text
        }

        noteTextField.inputAccessoryView = toolbar.wrappedSafeAreaContainer

        guard let headerView = (Bundle.main.loadNibNamed("NCShareAdvancePermissionHeader", owner: self, options: nil)?.first as? NCShareAdvancePermissionHeader) else { return }
        headerContainerView.addSubview(headerView)
        headerView.frame = headerContainerView.frame
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.topAnchor.constraint(equalTo: headerContainerView.topAnchor).isActive = true
        headerView.bottomAnchor.constraint(equalTo: headerContainerView.bottomAnchor).isActive = true
        headerView.leftAnchor.constraint(equalTo: headerContainerView.leftAnchor).isActive = true
        headerView.rightAnchor.constraint(equalTo: headerContainerView.rightAnchor).isActive = true

        headerView.setupUI(with: metadata)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        share.note = noteTextField.text
        onDismiss?()
    }

    @objc func adjustForKeyboard(notification: Notification) {
        guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue,
              let globalTextViewFrame = noteTextField.superview?.convert(noteTextField.frame, to: nil) else { return }

        let keyboardScreenEndFrame = keyboardValue.cgRectValue
        let portionCovoredByLeyboard = globalTextViewFrame.maxY - keyboardScreenEndFrame.minY

        if notification.name == UIResponder.keyboardWillHideNotification || portionCovoredByLeyboard < 0 {
            noteTextField.contentInset = .zero
        } else {
            noteTextField.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: portionCovoredByLeyboard, right: 0)
        }

        noteTextField.scrollIndicatorInsets = noteTextField.contentInset
    }
}
