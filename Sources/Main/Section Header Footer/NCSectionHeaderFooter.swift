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

    @IBOutlet weak var button1: UIButton!
    @IBOutlet weak var button2: UIButton!
    @IBOutlet weak var button3: UIButton!

    @IBOutlet weak var viewButtonsCommand: UIView!
    @IBOutlet weak var viewButtonsView: UIView!
    @IBOutlet weak var viewSeparator: UIView!
    @IBOutlet weak var viewRichWorkspace: UIView!
    @IBOutlet weak var viewSection: UIView!

    @IBOutlet weak var viewButtonsCommandHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewButtonsViewHeightConstraint: NSLayoutConstraint!
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

        buttonSwitch.setImage(UIImage(named: "switchList")!.image(color: .systemGray, size: 25), for: .normal)

        buttonOrder.setTitle("", for: .normal)
        buttonOrder.setTitleColor(.systemBlue, for: .normal)
        buttonMore.setImage(UIImage(named: "more")!.image(color: .systemGray, size: 25), for: .normal)

        button1.setImage(nil, for: .normal)
        button1.isHidden = true
        button1.backgroundColor = .clear
        button1.setTitleColor(.systemBlue, for: .normal)
        button1.layer.borderColor = UIColor.systemGray.cgColor
        button1.layer.borderWidth = 0.4
        button1.layer.cornerRadius = 3

        button2.setImage(nil, for: .normal)
        button2.isHidden = true
        button2.backgroundColor = .clear
        button2.setTitleColor(.systemBlue, for: .normal)
        button2.layer.borderColor = UIColor.systemGray.cgColor
        button2.layer.borderWidth = 0.4
        button2.layer.cornerRadius = 3

        button3.setImage(nil, for: .normal)
        button3.isHidden = true
        button3.backgroundColor = .clear
        button3.setTitleColor(.systemBlue, for: .normal)
        button3.layer.borderColor = UIColor.systemGray.cgColor
        button3.layer.borderWidth = 0.4
        button3.layer.cornerRadius = 3

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

    //MARK: - Command

    func setStatusButtonsCommand(enable: Bool) {

        button1.isEnabled = enable
        button2.isEnabled = enable
        button3.isEnabled = enable
    }

    func setButtonsCommand(heigt :CGFloat, imageButton1: UIImage? = nil, titleButton1: String? = nil, imageButton2: UIImage? = nil, titleButton2: String? = nil, imageButton3: UIImage? = nil, titleButton3: String? = nil) {

        viewButtonsCommandHeightConstraint.constant = heigt
        if heigt == 0 {
            viewButtonsView.isHidden = true
            button1.isHidden = true
            button2.isHidden = true
            button3.isHidden = true
        } else {
            viewButtonsView.isHidden = false
            if var image = imageButton1, let title = titleButton1 {
                image = image.image(color: .systemGray, size: 25)
                button1.setImage(image, for: .normal)
                button1.isHidden = false
                button1.setTitle(title.firstUppercased, for: .normal)
            }
            if var image = imageButton2, let title = titleButton2 {
                image = image.image(color: .systemGray, size: 25)
                button2.setImage(image, for: .normal)
                button2.isHidden = false
                button2.setTitle(title.firstUppercased, for: .normal)
            }
            if var image = imageButton3, let title = titleButton3 {
                image = image.image(color: .systemGray, size: 25)
                button3.setImage(image, for: .normal)
                button3.isHidden = false
                button3.setTitle(title.firstUppercased, for: .normal)
            }
        }
    }

    //MARK: - View

    func setStatusButtonsView(enable: Bool) {

        buttonSwitch.isEnabled = enable
        buttonOrder.isEnabled = enable
        buttonMore.isEnabled = enable
    }

    func buttonMoreIsHidden(_ isHidden: Bool) {

        buttonMore.isHidden = isHidden
    }

    func setImageSwitchList() {

        buttonSwitch.setImage(UIImage(named: "switchList")!.image(color: .systemGray, size: 50), for: .normal)
    }

    func setImageSwitchGrid() {

        buttonSwitch.setImage(UIImage(named: "switchGrid")!.image(color: .systemGray, size: 50), for: .normal)
    }

    func setButtonsView(heigt :CGFloat) {

        viewButtonsViewHeightConstraint.constant = heigt
        if heigt == 0 {
            viewButtonsView.isHidden = true
        } else {
            viewButtonsView.isHidden = false
        }
    }

    func setSortedTitle(_ title: String) {

        let title = NSLocalizedString(title, comment: "")
        //let size = title.size(withAttributes: [.font: buttonOrder.titleLabel?.font as Any])

        buttonOrder.setTitle(title, for: .normal)
    }

    //MARK: - RichWorkspace

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

    //MARK: - Section

    func setSectionHeight(_ size:CGFloat) {

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

    @IBAction func touchUpInsideButton1(_ sender: Any) {
       delegate?.tapButton1(sender)
    }

    @IBAction func touchUpInsideButton2(_ sender: Any) {
        delegate?.tapButton2(sender)
    }

    @IBAction func touchUpInsideButton3(_ sender: Any) {
        delegate?.tapButton3(sender)
    }

    @objc func touchUpInsideViewRichWorkspace(_ sender: Any) {
        delegate?.tapRichWorkspace(sender)
    }
}

protocol NCSectionHeaderMenuDelegate: AnyObject {
    func tapButtonSwitch(_ sender: Any)
    func tapButtonOrder(_ sender: Any)
    func tapButtonMore(_ sender: Any)
    func tapButton1(_ sender: Any)
    func tapButton2(_ sender: Any)
    func tapButton3(_ sender: Any)
    func tapRichWorkspace(_ sender: Any)
}

// optional func
extension NCSectionHeaderMenuDelegate {
    func tapButtonSwitch(_ sender: Any) {}
    func tapButtonOrder(_ sender: Any) {}
    func tapButtonMore(_ sender: Any) {}
    func tapButton1(_ sender: Any) {}
    func tapButton2(_ sender: Any) {}
    func tapButton3(_ sender: Any) {}
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

        if foldersText == "" {
            labelSection.text = filesText
        } else if filesText == "" {
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
