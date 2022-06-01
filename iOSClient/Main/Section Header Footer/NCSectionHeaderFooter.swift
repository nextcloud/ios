//
//  NCSectionHeaderFooter.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 09/10/2018.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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
import MarkdownKit

class NCSectionHeaderMenu: UICollectionReusableView, UIGestureRecognizerDelegate {

    @IBOutlet weak var buttonSwitch: UIButton!
    @IBOutlet weak var buttonOrder: UIButton!
    @IBOutlet weak var buttonMore: UIButton!

    @IBOutlet weak var buttonUpload: UIButton!
    @IBOutlet weak var buttonCreateFolder: UIButton!
    @IBOutlet weak var buttonScanDocument: UIButton!

    @IBOutlet weak var viewButtonsOne: UIView!
    @IBOutlet weak var viewButtonsTwo: UIView!
    @IBOutlet weak var viewSeparator: UIView!
    @IBOutlet weak var viewRichWorkspace: UIView!
    @IBOutlet weak var viewSection: UIView!

    @IBOutlet weak var viewButtonsOneHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewButtonsTwoHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewSeparatorHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewRichWorkspaceHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewSectionHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var textViewRichWorkspace: UITextView!
    @IBOutlet weak var labelSection: UILabel!


    weak var delegate: NCSectionHeaderMenuDelegate?

    private var markdownParser = MarkdownParser()
    private var richWorkspaceText: String?
    private var textViewColor: UIColor?
    private let gradient: CAGradientLayer = CAGradientLayer()

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = .clear

        buttonSwitch.setImage(UIImage(named: "switchList")!.image(color: NCBrandColor.shared.systemGray1, size: 25), for: .normal)

        buttonOrder.setTitle("", for: .normal)
        buttonOrder.setTitleColor(.systemBlue, for: .normal)
        buttonMore.setImage(UIImage(named: "more")!.image(color: NCBrandColor.shared.systemGray1, size: 25), for: .normal)

        let imageUpload = UIImage(named: "buttonAddImage")!.image(color: NCBrandColor.shared.systemGray1, size: 25)
        buttonUpload.backgroundColor = .clear
        buttonUpload.setTitleColor(.systemBlue, for: .normal)
        buttonUpload.setTitle(NSLocalizedString("_upload_", comment: ""), for: .normal)
        buttonUpload.layer.borderColor = UIColor.lightGray.cgColor
        buttonUpload.layer.borderWidth = 0.3
        buttonUpload.layer.cornerRadius = 3
        buttonUpload.setImage(imageUpload, for: .normal)

        let imageFolder = UIImage(named: "buttonAddFolder")!.image(color: NCBrandColor.shared.systemGray1, size: 25)
        buttonCreateFolder.backgroundColor = .clear
        buttonCreateFolder.setTitleColor(.systemBlue, for: .normal)
        buttonCreateFolder.setTitle(NSLocalizedString("_folder_", comment: ""), for: .normal)
        buttonCreateFolder.layer.borderColor = UIColor.lightGray.cgColor
        buttonCreateFolder.layer.borderWidth = 0.3
        buttonCreateFolder.layer.cornerRadius = 3
        buttonCreateFolder.setImage(imageFolder, for: .normal)

        let imageScan = NCUtility.shared.loadImage(named: "buttonAddScan").image(color: NCBrandColor.shared.systemGray1, size: 25)
        buttonScanDocument.backgroundColor = .clear
        buttonScanDocument.setTitleColor(.systemBlue, for: .normal)
        buttonScanDocument.setTitle(NSLocalizedString("_scan_", comment: ""), for: .normal)
        buttonScanDocument.layer.borderColor = UIColor.lightGray.cgColor
        buttonScanDocument.layer.borderWidth = 0.3
        buttonScanDocument.layer.cornerRadius = 3
        buttonScanDocument.setImage(imageScan, for: .normal)
        if #available(iOS 13.0, *) {
            buttonScanDocument.isHidden = false
        } else {
            buttonScanDocument.isHidden = true
        }

        // Gradient
        gradient.startPoint = CGPoint(x: 0, y: 0.50)
        gradient.endPoint = CGPoint(x: 0, y: 1)
        viewRichWorkspace.layer.addSublayer(gradient)
        setGradientColor()

        let tap = UITapGestureRecognizer(target: self, action: #selector(touchUpInsideViewRichWorkspace(_:)))
        tap.delegate = self
        viewRichWorkspace?.addGestureRecognizer(tap)

        viewSeparator.backgroundColor = UIColor(red: 0.79, green: 0.79, blue: 0.79, alpha: 1.0)
        viewSeparatorHeightConstraint.constant = 0.5

        markdownParser = MarkdownParser(font: UIFont.systemFont(ofSize: 15), color: NCBrandColor.shared.label)
        markdownParser.header.font = UIFont.systemFont(ofSize: 25)
        if let richWorkspaceText = richWorkspaceText {
            textViewRichWorkspace.attributedText = markdownParser.parse(richWorkspaceText)
        }
        textViewColor = NCBrandColor.shared.label

        labelSection.text = ""
        viewSectionHeightConstraint.constant = 0
    }

    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        gradient.frame = viewRichWorkspace.bounds
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setGradientColor()
    }

    //MARK: -

    func setGradientColor() {
        if traitCollection.userInterfaceStyle == .dark {
            gradient.colors = [UIColor(white: 0, alpha: 0).cgColor, UIColor.black.cgColor]
        } else {
            gradient.colors = [UIColor(white: 1, alpha: 0).cgColor, UIColor.white.cgColor]
        }
    }

    func setSortedTitle(_ title: String) {

        let title = NSLocalizedString(title, comment: "")
        //let size = title.size(withAttributes: [.font: buttonOrder.titleLabel?.font as Any])

        buttonOrder.setTitle(title, for: .normal)
    }

    func setRichWorkspaceText(_ text: String?) {
        guard let text = text else { return }
        if text != self.richWorkspaceText {
            textViewRichWorkspace.attributedText = markdownParser.parse(text)
            self.richWorkspaceText = text
        }
    }

    //MARK: -

    func setStatusButtonOne(count: Int) {
        if count == 0 {
            buttonSwitch.isEnabled = false
            buttonOrder.isEnabled = false
            buttonMore.isEnabled = false
        } else {
            buttonSwitch.isEnabled = true
            buttonOrder.isEnabled = true
            buttonMore.isEnabled = true
        }
    }

    func buttonMoreIsHidden(_ isHidden: Bool) {
        buttonMore.isHidden = isHidden
    }

    func setImageSwitchList() {
        buttonSwitch.setImage(UIImage(named: "switchList")!.image(color: NCBrandColor.shared.systemGray1, size: 50), for: .normal)
    }

    func setImageSwitchGrid() {
        buttonSwitch.setImage(UIImage(named: "switchGrid")!.image(color: NCBrandColor.shared.systemGray1, size: 50), for: .normal)
    }

    func setButtonsOneHeight(_ size:CGFloat) {
        viewButtonsOneHeightConstraint.constant = size
        if size == 0 {
            viewButtonsOne.isHidden = true
        } else {
            viewButtonsOne.isHidden = false
        }
    }

    func setButtonsTwoHeight(_ size:CGFloat) {
        viewButtonsTwoHeightConstraint.constant = size
        if size == 0 {
            viewButtonsTwo.isHidden = true
        } else {
            viewButtonsTwo.isHidden = false
        }
    }

    func setRichWorkspaceHeight(_ size: CGFloat) {
        viewRichWorkspaceHeightConstraint.constant = size
        if size == 0 {
            viewRichWorkspace.isHidden = true
        } else {
            viewRichWorkspace.isHidden = false
        }
    }

    func setSectionHeight(_ size:CGFloat) {
        viewSectionHeightConstraint.constant = size
        if size == 0 {
            viewSection.isHidden = true
        } else {
            viewSection.isHidden = false
        }
    }

    @IBAction func touchUpInsideMore(_ sender: Any) {
        delegate?.tapButtonMore(sender: sender)
    }

    @IBAction func touchUpInsideSwitch(_ sender: Any) {
        delegate?.tapButtonSwitch(sender: sender)
    }

    @IBAction func touchUpInsideOrder(_ sender: Any) {
        delegate?.tapButtonOrder(sender: sender)
    }

    @IBAction func touchUpInsideButtonUpload(_ sender: Any) {
       delegate?.tapButtonUpload(sender: sender)
    }

    @IBAction func touchUpInsideButtonCreateFolder(_ sender: Any) {
        delegate?.tapButtonCreateFolder(sender: sender)
    }

    @IBAction func touchUpInsideButtonScanDocument(_ sender: Any) {

    }

    @objc func touchUpInsideViewRichWorkspace(_ sender: Any) {
        delegate?.tapRichWorkspace(sender: sender)
    }
}

protocol NCSectionHeaderMenuDelegate: AnyObject {
    func tapButtonSwitch(sender: Any)
    func tapButtonOrder(sender: Any)
    func tapButtonMore(sender: Any)
    func tapButtonUpload(sender: Any)
    func tapButtonCreateFolder(sender: Any)
    func tapButtonScanDocument(sender: Any)
    func tapRichWorkspace(sender: Any)
}

// optional func
extension NCSectionHeaderMenuDelegate {
    func tapButtonSwitch(sender: Any) {}
    func tapButtonOrder(sender: Any) {}
    func tapButtonMore(sender: Any) {}
    func tapButtonUpload(sender: Any) {}
    func tapButtonCreateFolder(sender: Any) {}
    func tapButtonScanDocument(sender: Any) {}
    func tapRichWorkspace(sender: Any) {}
}

class NCSectionHeader: UICollectionReusableView {

    @IBOutlet weak var labelSection: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        self.backgroundColor = UIColor.clear
        self.labelSection.text = ""
    }
}

class NCSectionFooter: UICollectionReusableView {

    @IBOutlet weak var labelSection: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        self.backgroundColor = UIColor.clear
        labelSection.textColor = NCBrandColor.shared.gray
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
            filesText = "\(files) " + NSLocalizedString("_files_", comment: "") + " " + CCUtility.transformedSize(size)
        } else if files == 1 {
            filesText = "1 " + NSLocalizedString("_file_", comment: "") + " " + CCUtility.transformedSize(size)
        }

        if foldersText == "" {
            labelSection.text = filesText
        } else if filesText == "" {
            labelSection.text = foldersText
        } else {
            labelSection.text = foldersText + ", " + filesText
        }
    }

    func setTitleLabel(text: String) {

        labelSection.text = text
    }
}
