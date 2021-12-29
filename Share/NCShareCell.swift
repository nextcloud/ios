//
//  NCShareCell.swift
//  Share
//
//  Created by Henrik Storch on 29.12.21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import UIKit
import NCCommunication

protocol NCShareCellDelegate: AnyObject {
    func removeFile(named fileName: String)
}

class NCShareCell: UITableViewCell {
    @IBOutlet weak var imageCell: UIImageView!
    @IBOutlet weak var fileNameCell: UILabel!
    @IBOutlet weak var moreButton: UIButton!
    @IBOutlet weak var sizeCell: UILabel!
    weak var delegate: NCShareCellDelegate?
    var fileName = ""

    func setup(fileName: String) {
        self.fileName = fileName
        let resultInternalType = NCCommunicationCommon.shared.getInternalType(fileName: fileName, mimeType: "", directory: false)

        backgroundColor = NCBrandColor.shared.systemBackground
        imageCell?.layer.cornerRadius = 6
        imageCell?.layer.masksToBounds = true

        if let image = UIImage(contentsOfFile: (NSTemporaryDirectory() + fileName)) {
            imageCell?.image = image.resizeImage(size: CGSize(width: 80, height: 80), isAspectRation: true)
        } else {
            if !resultInternalType.iconName.isEmpty {
                imageCell?.image = UIImage(named: resultInternalType.iconName)
            } else {
                imageCell?.image = NCBrandColor.cacheImages.file
            }
        }

        fileNameCell?.text = fileName

        let fileSize = NCUtilityFileSystem.shared.getFileSize(filePath: (NSTemporaryDirectory() + fileName))
        sizeCell?.text = CCUtility.transformedSize(fileSize)

        moreButton?.setImage(NCUtility.shared.loadImage(named: "deleteScan").image(color: NCBrandColor.shared.label, size: 15), for: .normal)
    }

    @IBAction func buttonTapped(_ sender: Any) {
        delegate?.removeFile(named: fileName)
    }
}
