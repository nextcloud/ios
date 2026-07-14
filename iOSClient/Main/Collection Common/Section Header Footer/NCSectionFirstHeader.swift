// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import MarkdownKit
import NextcloudKit

protocol NCSectionFirstHeaderDelegate: AnyObject {
    func tapRichWorkspace(_ sender: Any)
    func tapRecommendations(with metadata: tableMetadata, viewerTransitionSource: NCMediaViewerTransitionSource?)
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
    private let global = NCGlobal.shared
    private var richWorkspaceText: String?
    private let richWorkspaceGradient: CAGradientLayer = CAGradientLayer()
    private var recommendations: [tableRecommendedFiles] = []
    private var viewController: UIViewController?
    private var sceneIdentifier: String = ""
    private var recommendationsIdentity: [String] = []

#if !EXTENSION
    @MainActor
    internal var controller: NCMainTabBarController? {
        viewController?.tabBarController as? NCMainTabBarController
    }
#endif

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

    func setContent(heightHeaderRichWorkspace: CGFloat,
                    richWorkspaceText: String?,
                    heightHeaderRecommendations: CGFloat,
                    recommendations: [tableRecommendedFiles],
                    heightHeaderSection: CGFloat,
                    sectionText: String?,
                    viewController: UIViewController?,
                    sceneItentifier: String,
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
        self.sceneIdentifier = sceneItentifier
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

#if EXTENSION
        self.collectionViewRecommendations.reloadData()
#else
        Task { [weak self] in
            guard let self else { return }

            let isPause = await (viewController as? NCCollectionViewCommon)?
                .debouncerReloadDataSource
                .isPausedNow() ?? false

            guard !isPause else {
                return
            }

            let fileIds = recommendations.map(\.id)
            let metadatas = await NCManageDatabase.shared.getMetadatasFromFileIdsAsync(fileIds)
            let etagsByFileId = Dictionary(
                metadatas.map { ($0.fileId, $0.etag) },
                uniquingKeysWith: { current, _ in current }
            )
            let newRecommendationsIdentity = recommendations.map {
                "\($0.id)|\($0.reason)|\(etagsByFileId[$0.id] ?? "")"
            }

            guard self.recommendationsIdentity != newRecommendationsIdentity else {
                return
            }

            self.recommendationsIdentity = newRecommendationsIdentity
            self.collectionViewRecommendations.reloadData()
        }
#endif
    }

    // MARK: - RichWorkspace

    func setRichWorkspaceColor(style: UIUserInterfaceStyle? = nil) {
        if let style {
            richWorkspaceGradient.colors = style == .light ? [UIColor(white: 1, alpha: 0).cgColor, UIColor.white.cgColor] : [UIColor(white: 0, alpha: 0).cgColor, UIColor.black.cgColor]
        } else {
            richWorkspaceGradient.colors = traitCollection.userInterfaceStyle == .light ? [UIColor(white: 1, alpha: 0).cgColor, UIColor.white.cgColor] : [UIColor(white: 0, alpha: 0).cgColor, UIColor.black.cgColor]
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
        let recommendedFile = self.recommendations[indexPath.row]
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "cell",
            for: indexPath
        ) as? NCRecommendationsCell else {
            fatalError("Unable to dequeue NCRecommendationsCell")
        }

        cell.representedFileId = recommendedFile.id
        cell.labelInfo.text = recommendedFile.reason
        cell.delegate = self
        cell.image.image = nil
        cell.image.contentMode = .scaleAspectFit
        cell.setImageCorner(withBorder: false)

        let fileId = recommendedFile.id

        Task { [weak self, weak cell] in
            guard let self,
                  let metadata = await NCManageDatabase.shared.getMetadataFromFileIdAsync(fileId),
                  !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard let cell,
                      cell.representedFileId == fileId else {
                    return
                }

                cell.metadata = metadata
                cell.setBidiSafeFilename(
                    metadata.fileNameView,
                    isDirectory: metadata.directory,
                    titleLabel: cell.labelFilename,
                    extensionLabel: cell.labelExtensionFilename
                )

                let hasDocumentPreview = metadata.hasPreview &&
                metadata.classFile == NKTypeClassFile.document.rawValue

                cell.setImageCorner(withBorder: hasDocumentPreview)
            }

            if metadata.directory {
                let icon = self.utility.loadImage(
                    named: metadata.iconName,
                    useTypeIconFile: true,
                    account: metadata.account
                )

                await MainActor.run {
                    guard let cell,
                          cell.representedFileId == fileId else {
                        return
                    }

                    cell.image.image = icon
                    cell.image.contentMode = .scaleAspectFit
                }

                return
            }

            if let image = self.utility.getImage(
                ocId: metadata.ocId,
                etag: metadata.etag,
                ext: self.global.previewExt512,
                userId: metadata.userId,
                urlBase: metadata.urlBase
            ) {
                await MainActor.run {
                    guard let cell,
                          cell.representedFileId == fileId else {
                        return
                    }

                    cell.image.image = image
                    cell.image.contentMode = .scaleAspectFill
                }

                return
            }

            let icon = self.utility.loadImage(
                named: metadata.iconName,
                useTypeIconFile: true,
                account: metadata.account
            )

            await MainActor.run {
                guard let cell,
                      cell.representedFileId == fileId else {
                    return
                }

                cell.image.image = icon
                cell.image.contentMode = .scaleAspectFit
            }

            let result = await NextcloudKit.shared.downloadPreviewAsync(
                fileId: fileId,
                etag: metadata.etag,
                account: metadata.account
            )

            guard result.error == .success,
                  let data = result.responseData?.data,
                  let image = NCUtility().createImageFileFrom(
                    data: data,
                    ocId: metadata.ocId,
                    etag: metadata.etag,
                    ext: self.global.previewExt512,
                    userId: metadata.userId,
                    urlBase: metadata.urlBase
                  ) else {
                return
            }

            await MainActor.run {
                guard let cell,
                      cell.representedFileId == fileId else {
                    return
                }

                cell.image.contentMode = .scaleAspectFill

                if metadata.classFile == NKTypeClassFile.document.rawValue {
                    cell.setImageCorner(withBorder: true)
                }

                UIView.transition(
                    with: cell.image,
                    duration: 0.25,
                    options: .transitionCrossDissolve
                ) {
                    cell.image.image = image
                }
            }
        }

        return cell
    }
}

extension NCSectionFirstHeader: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let recommendedFiles = self.recommendations[indexPath.row]
        guard let metadata = NCManageDatabase.shared.getMetadataFromFileId(recommendedFiles.id),
            let cell = collectionView.cellForItem(at: indexPath) as? NCRecommendationsCell else {
            return
        }
        let viewerTransitionSource = cell.viewerTransitionSource()

        self.delegate?.tapRecommendations(with: metadata, viewerTransitionSource: viewerTransitionSource)
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let recommendedFiles = self.recommendations[indexPath.row]
        guard let metadata = NCManageDatabase.shared.getMetadataFromFileId(recommendedFiles.id),
              metadata.classFile != NKTypeClassFile.url.rawValue,
              let viewController else {
            return nil
        }
        let identifier = indexPath as NSCopying
        let image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: NCGlobal().previewExt1024, userId: metadata.userId, urlBase: metadata.urlBase)

#if EXTENSION
        return nil
#else
        return UIContextMenuConfiguration(identifier: identifier, previewProvider: {
            return NCViewerProviderContextMenu(metadata: metadata, image: image, sceneIdentifier: self.sceneIdentifier)
        }, actionProvider: { _ in
            let cell = collectionView.cellForItem(at: indexPath)
            let contextMenu = NCContextMenuMain(metadata: metadata.detachedCopy(), viewController: viewController, controller: self.controller, sender: cell)
            return contextMenu.viewMenu()
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
    func openContextMenu(with metadata: tableMetadata?, button: UIButton, sender: Any) {
#if !EXTENSION
        Task {
            guard let viewController = self.viewController, let metadata else {
                return
            }
            button.menu = NCContextMenuMain(metadata: metadata, viewController: viewController, controller: self.controller, sender: sender).viewMenu()
        }
#endif
    }

    func onMenuIntent(with metadata: tableMetadata?) {
#if !EXTENSION
        Task {
            let collectionViewCommon = (self.viewController as? NCCollectionViewCommon)
            await collectionViewCommon?.debouncerReloadData.pause()
        }
#endif
    }
}
