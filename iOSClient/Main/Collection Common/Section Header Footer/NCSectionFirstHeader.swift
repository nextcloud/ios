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
    func tapRecommendations(with metadata: tableMetadata)
    func tapRecommendationsButtonMenu(with metadata: tableMetadata, image: UIImage?)
}

class NCSectionFirstHeader: UICollectionReusableView, UIGestureRecognizerDelegate {
    @IBOutlet weak var viewRichWorkspace: UIView!
    @IBOutlet weak var viewRecommendations: UIView!
    @IBOutlet weak var viewTransfer: UIView!
    @IBOutlet weak var viewSection: UIView!

    @IBOutlet weak var viewRichWorkspaceHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewRecommendationsHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewTransferHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewSectionHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var transferSeparatorBottomHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var textViewRichWorkspace: UITextView!
    @IBOutlet weak var collectionViewRecommendations: UICollectionView!
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
    private var recommendations: [tableRecommendedFiles] = []

    override func awakeFromNib() {
        super.awakeFromNib()

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
        // Recommendations
        //
        viewRecommendationsHeightConstraint.constant = 0
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        collectionViewRecommendations.collectionViewLayout = layout
        collectionViewRecommendations.register(UINib(nibName: "NCRecommendationsCell", bundle: nil), forCellWithReuseIdentifier: "cell")

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
        setRichWorkspaceColor()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        setRichWorkspaceColor()
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

    private func setRichWorkspaceColor() {
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

    func setRecommendations(size: CGFloat, recommendations: [tableRecommendedFiles]) {
        viewRecommendationsHeightConstraint.constant = size
        self.recommendations = recommendations

        if size == 0 {
            viewRecommendations.isHidden = true
        } else {
            viewRecommendations.isHidden = false
        }

        collectionViewRecommendations.reloadData()
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

extension NCSectionFirstHeader: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        self.recommendations.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let recommendedFiles = self.recommendations[indexPath.row]
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as? NCRecommendationsCell,
              let metadata = NCManageDatabase.shared.getResultMetadataFromFileId(recommendedFiles.id) else { fatalError() }

        var image = self.utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: NCGlobal.shared.previewExt512)

        if image == nil {
            cell.image.contentMode = .scaleAspectFit
            if metadata.iconName.isEmpty {
               image = NCImageCache.shared.getImageFile()
            } else {
                image = self.utility.loadImage(named: metadata.iconName, useTypeIconFile: true, account: metadata.account)
            }
        } else {
            cell.image.contentMode = .scaleToFill
        }

        cell.image.image = image
        cell.labelFilename.text = recommendedFiles.name
        cell.labelInfo.text = recommendedFiles.reason

        cell.delegate = self
        cell.metadata = metadata
        cell.recommendedFiles = recommendedFiles

        return cell
    }
}

extension NCSectionFirstHeader: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let recommendedFiles = self.recommendations[indexPath.row]
        guard let metadata = NCManageDatabase.shared.getResultMetadataFromFileId(recommendedFiles.id) else {
            return
        }

        self.delegate?.tapRecommendations(with: metadata)
    }
}

extension NCSectionFirstHeader: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: NCGlobal.shared.heightHeaderRecommendations + 25, height: NCGlobal.shared.heightHeaderRecommendations)
    }
}

extension NCSectionFirstHeader: NCRecommendationsCellDelegate {
    func touchUpInsideButtonMenu(with metadata: tableMetadata, image: UIImage?) {
        self.delegate?.tapRecommendationsButtonMenu(with: metadata, image: image)
    }
}
