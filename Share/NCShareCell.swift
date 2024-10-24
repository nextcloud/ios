//
//  NCShareCell.swift
//  Share
//
//  Created by Henrik Storch on 29.12.21.
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
import NextcloudKit

protocol NCShareCellDelegate: AnyObject {
    var uploadStarted: Bool { get }
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
    var account: String = ""
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()

    func setup(fileName: String, account: String) {
        self.fileName = fileName
        self.account = account
        let resultInternalType = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: fileName, mimeType: "", directory: false, account: account)

        backgroundColor = .systemBackground
        imageCell?.layer.cornerRadius = 6
        imageCell?.layer.masksToBounds = true

        if let image = UIImage.downsample(imageAt: URL(fileURLWithPath: NSTemporaryDirectory() + fileName), to: CGSize(width: 80, height: 80)) {
            imageCell.image = image
            imageCell.contentMode = .scaleAspectFill
        } else {
            imageCell.image = utility.loadImage(named: resultInternalType.iconName, useTypeIconFile: true, account: account)
            imageCell.contentMode = .scaleAspectFit
        }

        fileNameCell?.text = fileName

        let fileSize = utilityFileSystem.getFileSize(filePath: (NSTemporaryDirectory() + fileName))
        sizeCell?.text = utilityFileSystem.transformedSize(fileSize)

        moreButton?.setImage(NCImageCache.shared.getImageButtonMore(), for: .normal)
    }

    @IBAction func buttonTapped(_ sender: Any) {
        guard !fileName.isEmpty, delegate?.uploadStarted != true else { return }
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
