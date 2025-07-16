//
//  NCMedia+Command.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 24/02/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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

import Foundation
import UIKit
import NextcloudKit
import SwiftUI

extension NCMedia {
    @IBAction func selectOrCancelButtonPressed(_ sender: UIButton) {
        isEditMode = !isEditMode
        setSelectcancelButton()
    }

    @IBAction func assistantButtonPressed(_ sender: UIButton) {
        let assistant = NCAssistant()
            .environmentObject(NCAssistantModel(controller: self.controller))
        let hostingController = UIHostingController(rootView: assistant)
        self.present(hostingController, animated: true, completion: nil)
    }

    func setEditMode(_ editMode: Bool) {
        isEditMode = editMode
        setSelectcancelButton()
    }

    func setSelectcancelButton() {
        let capabilities = NCNetworking.shared.capabilities[session.account] ?? NKCapabilities.Capabilities()
        let assistantEnabled = capabilities.assistantEnabled

        assistantButton.isHidden = true
        fileSelect.removeAll()
        tabBarSelect.selectCount = fileSelect.count

        if let visibleCells = self.collectionView?.indexPathsForVisibleItems.compactMap({ self.collectionView?.cellForItem(at: $0) }) {
            for case let cell as NCMediaCell in visibleCells {
                cell.selected(false)
            }
        }

        if isEditMode {
            selectOrCancelButton.setTitle( NSLocalizedString("_cancel_", comment: ""), for: .normal)
            selectOrCancelButton.isHidden = false
            menuButton.isHidden = true
            tabBarSelect.show()
        } else {
            selectOrCancelButton.setTitle( NSLocalizedString("_select_", comment: ""), for: .normal)
            selectOrCancelButton.isHidden = false
            menuButton.isHidden = false
            if assistantEnabled {
                assistantButton.isHidden = false
            }
            tabBarSelect.hide()
        }
    }

    func setTitleDate() {
        if let layoutAttributes = collectionView.collectionViewLayout.layoutAttributesForElements(in: collectionView.bounds) {
            let sortedAttributes = layoutAttributes.sorted { $0.frame.minY < $1.frame.minY || ($0.frame.minY == $1.frame.minY && $0.frame.minX < $1.frame.minX) }

            if let firstAttribute = sortedAttributes.first, let metadata = dataSource.getMetadata(indexPath: firstAttribute.indexPath) {
                titleDate?.text = utility.getTitleFromDate(metadata.datePhotosOriginal as Date)
                return
            }
        }

        titleDate?.text = ""
    }

    func setColor() {
        if isTop {
            UIView.animate(withDuration: 0.3) { [self] in
                gradientView.alpha = 0
                titleDate?.textColor = NCBrandColor.shared.textColor
                activityIndicator.color = NCBrandColor.shared.textColor
                selectOrCancelButton.setTitleColor(NCBrandColor.shared.textColor, for: .normal)
                menuButton.setImage(NCUtility().loadImage(named: "ellipsis", colors: [NCBrandColor.shared.textColor]), for: .normal)
                assistantButton.setImage(NCUtility().loadImage(named: "sparkles", colors: [NCBrandColor.shared.textColor]), for: .normal)
            }
        } else {
            UIView.animate(withDuration: 0.3) { [self] in
                gradientView.alpha = 1
                titleDate?.textColor = .white
                activityIndicator.color = .white
                selectOrCancelButton.setTitleColor(.white, for: .normal)
                menuButton.setImage(NCUtility().loadImage(named: "ellipsis", colors: [.white]), for: .normal)
                assistantButton.setImage(NCUtility().loadImage(named: "sparkles", colors: [.white]), for: .normal)
            }
        }
    }

    func createMenu() {
        let layoutForView = database.getLayoutForView(account: session.account, key: global.layoutViewMedia, serverUrl: "", layout: global.mediaLayoutRatio)
        var layout = layoutForView.layout
        /// Overwrite default value
        if layout == global.layoutList {
            layout = global.mediaLayoutRatio
        }
        ///
        let layoutTitle = (layout == global.mediaLayoutRatio) ? NSLocalizedString("_media_square_", comment: "") : NSLocalizedString("_media_ratio_", comment: "")
        let layoutImage = (layout == global.mediaLayoutRatio) ? utility.loadImage(named: "square.grid.3x3") : utility.loadImage(named: "rectangle.grid.3x2")

        let viewFilterMenu = UIMenu(title: "", options: .displayInline, children: [
            UIAction(title: NSLocalizedString("_media_viewimage_show_", comment: ""), image: utility.loadImage(named: "photo")) { _ in
                self.showOnlyImages = true
                self.showOnlyVideos = false
                Task {
                    await self.loadDataSource()
                    await self.networkRemoveAll()
                }
            },
            UIAction(title: NSLocalizedString("_media_viewvideo_show_", comment: ""), image: utility.loadImage(named: "video")) { _ in
                self.showOnlyImages = false
                self.showOnlyVideos = true
                Task {
                    await self.loadDataSource()
                    await self.networkRemoveAll()
                }
            },
            UIAction(title: NSLocalizedString("_media_show_all_", comment: ""), image: utility.loadImage(named: "photo.on.rectangle")) { _ in
                self.showOnlyImages = false
                self.showOnlyVideos = false
                Task {
                    await self.loadDataSource()
                    await self.networkRemoveAll()
                }
            }
        ])

        let viewLayoutMenu = UIMenu(title: "", options: .displayInline, children: [
            UIAction(title: layoutTitle, image: layoutImage) { _ in
                if layout == self.global.mediaLayoutRatio {
                    self.database.setLayoutForView(account: self.session.account, key: self.global.layoutViewMedia, serverUrl: "", layout: self.global.mediaLayoutSquare)
                    self.layoutType = self.global.mediaLayoutSquare
                } else {
                    self.database.setLayoutForView(account: self.session.account, key: self.global.layoutViewMedia, serverUrl: "", layout: self.global.mediaLayoutRatio)
                    self.layoutType = self.global.mediaLayoutRatio
                }
                self.createMenu()
                self.collectionViewReloadData()
            }
        ])

        let viewFolderMedia = UIMenu(title: "", options: .displayInline, children: [
            UIAction(title: NSLocalizedString("_select_media_folder_", comment: ""), image: utility.loadImage(named: "folder"), handler: { _ in
                guard let navigationController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateInitialViewController() as? UINavigationController,
                      let viewController = navigationController.topViewController as? NCSelect else { return }
                viewController.delegate = self
                viewController.typeOfCommandView = .select
                viewController.type = "mediaFolder"
                viewController.session = self.session
                self.present(navigationController, animated: true)
            })
        ])

        let playFile = UIAction(title: NSLocalizedString("_play_from_files_", comment: ""), image: utility.loadImage(named: "play.circle")) { _ in
            guard let controller = self.controller else { return }
            self.documentPickerViewController = NCDocumentPickerViewController(controller: controller, isViewerMedia: true, allowsMultipleSelection: false, viewController: self)
        }

        let playURL = UIAction(title: NSLocalizedString("_play_from_url_", comment: ""), image: utility.loadImage(named: "link")) { _ in
            let alert = UIAlertController(title: NSLocalizedString("_valid_video_url_", comment: ""), message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: nil))
            alert.addTextField(configurationHandler: { textField in
                textField.placeholder = "http://myserver.com/movie.mkv"
            })
            alert.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in
                guard let stringUrl = alert.textFields?.first?.text, !stringUrl.isEmpty, let url = URL(string: stringUrl) else {
                    return
                }
                let fileName = url.lastPathComponent
                Task {
                    let metadata = await self.database.createMetadataAsync(fileName: fileName,
                                                                           ocId: NSUUID().uuidString,
                                                                           serverUrl: "",
                                                                           url: stringUrl,
                                                                           session: self.session,
                                                                           sceneIdentifier: self.controller?.sceneIdentifier)
                    await self.database.addMetadataAsync(metadata)
                    NCViewer().view(viewController: self, metadata: metadata)
                }
            }))
            self.present(alert, animated: true)
        }

        menuButton.menu = UIMenu(title: "", children: [viewFilterMenu, viewLayoutMenu, viewFolderMedia, playFile, playURL])
    }
}

extension NCMedia: NCMediaSelectTabBarDelegate {
    func delete() {
        let ocIds = self.fileSelect.map { $0 }
        var alertStyle = UIAlertController.Style.actionSheet

        if UIDevice.current.userInterfaceIdiom == .pad { alertStyle = .alert }

        if !ocIds.isEmpty {
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: alertStyle)

            alertController.addAction(UIAlertAction(title: NSLocalizedString("_delete_selected_photos_", comment: ""), style: .destructive) { (_: UIAlertAction) in
                self.isEditMode = false
                self.setSelectcancelButton()

                Task {
                    for ocId in ocIds {
                        await self.deleteImage(with: ocId)
                    }
                    self.collectionViewReloadData()
                }
            })

            alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel) { (_: UIAlertAction) in })

            present(alertController, animated: true, completion: { })
        }
    }

    func deleteImage(with ocId: String) async {
        guard let metadata = await self.database.getMetadataFromOcIdAsync(ocId) else {
            await MainActor.run {
                self.dataSource.removeMetadata([ocId])
                self.collectionViewReloadData()
            }
            return
        }

        let resultsDeleteFileOrFolder = await NextcloudKit.shared.deleteFileOrFolderAsync(serverUrlFileName: metadata.serverUrlFileName, account: metadata.account)

        guard resultsDeleteFileOrFolder.error == .success || resultsDeleteFileOrFolder.error.errorCode == self.global.errorResourceNotFound else {
            return
        }

        self.ocIdDeleted.append(ocId)
        await self.database.deleteMetadataOcIdAsync(ocId)

        await MainActor.run {
            if let indexPath = self.dataSource.indexPath(forOcId: ocId) {
                self.collectionView.performBatchUpdates {
                    self.dataSource.removeMetadata([ocId])
                    self.collectionView.deleteItems(at: [indexPath])
                }
            } else {
                self.dataSource.removeMetadata([ocId])
                self.collectionViewReloadData()
            }
        }
    }

}
