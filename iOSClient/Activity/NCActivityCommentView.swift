//
//  NCActivityCommentView.swift
//  Nextcloud
//
//  Created by Henrik Storch on 04.01.22.
//  Copyright © 2021 Henrik Storch. All rights reserved.
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

class NCActivityCommentView: UIView, UITextFieldDelegate {
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var newCommentField: UITextField!

    var completionHandler: ((String?) -> Void)?

    func setup(account: String, completionHandler: @escaping (String?) -> Void) {
        let session = NCSession.shared.getSession(account: account)
        self.completionHandler = completionHandler
        newCommentField.placeholder = NSLocalizedString("_new_comment_", comment: "")
        newCommentField.delegate = self

        let fileName = NCSession.shared.getFileName(urlBase: session.urlBase, user: session.user)
        let fileNameLocalPath = NCUtilityFileSystem().directoryUserData + "/" + fileName
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
