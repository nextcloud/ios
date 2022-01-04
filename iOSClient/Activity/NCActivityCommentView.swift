//
//  NCActivityCommentView.swift
//  Nextcloud
//
//  Created by Henrik Storch on 04.01.22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//

import UIKit

class NCActivityCommentView: UIView, UITextFieldDelegate {
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var labelUser: UILabel!
    @IBOutlet weak var newCommentField: UITextField!

    var completionHandler: ((String?) -> Void)?

    func setup(urlBase: NCUserBaseUrl, account: tableAccount, completionHandler: @escaping (String?) -> Void) {
        self.completionHandler = completionHandler
        newCommentField.placeholder = NSLocalizedString("_new_comment_", comment: "")
        newCommentField.delegate = self

        let fileName = urlBase.userBaseUrl + "-" + urlBase.user + ".png"
        let fileNameLocalPath = String(CCUtility.getDirectoryUserData()) + "/" + fileName
        if let image = UIImage(contentsOfFile: fileNameLocalPath) {
            imageItem.image = image
        } else {
            imageItem.image = UIImage(named: "avatar")
        }

        if account.displayName.isEmpty {
            labelUser.text = account.user
        } else {
            labelUser.text = account.displayName
        }
        labelUser.textColor = NCBrandColor.shared.label
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        completionHandler?(textField.text)
        return true
    }
}
