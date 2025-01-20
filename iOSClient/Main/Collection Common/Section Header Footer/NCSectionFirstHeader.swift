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
import NextcloudKit

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
    @IBOutlet weak var labelRecommendations: UILabel!
    @IBOutlet weak var imageTransfer: UIImageView!
    @IBOutlet weak var labelTransfer: UILabel!
    @IBOutlet weak var progressTransfer: UIProgressView!
    @IBOutlet weak var transferSeparatorBottom: UIView!
    @IBOutlet weak var labelSection: UILabel!

    private weak var delegate: NCSectionFirstHeaderDelegate?
    private let utility = NCUtility()
    private var markdownParser = MarkdownParser()
    private var richWorkspaceText: String?
    private let richWorkspaceGradient: CAGradientLayer = CAGradientLayer()
    private var recommendations: [tableRecommendedFiles] = []
    private var viewController: UIViewController?

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
        layout.minimumInteritemSpacing = 20

        collectionViewRecommendations.collectionViewLayout = layout
        collectionViewRecommendations.register(UINib(nibName: "NCRecommendationsCell", bundle: nil), forCellWithReuseIdentifier: "cell")
        labelRecommendations.text = NSLocalizedString("_recommended_files_", comment: "")

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

    func setContent(heightHeaderRichWorkspace: CGFloat,
                    richWorkspaceText: String?,
                    heightHeaderRecommendations: CGFloat,
                    recommendations: [tableRecommendedFiles],
                    heightHeaderTransfer: CGFloat,
                    headerTransferIsHidden: Bool,
                    heightHeaderSection: CGFloat,
                    sectionText: String?,
                    viewController: UIViewController?,
                    delegate: NCSectionFirstHeaderDelegate?) {
        viewRichWorkspaceHeightConstraint.constant = heightHeaderRichWorkspace
        viewRecommendationsHeightConstraint.constant = heightHeaderRecommendations
        viewSectionHeightConstraint.constant = heightHeaderSection

        if let richWorkspaceText, richWorkspaceText != self.richWorkspaceText {
            textViewRichWorkspace.attributedText = markdownParser.parse(richWorkspaceText)
            self.richWorkspaceText = richWorkspaceText
        }
        setRichWorkspaceColor()
        self.recommendations = recommendations
        self.labelSection.text = sectionText
        self.viewController = viewController
        self.delegate = delegate

        if heightHeaderRichWorkspace != 0, let richWorkspaceText, !richWorkspaceText.isEmpty {
            viewRichWorkspace.isHidden = false
        } else {
            viewRichWorkspace.isHidden = true
        }

        if heightHeaderRecommendations != 0 && !recommendations.isEmpty {
            viewRecommendations.isHidden = false
        } else {
            viewRecommendations.isHidden = true
        }

        setViewTransfer(isHidden: headerTransferIsHidden, height: heightHeaderTransfer)

        if heightHeaderSection == 0 {
            viewSection.isHidden = true
        } else {
            viewSection.isHidden = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.collectionViewRecommendations.reloadData()
        }
    }

    // MARK: - RichWorkspace

    private func setRichWorkspaceColor() {
        if traitCollection.userInterfaceStyle == .dark {
            richWorkspaceGradient.colors = [UIColor(white: 0, alpha: 0).cgColor, UIColor.black.cgColor]
        } else {
            richWorkspaceGradient.colors = [UIColor(white: 1, alpha: 0).cgColor, UIColor.white.cgColor]
        }
    }

    @objc func touchUpInsideViewRichWorkspace(_ sender: Any) {
        delegate?.tapRichWorkspace(sender)
    }

    // MARK: - Transfer

    func setViewTransfer(isHidden: Bool, progress: Float? = nil, height: CGFloat) {
        viewTransfer.isHidden = isHidden

        if isHidden {
            viewTransferHeightConstraint.constant = 0
            progressTransfer.progress = 0
        } else {
            viewTransferHeightConstraint.constant = height
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
}

extension NCSectionFirstHeader: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        self.recommendations.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let recommendedFiles = self.recommendations[indexPath.row]
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as? NCRecommendationsCell else { fatalError() }

        if let metadata = NCManageDatabase.shared.getResultMetadataFromFileId(recommendedFiles.id) {
            let imagePreview = self.utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: NCGlobal.shared.previewExt512)

            if metadata.directory {
                cell.image.image = self.utility.loadImage(named: metadata.iconName, useTypeIconFile: true, account: metadata.account)
                cell.image.contentMode = .scaleAspectFit
            } else if let image = imagePreview {
                cell.image.image = image
                cell.image.contentMode = .scaleToFill
            } else {
                cell.image.image = self.utility.loadImage(named: metadata.iconName, useTypeIconFile: true, account: metadata.account)
                cell.image.contentMode = .scaleAspectFit
                if recommendedFiles.hasPreview {
                    NextcloudKit.shared.downloadPreview(fileId: metadata.fileId, account: metadata.account) { _, _, _, _, responseData, error in
                        if error == .success, let data = responseData?.data {
                            self.utility.createImageFileFrom(data: data, ocId: metadata.ocId, etag: metadata.etag)
                            if let image = self.utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: NCGlobal.shared.previewExt512) {
                                for case let cell as NCRecommendationsCell in self.collectionViewRecommendations.visibleCells {
                                    if cell.id == recommendedFiles.id {
                                        cell.image.contentMode = .scaleToFill
                                        UIView.transition(with: cell.image, duration: 0.75, options: .transitionCrossDissolve, animations: {
                                            cell.image.image = image
                                        }, completion: nil)
                                        break
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if metadata.hasPreview, metadata.classFile == NKCommon.TypeClassFile.document.rawValue, imagePreview == nil {
                cell.setImageCorner(withBorder: true)
            } else {
                cell.setImageCorner(withBorder: false)
            }

            cell.labelFilename.text = metadata.fileNameView
            cell.labelInfo.text = recommendedFiles.reason

            cell.delegate = self
            cell.metadata = metadata
            cell.recommendedFiles = recommendedFiles
            cell.id = recommendedFiles.id
        }

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

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let recommendedFiles = self.recommendations[indexPath.row]
        guard let metadata = NCManageDatabase.shared.getResultMetadataFromFileId(recommendedFiles.id),
              metadata.classFile != NKCommon.TypeClassFile.url.rawValue,
              let viewController else {
            return nil
        }
        let identifier = indexPath as NSCopying
        let image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: NCGlobal().previewExt1024)

#if EXTENSION
        return nil
#else
        return UIContextMenuConfiguration(identifier: identifier, previewProvider: {
            return NCViewerProviderContextMenu(metadata: metadata, image: image)
        }, actionProvider: { _ in
            return NCContextMenu().viewMenu(ocId: metadata.ocId, viewController: viewController, image: image)
        })
#endif
    }
}

extension NCSectionFirstHeader: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cellHeight = collectionView.bounds.height

        return CGSize(width: cellHeight, height: cellHeight)
    }
}

extension NCSectionFirstHeader: NCRecommendationsCellDelegate {
    func touchUpInsideButtonMenu(with metadata: tableMetadata, image: UIImage?) {
        self.delegate?.tapRecommendationsButtonMenu(with: metadata, image: image)
    }
}
