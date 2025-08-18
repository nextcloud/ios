// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

class NCActivityCommentView: UIView, UITextFieldDelegate {
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var newCommentField: UITextField!

    var completionHandler: ((String?) -> Void)?
    let utilityFileSystem = NCUtilityFileSystem()

    func setup(account: String, completionHandler: @escaping (String?) -> Void) {
        let session = NCSession.shared.getSession(account: account)
        self.completionHandler = completionHandler
        newCommentField.placeholder = NSLocalizedString("_new_comment_", comment: "")
        newCommentField.delegate = self

        let fileName = NCSession.shared.getFileName(urlBase: session.urlBase, user: session.user)
        let fileNameLocalPath = utilityFileSystem.createServerUrl(serverUrl: utilityFileSystem.directoryUserData, fileName: fileName)
        if let image = UIImage(contentsOfFile: fileNameLocalPath) {
            imageItem.image = image
        } else {
            imageItem.image = NCUtility().loadImage(named: "person.crop.circle", colors: [NCBrandColor.shared.iconImageColor])
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        completionHandler?(textField.text)
        return true
    }
}

extension NCActivityCommentView: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        completionHandler?(searchBar.text)
    }
}
