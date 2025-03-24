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
    @IBOutlet weak var viewSection: UIView!

    @IBOutlet weak var viewRichWorkspaceHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewRecommendationsHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewSectionHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var textViewRichWorkspace: UITextView!
    @IBOutlet weak var collectionViewRecommendations: UICollectionView!
    @IBOutlet weak var labelRecommendations: UILabel!
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
        layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        layout.scrollDirection = .horizontal

        collectionViewRecommendations.collectionViewLayout = layout
        collectionViewRecommendations.register(UINib(nibName: "NCRecommendationsCell", bundle: nil), forCellWithReuseIdentifier: "cell")
        labelRecommendations.text = NSLocalizedString("_recommended_files_", comment: "")

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

        if heightHeaderSection == 0 {
            viewSection.isHidden = true
        } else {
            viewSection.isHidden = false
        }

        self.collectionViewRecommendations.reloadData()
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
}

extension NCSectionFirstHeader: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        self.recommendations.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let recommendedFiles = self.recommendations[indexPath.row]
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as? NCRecommendationsCell else { fatalError() }

        if let metadata = NCManageDatabase.shared.getMetadataFromFileId(recommendedFiles.id) {
            let imagePreview = self.utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: NCGlobal.shared.previewExt512)

            if metadata.directory {
                cell.image.image = self.utility.loadImage(named: metadata.iconName, useTypeIconFile: true, account: metadata.account)
                cell.image.contentMode = .scaleAspectFit
            } else if let image = imagePreview {
                cell.image.image = image
                cell.image.contentMode = .scaleAspectFill
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
                                        cell.image.contentMode = .scaleAspectFill
                                        if metadata.classFile == NKCommon.TypeClassFile.document.rawValue {
                                            cell.setImageCorner(withBorder: true)
                                        }
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

            if metadata.hasPreview, metadata.classFile == NKCommon.TypeClassFile.document.rawValue, imagePreview != nil {
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
        guard let metadata = NCManageDatabase.shared.getMetadataFromFileId(recommendedFiles.id) else {
            return
        }

        self.delegate?.tapRecommendations(with: metadata)
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let recommendedFiles = self.recommendations[indexPath.row]
        guard let metadata = NCManageDatabase.shared.getMetadataFromFileId(recommendedFiles.id),
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
        let cellHeight = collectionView.bounds.height - 20

        return CGSize(width: cellHeight, height: cellHeight)
    }
}

extension NCSectionFirstHeader: NCRecommendationsCellDelegate {
    func touchUpInsideButtonMenu(with metadata: tableMetadata, image: UIImage?) {
        self.delegate?.tapRecommendationsButtonMenu(with: metadata, image: image)
    }
}
