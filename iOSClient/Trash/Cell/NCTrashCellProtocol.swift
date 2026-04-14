// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

protocol NCTrashCellProtocol {
    var objectId: String { get set }
    var labelTitle: UILabel! { get set }
    var labelExtension: UILabel! { get set }
    var labelInfo: UILabel! { get set }
    var imageItem: UIImageView! { get set }
    var account: String { get set }

    func selected(_ status: Bool, isEditMode: Bool, account: String)
}

extension NCTrashCellProtocol where Self: UICollectionViewCell {
    mutating func setupCellUI(tableTrash: tableTrash, image: UIImage?) {
        self.objectId = tableTrash.fileId

        setBidiSafeFilename(tableTrash.trashbinFileName, isDirectory: tableTrash.directory, titleLabel: labelTitle, extensionLabel: labelExtension)

        self.labelTitle.textColor = NCBrandColor.shared.textColor
        self.labelExtension?.textColor = NCBrandColor.shared.textColor
        if self is NCTrashListCell {
            self.labelInfo?.text = NCUtility().getRelativeDateTitle(tableTrash.trashbinDeletionTime as Date)
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

        if self is NCTrashGridCell {
            if labelExtension?.isHidden ?? true {
                labelTitle.numberOfLines = 2
                labelTitle.lineBreakMode = .byWordWrapping
            } else {
                labelTitle.numberOfLines = 1
                labelTitle.lineBreakMode = .byTruncatingTail
            }
        }
    }
}
