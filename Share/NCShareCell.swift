// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2021 Marino Faggiana
// SPDX-FileCopyrightText: 2021 Henrik Storch
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

protocol NCShareCellDelegate: AnyObject {
    func removeFile(named fileName: String)
    func showRenameFileDialog(named fileName: String, account: String)
    func renameFile(oldName: String, newName: String, account: String)
}

class NCShareCell: UITableViewCell {
    @IBOutlet weak var imageCell: UIImageView!
    @IBOutlet weak var fileNameCell: UILabel!
    @IBOutlet weak var moreButton: UIButton!
    @IBOutlet weak var sizeCell: UILabel!
    weak var delegate: (NCShareCellDelegate & UIViewController)?
    var fileName: String = ""
    var iconName: String = ""
    var account: String = ""
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()

    func setup(fileName: String, iconName: String, account: String) {
        self.fileName = fileName
        self.account = account
        self.iconName = iconName

        backgroundColor = .systemBackground
        imageCell?.layer.cornerRadius = 6
        imageCell?.layer.masksToBounds = true

        if let image = UIImage.downsample(imageAt: URL(fileURLWithPath: NSTemporaryDirectory() + fileName), to: CGSize(width: 80, height: 80)) {
            imageCell.image = image
            imageCell.contentMode = .scaleAspectFill
        } else {
            imageCell.image = utility.loadImage(named: iconName, useTypeIconFile: true, account: account)
            imageCell.contentMode = .scaleAspectFit
        }

        fileNameCell?.text = fileName

        let fileSize = utilityFileSystem.getFileSize(filePath: (NSTemporaryDirectory() + fileName))
        sizeCell?.text = utilityFileSystem.transformedSize(fileSize)

        moreButton?.setImage(NCImageCache.shared.getImageButtonMore(), for: .normal)
    }

    @IBAction func buttonTapped(_ sender: Any) {
        let alertController = UIAlertController(title: "", message: fileName, preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_rename_file_", comment: ""), style: .default) { _ in
            self.delegate?.showRenameFileDialog(named: self.fileName, account: self.account)
        })

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_remove_file_", comment: ""), style: .default) { _ in
            self.delegate?.removeFile(named: self.fileName)
        })

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel) { _ in })
        delegate?.present(alertController, animated: true, completion: nil)
    }
}
