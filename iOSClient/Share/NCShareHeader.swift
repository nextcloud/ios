//
//  NCShareHeader.swift
//  Nextcloud
//
//  Created by T-systems on 10/08/21.
//  Copyright © 2022 Henrik Storch. All rights reserved.
//
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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
import TagListView
import SwiftUI
import NextcloudKit

class NCShareHeader: UIView {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var fileName: UILabel!
    @IBOutlet weak var fileNameExtension: UILabel!
    @IBOutlet weak var info: UILabel!
    @IBOutlet weak var fullWidthImageView: UIImageView!
    @IBOutlet weak var fileNameTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var tagListView: TagListView!

    private var metadata = tableMetadata()

    private var heightConstraintWithImage: NSLayoutConstraint?
    private var heightConstraintWithoutImage: NSLayoutConstraint?

    func setupUI(with metadata: tableMetadata) {
        self.metadata = metadata.detachedCopy()
        let utilityFileSystem = NCUtilityFileSystem()
        if let image = NCUtility().getImage(ocId: metadata.ocId, etag: metadata.etag, ext: NCGlobal.shared.previewExt1024, userId: metadata.userId, urlBase: metadata.urlBase) {
            fullWidthImageView.image = image
            fullWidthImageView.contentMode = .scaleAspectFill
            imageView.image = fullWidthImageView.image
            imageView.isHidden = true
        } else {
            if metadata.directory {
                imageView.image = metadata.e2eEncrypted ? NCImageCache.shared.getFolderEncrypted(account: metadata.account) : NCImageCache.shared.getFolder(account: metadata.account)
            } else if !metadata.iconName.isEmpty {
                imageView.image = NCUtility().loadImage(named: metadata.iconName, useTypeIconFile: true, account: metadata.account)
            } else {
                imageView.image = NCImageCache.shared.getImageFile()
            }

            fileNameTopConstraint.constant -= 45
        }

        fileName?.numberOfLines = 1
        fileNameExtension?.numberOfLines = 1
        setBidiSafeFilename(metadata.fileNameView, isDirectory: metadata.directory, titleLabel: fileName, extensionLabel: fileNameExtension)

        fileName.textColor = NCBrandColor.shared.textColor
        fileNameExtension?.textColor = NCBrandColor.shared.textColor
        info.textColor = NCBrandColor.shared.textColor2
        info.text = utilityFileSystem.transformedSize(metadata.size) + ", " + NCUtility().getRelativeDateTitle(metadata.date as Date)

        tagListView.marginY = 8
        refreshTags(metadata.tagNames, tagModels: metadata.tags.map(\.nkTag))

        setNeedsLayout()
        layoutIfNeeded()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if fullWidthImageView.image != nil {
            imageView.isHidden = traitCollection.verticalSizeClass != .compact
        }
    }

    func presentTagEditor(from sourceViewController: UIViewController, onApplied: (([NKTag]) -> Void)? = nil) {
        let editor = NCTagEditorView(
            metadata: metadata.detachedCopy(),
            windowScene: sourceViewController.view.window?.windowScene,
            onApplied: { [weak self] tags in
                guard let self else { return }
                self.metadata.tags.removeAll()
                self.metadata.tags.append(objectsIn: tags, account: self.metadata.account)
                self.refreshTags(tags.map(\.name), tagModels: tags)
                onApplied?(tags)
            }
        )

        let hosting = UIHostingController(rootView: editor)
        hosting.title = NSLocalizedString("_tags_", comment: "")
        hosting.isModalInPresentation = true

        if let sheet = hosting.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.selectedDetentIdentifier = .medium
            sheet.prefersGrabberVisible = true
        }

        sourceViewController.present(hosting, animated: true)
    }

    private func refreshTags(_ tags: [String], tagModels: [NKTag]? = nil) {
        let tagModels = tagModels ?? []

        tagListView.removeAllTags()

        for tagName in tags {
            let matchedTag = tagModels.first { $0.name == tagName }
            let displayName = matchedTag?.name ?? tagName
            let tagView = tagListView.addTag(displayName)

            if let colorHex = matchedTag?.color, let color = UIColor(hex: colorHex) {
                tagView.tagBackgroundColor = .clear
                tagView.borderColor = color
                tagView.textColor = color
                tagView.selectedTextColor = color
            } else {
                tagView.tagBackgroundColor = .clear
                tagView.borderColor = .systemGray
                tagView.textColor = .systemGray
                tagView.selectedTextColor = .systemGray
            }

            tagView.textFont = UIFont.boldSystemFont(ofSize: 12)
        }
    }

}
