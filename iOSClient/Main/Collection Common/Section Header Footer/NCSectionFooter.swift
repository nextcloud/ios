//
//  NCSectionFooter.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 20/07/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import UIKit

protocol NCSectionFooterDelegate: AnyObject {
    func tapButtonSection(_ sender: Any, metadataForSection: NCMetadataForSection?)
}

class NCSectionFooter: UICollectionReusableView {
    @IBOutlet weak var buttonSection: UIButton!
    @IBOutlet weak var activityIndicatorSection: UIActivityIndicatorView!
    @IBOutlet weak var labelSection: UILabel!
    @IBOutlet weak var separator: UIView!
    @IBOutlet weak var separatorHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var buttonSectionHeightConstraint: NSLayoutConstraint!

    weak var delegate: NCSectionFooterDelegate?
    var metadataForSection: NCMetadataForSection?
    let utilityFileSystem = NCUtilityFileSystem()

    override func awakeFromNib() {
        super.awakeFromNib()

        self.backgroundColor = .clear
        labelSection.textColor = NCBrandColor.shared.textColor2
        labelSection.text = ""

        separator.backgroundColor = .separator
        separatorHeightConstraint.constant = 0.5

        buttonIsHidden(true)
        activityIndicatorSection.isHidden = true
        activityIndicatorSection.color = NCBrandColor.shared.textColor
    }

    func setTitleLabel(directories: Int, files: Int, size: Int64) {
        var foldersText = ""
        var filesText = ""

        if directories > 1 {
            foldersText = "\(directories) " + NSLocalizedString("_folders_", comment: "")
        } else if directories == 1 {
            foldersText = "1 " + NSLocalizedString("_folder_", comment: "")
        }

        if files > 1 {
            filesText = "\(files) " + NSLocalizedString("_files_", comment: "") + " • " + utilityFileSystem.transformedSize(size)
        } else if files == 1 {
            filesText = "1 " + NSLocalizedString("_file_", comment: "") + " • " + utilityFileSystem.transformedSize(size)
        }

        if foldersText.isEmpty {
            labelSection.text = filesText
        } else if filesText.isEmpty {
            labelSection.text = foldersText
        } else {
            labelSection.text = foldersText + " • " + filesText
        }
    }

    func setTitleLabel(_ text: String) {
        labelSection.text = text
    }

    func setButtonText(_ text: String) {
        buttonSection.setTitle(text, for: .normal)
    }

    func separatorIsHidden(_ isHidden: Bool) {
        separator.isHidden = isHidden
    }

    func buttonIsHidden(_ isHidden: Bool) {
        buttonSection.isHidden = isHidden
        if isHidden {
            buttonSectionHeightConstraint.constant = 0
        } else {
            buttonSectionHeightConstraint.constant = NCGlobal.shared.heightFooterButton
        }
    }

    func showActivityIndicatorSection() {
        buttonSection.isHidden = true
        buttonSectionHeightConstraint.constant = NCGlobal.shared.heightFooterButton

        activityIndicatorSection.isHidden = false
        activityIndicatorSection.startAnimating()
    }

    func hideActivityIndicatorSection() {
        activityIndicatorSection.stopAnimating()
        activityIndicatorSection.isHidden = true
    }

    // MARK: - Action

    @IBAction func touchUpInsideButton(_ sender: Any) {
        delegate?.tapButtonSection(sender, metadataForSection: metadataForSection)
    }
}
