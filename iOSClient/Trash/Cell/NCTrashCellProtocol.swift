//
//  NCTrashCellProtocol.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 24/03/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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

protocol NCTrashCellProtocol {
    var objectId: String { get set }
    var labelTitle: UILabel! { get set }
    var labelInfo: UILabel! { get set }
    var imageItem: UIImageView! { get set }
    var account: String { get set }

    func selected(_ status: Bool, isEditMode: Bool, account: String)
}

extension NCTrashCellProtocol where Self: UICollectionViewCell {
    mutating func setupCellUI(tableTrash: tableTrash, image: UIImage?) {
        self.objectId = tableTrash.fileId
        self.labelTitle.text = tableTrash.trashbinFileName
        self.labelTitle.textColor = NCBrandColor.shared.textColor
        if self is NCTrashListCell {
            self.labelInfo?.text = NCUtility().dateDiff(tableTrash.trashbinDeletionTime as Date)
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .none
            dateFormatter.locale = Locale.current
            self.labelInfo?.text = dateFormatter.string(from: tableTrash.trashbinDeletionTime as Date)
        }
        if tableTrash.directory {
            self.imageItem.image = NCImageCache.shared.getFolder(account: tableTrash.account)
        } else {
            self.imageItem.image = image
            self.labelInfo?.text = (self.labelInfo?.text ?? "") + " · " + NCUtilityFileSystem().transformedSize(tableTrash.size)
        }
        self.accessibilityLabel = tableTrash.trashbinFileName + ", " + (self.labelInfo?.text ?? "")
    }
}
