//
//  NCSectionFirstHeader.swift
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

protocol NCSectionFirstHeaderDelegate: AnyObject {
    func tapRichWorkspace(_ sender: Any)
}

class NCSectionFirstHeader: UICollectionReusableView, UIGestureRecognizerDelegate {
    @IBOutlet weak var viewRichWorkspace: UIView!
    @IBOutlet weak var viewRecommendation: UIView!
    @IBOutlet weak var viewTransfer: UIView!
    @IBOutlet weak var viewSection: UIView!

    @IBOutlet weak var viewRichWorkspaceHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewRecommendationHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewTransferHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewSectionHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var transferSeparatorBottomHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var textViewRichWorkspace: UITextView!
    @IBOutlet weak var collectionViewRecommendation: UICollectionView!
    @IBOutlet weak var imageTransfer: UIImageView!
    @IBOutlet weak var labelTransfer: UILabel!
    @IBOutlet weak var progressTransfer: UIProgressView!
    @IBOutlet weak var transferSeparatorBottom: UIView!
    @IBOutlet weak var labelSection: UILabel!

    weak var delegate: NCSectionFirstHeaderDelegate?
    let utility = NCUtility()
    private var markdownParser = MarkdownParser()
    private var richWorkspaceText: String?
    private let richWorkspaceGradient: CAGradientLayer = CAGradientLayer()

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = .clear

        //
        // RichWorkspace
        //
        richWorkspaceGradient.startPoint = CGPoint(x: 0, y: 0.8)
        richWorkspaceGradient.endPoint = CGPoint(x: 0, y: 0.9)
        viewRichWorkspace.layer.addSublayer(richWorkspaceGradient)

        let tap = UITapGestureRecognizer(target: self, action: #selector(touchUpInsideViewRichWorkspace(_:)))
        tap.delegate = self
        viewRichWorkspace?.addGestureRecognizer(tap)

        markdownParser = MarkdownParser(font: UIFont.systemFont(ofSize: 15), color: NCBrandColor.shared.textColor)
        markdownParser.header.font = UIFont.systemFont(ofSize: 25)
        if let richWorkspaceText = richWorkspaceText {
            textViewRichWorkspace.attributedText = markdownParser.parse(richWorkspaceText)
        }

        //
        // Recommendation
        //
        viewRecommendationHeightConstraint.constant = 0

        //
        // Transfer
        //
        imageTransfer.tintColor = NCBrandColor.shared.iconImageColor
        imageTransfer.image = NCUtility().loadImage(named: "icloud.and.arrow.up")

        progressTransfer.progress = 0
        progressTransfer.tintColor = NCBrandColor.shared.iconImageColor
        progressTransfer.trackTintColor = NCBrandColor.shared.customer.withAlphaComponent(0.2)

        transferSeparatorBottom.backgroundColor = .separator
        transferSeparatorBottomHeightConstraint.constant = 0.5

        //
        // Section
        //
        labelSection.text = ""
        viewSectionHeightConstraint.constant = 0
    }

    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)

        richWorkspaceGradient.frame = viewRichWorkspace.bounds
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
            richWorkspaceGradient.colors = [UIColor(white: 0, alpha: 0).cgColor, UIColor.black.cgColor]
        } else {
            richWorkspaceGradient.colors = [UIColor(white: 1, alpha: 0).cgColor, UIColor.white.cgColor]
        }
    }

    func setRichWorkspaceText(_ text: String?) {
        guard let text = text else { return }

        if text != self.richWorkspaceText {
            textViewRichWorkspace.attributedText = markdownParser.parse(text)
            self.richWorkspaceText = text
        }
    }

    @objc func touchUpInsideViewRichWorkspace(_ sender: Any) {
        delegate?.tapRichWorkspace(sender)
    }

    // MARK: - Recommendation

    func setRecommendationHeight(_ size: CGFloat) {
        viewRecommendationHeightConstraint.constant = size

        if size == 0 {
            viewRecommendation.isHidden = true
        } else {
            viewRecommendation.isHidden = false
        }
    }

    // MARK: - Transfer

    func setViewTransfer(isHidden: Bool, progress: Float? = nil) {
        viewTransfer.isHidden = isHidden

        if isHidden {
            viewTransferHeightConstraint.constant = 0
            progressTransfer.progress = 0
        } else {
            viewTransferHeightConstraint.constant = NCGlobal.shared.heightHeaderTransfer
            if NCTransferProgress.shared.haveUploadInForeground() {
                labelTransfer.text = String(format: NSLocalizedString("_upload_foreground_msg_", comment: ""), NCBrandOptions.shared.brand)
                if let progress {
                    progressTransfer.progress = progress
                } else if let progress = NCTransferProgress.shared.getLastTransferProgressInForeground() {
                    progressTransfer.progress = progress
                } else {
                    progressTransfer.progress = 0.0
                }
            } else {
                labelTransfer.text = NSLocalizedString("_upload_background_msg_", comment: "")
                progressTransfer.progress = 0.0
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
}
