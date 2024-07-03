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

    @IBOutlet weak var buttonTransfer: UIButton!
    @IBOutlet weak var imageButtonTransfer: UIImageView!
    @IBOutlet weak var labelTransfer: UILabel!
    @IBOutlet weak var progressTransfer: UIProgressView!
    @IBOutlet weak var transferSeparatorBottom: UIView!
    @IBOutlet weak var textViewRichWorkspace: UITextView!
    @IBOutlet weak var labelSection: UILabel!
    @IBOutlet weak var viewTransfer: UIView!
    @IBOutlet weak var viewRichWorkspace: UIView!
    @IBOutlet weak var viewSection: UIView!

    @IBOutlet weak var viewTransferHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewRichWorkspaceHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewSectionHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var transferSeparatorBottomHeightConstraint: NSLayoutConstraint!

    weak var delegate: NCSectionHeaderMenuDelegate?
    let utility = NCUtility()
    private var markdownParser = MarkdownParser()
    private var richWorkspaceText: String?
    private var textViewColor: UIColor?
    private let gradient: CAGradientLayer = CAGradientLayer()

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = .clear

        // Gradient
        gradient.startPoint = CGPoint(x: 0, y: 0.8)
        gradient.endPoint = CGPoint(x: 0, y: 0.9)
        viewRichWorkspace.layer.addSublayer(gradient)

        let tap = UITapGestureRecognizer(target: self, action: #selector(touchUpInsideViewRichWorkspace(_:)))
        tap.delegate = self
        viewRichWorkspace?.addGestureRecognizer(tap)

        markdownParser = MarkdownParser(font: UIFont.systemFont(ofSize: 15), color: NCBrandColor.shared.textColor)
        markdownParser.header.font = UIFont.systemFont(ofSize: 25)
        if let richWorkspaceText = richWorkspaceText {
            textViewRichWorkspace.attributedText = markdownParser.parse(richWorkspaceText)
        }
        textViewColor = NCBrandColor.shared.textColor

        labelSection.text = ""
        viewSectionHeightConstraint.constant = 0

        buttonTransfer.backgroundColor = .clear
        buttonTransfer.setImage(nil, for: .normal)
        buttonTransfer.layer.cornerRadius = 6
        buttonTransfer.layer.masksToBounds = true
        imageButtonTransfer.image = NCUtility().loadImage(named: "stop.circle")
        imageButtonTransfer.tintColor = .white
        labelTransfer.text = ""
        progressTransfer.progress = 0
        progressTransfer.tintColor = NCBrandColor.shared.brandElement
        progressTransfer.trackTintColor = NCBrandColor.shared.brandElement.withAlphaComponent(0.2)
        transferSeparatorBottom.backgroundColor = .separator
        transferSeparatorBottomHeightConstraint.constant = 0.5
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

    func setViewTransfer(isHidden: Bool, ocId: String? = nil, text: String? = nil, progress: Float? = nil) {
        labelTransfer.text = text
        viewTransfer.isHidden = isHidden
        progressTransfer.progress = 0

        if isHidden {
            viewTransferHeightConstraint.constant = 0
        } else {
            var image: UIImage?
            if let ocId,
               let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                image = utility.createFilePreviewImage(ocId: metadata.ocId, etag: metadata.etag, fileNameView: metadata.fileNameView, classFile: metadata.classFile, status: metadata.status, createPreviewMedia: true)?.darken()
                if image == nil {
                    image = utility.loadImage(named: metadata.iconName, useTypeIconFile: true)
                    buttonTransfer.backgroundColor = .lightGray
                } else {
                    buttonTransfer.backgroundColor = .clear
                }
            }
            viewTransferHeightConstraint.constant = NCGlobal.shared.heightHeaderTransfer
            if let progress {
                progressTransfer.progress = progress
            }
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

    @IBAction func touchUpTransfer(_ sender: Any) {
       delegate?.tapButtonTransfer(sender)
    }

    @objc func touchUpInsideViewRichWorkspace(_ sender: Any) {
        delegate?.tapRichWorkspace(sender)
    }
}

protocol NCSectionHeaderMenuDelegate: AnyObject {
    func tapButtonTransfer(_ sender: Any)
    func tapRichWorkspace(_ sender: Any)
}

// optional func
extension NCSectionHeaderMenuDelegate {
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

protocol NCSectionFooterDelegate: AnyObject {
    func tapButtonSection(_ sender: Any, metadataForSection: NCMetadataForSection?)
}

// optional func
extension NCSectionFooterDelegate {
    func tapButtonSection(_ sender: Any, metadataForSection: NCMetadataForSection?) {}
}

// https://stackoverflow.com/questions/16278463/darken-an-uiimage
public extension UIImage {

    private enum BlendMode {
        case multiply // This results in colors that are at least as dark as either of the two contributing sample colors
        case screen // This results in colors that are at least as light as either of the two contributing sample colors
    }

    // A level of zero yeilds the original image, a level of 1 results in black
    func darken(level: CGFloat = 0.5) -> UIImage? {
        return blend(mode: .multiply, level: level)
    }

    // A level of zero yeilds the original image, a level of 1 results in white
    func lighten(level: CGFloat = 0.5) -> UIImage? {
        return blend(mode: .screen, level: level)
    }

    private func blend(mode: BlendMode, level: CGFloat) -> UIImage? {
        let context = CIContext(options: nil)

        var level = level
        if level < 0 {
            level = 0
        } else if level > 1 {
            level = 1
        }

        let filterName: String
        switch mode {
        case .multiply: // As the level increases we get less white
            level = abs(level - 1.0)
            filterName = "CIMultiplyBlendMode"
        case .screen: // As the level increases we get more white
            filterName = "CIScreenBlendMode"
        }

        let blender = CIFilter(name: filterName)!
        let backgroundColor = CIColor(color: UIColor(white: level, alpha: 1))

        guard let inputImage = CIImage(image: self) else { return nil }
        blender.setValue(inputImage, forKey: kCIInputImageKey)

        guard let backgroundImageGenerator = CIFilter(name: "CIConstantColorGenerator") else { return nil }
        backgroundImageGenerator.setValue(backgroundColor, forKey: kCIInputColorKey)
        guard let backgroundImage = backgroundImageGenerator.outputImage?.cropped(to: CGRect(origin: CGPoint.zero, size: self.size)) else { return nil }
        blender.setValue(backgroundImage, forKey: kCIInputBackgroundImageKey)

        guard let blendedImage = blender.outputImage else { return nil }

        guard let cgImage = context.createCGImage(blendedImage, from: blendedImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
