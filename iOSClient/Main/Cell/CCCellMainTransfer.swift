//
//  CCCellMainTransfer.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 05.06.20.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//

import UIKit

class CCCellMainTransfer: UITableViewCell, NCImageCellProtocol {

    @IBOutlet weak var file: UIImageView!
    @IBOutlet weak var status: UIImageView!
    @IBOutlet weak var user: UIImageView!

    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var labelInfoFile: UILabel!

    @IBOutlet weak var transferButton: PKStopDownloadButton!

    var filePreviewImageView: UIImageView {
        get {
            return file
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        self.initCell()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        self.initCell()
    }

    func initCell() {
        separatorInset = UIEdgeInsets.init(top: 0, left: 60, bottom: 0, right: 0)
        accessoryType = UITableViewCell.AccessoryType.none
        file.image = nil
        file.layer.cornerRadius = 6
        file.layer.masksToBounds = true
        status.image = nil
        user.image = nil
        backgroundColor = NCBrandColor.sharedInstance.backgroundView

        labelTitle.textColor = NCBrandColor.sharedInstance.textView
        transferButton.tintColor = NCBrandColor.sharedInstance.optionItem
        labelTitle.isEnabled = true
        labelInfoFile.isEnabled = true
        file.backgroundColor = nil
    }

}
