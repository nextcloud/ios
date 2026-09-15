// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2006 TSI-mc
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

class NCShareNewUserAddComment: UIViewController, NCShareNavigationTitleSetting {

    @IBOutlet weak var headerContainerView: UIView!
    @IBOutlet weak var sharingLabel: UILabel!
    @IBOutlet weak var noteTextField: UITextView!

    let contentInsets: CGFloat = 16
    var onDismiss: (() -> Void)?

    public var share: Shareable!
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
        } onDone: {
            self.noteTextField.resignFirstResponder()
            self.share.note = self.noteTextField.text
            self.navigationController?.popViewController(animated: true)
        }

        noteTextField.inputAccessoryView = toolbar.wrappedSafeAreaContainer

        guard let headerView = (Bundle.main.loadNibNamed("NCShareHeader", owner: self, options: nil)?.first as? NCShareHeader) else { return }
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
