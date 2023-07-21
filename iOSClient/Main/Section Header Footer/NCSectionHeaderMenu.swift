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
    @IBOutlet weak var buttonTransfer: UIButton!
    @IBOutlet weak var labelTransfer: UILabel!
    @IBOutlet weak var progressTransfer: UIProgressView!
    @IBOutlet weak var textViewRichWorkspace: UITextView!
    @IBOutlet weak var labelSection: UILabel!
    @IBOutlet weak var viewTransfer: UIView!
    @IBOutlet weak var viewButtonsView: UIView!
    @IBOutlet weak var viewSeparator: UIView!
    @IBOutlet weak var viewRichWorkspace: UIView!
    @IBOutlet weak var viewSection: UIView!
    @IBOutlet weak var viewTransferHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewButtonsViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewSeparatorHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewRichWorkspaceHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewSectionHeightConstraint: NSLayoutConstraint!

    weak var delegate: NCSectionHeaderMenuDelegate?

    private var markdownParser = MarkdownParser()
    private var richWorkspaceText: String?
    private var textViewColor: UIColor?
    private let gradient: CAGradientLayer = CAGradientLayer()

    var ocIdTransfer: String?

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = .clear

        buttonSwitch.setImage(UIImage(systemName: "list.bullet")!.image(color: .systemGray, size: 25), for: .normal)

        buttonOrder.setTitle("", for: .normal)
        buttonOrder.setTitleColor(.systemBlue, for: .normal)
        buttonMore.setImage(UIImage(named: "more")!.image(color: .systemGray, size: 25), for: .normal)

        // Gradient
        gradient.startPoint = CGPoint(x: 0, y: 0.50)
        gradient.endPoint = CGPoint(x: 0, y: 1)
        viewRichWorkspace.layer.addSublayer(gradient)

        let tap = UITapGestureRecognizer(target: self, action: #selector(touchUpInsideViewRichWorkspace(_:)))
        tap.delegate = self
        viewRichWorkspace?.addGestureRecognizer(tap)

        viewSeparatorHeightConstraint.constant = 0.5
        viewSeparator.backgroundColor = .separator

        markdownParser = MarkdownParser(font: UIFont.systemFont(ofSize: 15), color: .label)
        markdownParser.header.font = UIFont.systemFont(ofSize: 25)
        if let richWorkspaceText = richWorkspaceText {
            textViewRichWorkspace.attributedText = markdownParser.parse(richWorkspaceText)
        }
        textViewColor = .label

        labelSection.text = ""
        viewSectionHeightConstraint.constant = 0

        buttonTransfer.setImage(nil, for: .normal)
        labelTransfer.text = ""
        progressTransfer.tintColor = NCBrandColor.shared.brandElement
        progressTransfer.transform = CGAffineTransform(scaleX: 1.0, y: 0.7)
        progressTransfer.trackTintColor = .clear
    }

    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)

        gradient.frame = viewRichWorkspace.bounds
        setInterfaceColor()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        setInterfaceColor()
    }

    // MARK: - View

    func setStatusButtonsView(enable: Bool) {

        buttonSwitch.isEnabled = enable
        buttonOrder.isEnabled = enable
        buttonMore.isEnabled = enable
    }

    func buttonMoreIsHidden(_ isHidden: Bool) {

        buttonMore.isHidden = isHidden
    }

    func setImageSwitchList() {

        buttonSwitch.setImage(UIImage(systemName: "list.bullet")!.image(color: .systemGray, width: 20, height: 15), for: .normal)
    }

    func setImageSwitchGrid() {

        buttonSwitch.setImage(UIImage(systemName: "square.grid.2x2")!.image(color: .systemGray, size: 20), for: .normal)
    }

    func setButtonsView(height: CGFloat) {

        viewButtonsViewHeightConstraint.constant = height
        if height == 0 {
            viewButtonsView.isHidden = true
        } else {
            viewButtonsView.isHidden = false
        }
    }

    func setSortedTitle(_ title: String) {

        let title = NSLocalizedString(title, comment: "")
        buttonOrder.setTitle(title, for: .normal)
    }

    // MARK: - RichWorkspace

    func setRichWorkspaceHeight(_ size: CGFloat) {

        viewRichWorkspaceHeightConstraint.constant = size
        if size == 0 {
            viewRichWorkspace.isHidden = true
        } else {
            viewRichWorkspace.isHidden = false
        }
    }

    func setInterfaceColor() {

        if traitCollection.userInterfaceStyle == .dark {
            gradient.colors = [UIColor(white: 0, alpha: 0).cgColor, UIColor.black.cgColor]
        } else {
            gradient.colors = [UIColor(white: 1, alpha: 0).cgColor, UIColor.white.cgColor]
        }
    }

    func setRichWorkspaceText(_ text: String?) {
        guard let text = text else { return }

        if text != self.richWorkspaceText {
            textViewRichWorkspace.attributedText = markdownParser.parse(text)
            self.richWorkspaceText = text
        }
    }

    // MARK: - Transfer

    func setTransfer(isHidden: Bool, image: UIImage? = nil, text: String? = nil, ocId: String?) {

        buttonTransfer.setImage(image, for: .normal)
        labelTransfer.text = text
        viewTransfer.isHidden = isHidden
        ocIdTransfer = ocId

        if isHidden {
            viewTransferHeightConstraint.constant = 0
        } else {
            viewTransferHeightConstraint.constant = NCGlobal.shared.heightHeaderTransfer
        }
    }

    // MARK: - Section

    func setSectionHeight(_ size: CGFloat) {

        viewSectionHeightConstraint.constant = size
        if size == 0 {
            viewSection.isHidden = true
        } else {
            viewSection.isHidden = false
        }
    }

    // MARK: - Action

    @IBAction func touchUpInsideSwitch(_ sender: Any) {
        delegate?.tapButtonSwitch(sender)
    }

    @IBAction func touchUpInsideOrder(_ sender: Any) {
        delegate?.tapButtonOrder(sender)
    }

    @IBAction func touchUpInsideMore(_ sender: Any) {
        delegate?.tapButtonMore(sender)
    }

    @IBAction func touchUpTransfer(_ sender: Any) {
       delegate?.tapButtonTransfer(sender)
    }

    @objc func touchUpInsideViewRichWorkspace(_ sender: Any) {
        delegate?.tapRichWorkspace(sender)
    }
}

protocol NCSectionHeaderMenuDelegate: AnyObject {
    func tapButtonSwitch(_ sender: Any)
    func tapButtonOrder(_ sender: Any)
    func tapButtonMore(_ sender: Any)
    func tapButtonTransfer(_ sender: Any)
    func tapRichWorkspace(_ sender: Any)
}

// optional func
extension NCSectionHeaderMenuDelegate {
    func tapButtonSwitch(_ sender: Any) {}
    func tapButtonOrder(_ sender: Any) {}
    func tapButtonMore(_ sender: Any) {}
    func tapButtonTransfer(_ sender: Any) {}
    func tapRichWorkspace(_ sender: Any) {}
}

class NCSectionHeader: UICollectionReusableView {

    @IBOutlet weak var labelSection: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        self.backgroundColor = UIColor.clear
        self.labelSection.text = ""
    }
}

class NCSectionFooter: UICollectionReusableView, NCSectionFooterDelegate {

    @IBOutlet weak var buttonSection: UIButton!
    @IBOutlet weak var activityIndicatorSection: UIActivityIndicatorView!
    @IBOutlet weak var labelSection: UILabel!
    @IBOutlet weak var separator: UIView!
    @IBOutlet weak var separatorHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var buttonSectionHeightConstraint: NSLayoutConstraint!

    weak var delegate: NCSectionFooterDelegate?
    var metadataForSection: NCMetadataForSection?

    override func awakeFromNib() {
        super.awakeFromNib()

        self.backgroundColor = UIColor.clear
        labelSection.textColor = UIColor.systemGray
        labelSection.text = ""

        separator.backgroundColor = .separator
        separatorHeightConstraint.constant = 0.5

        buttonIsHidden(true)
        activityIndicatorSection.isHidden = true
        activityIndicatorSection.color = .label
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

        if foldersText.isEmpty {
            labelSection.text = filesText
        } else if filesText.isEmpty {
            labelSection.text = foldersText
        } else {
            labelSection.text = foldersText + ", " + filesText
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

protocol NCSectionFooterDelegate: AnyObject {
    func tapButtonSection(_ sender: Any, metadataForSection: NCMetadataForSection?)
}

// optional func
extension NCSectionFooterDelegate {
    func tapButtonSection(_ sender: Any, metadataForSection: NCMetadataForSection?) {}
}
