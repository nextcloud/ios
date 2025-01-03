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

extension NCMedia {
    @IBAction func selectOrCancelButtonPressed(_ sender: UIButton) {
        isEditMode = !isEditMode
        setSelectcancelButton()
    }

    func setEditMode(_ editMode: Bool) {
        isEditMode = editMode
        setSelectcancelButton()
        updateHeadersView()
        setNavigationLeftItems()
    }

    func setSelectcancelButton() {
        fileSelect.removeAll()
        tabBarSelect.selectCount = fileSelect.count

        if let visibleCells = self.collectionView?.indexPathsForVisibleItems.compactMap({ self.collectionView?.cellForItem(at: $0) }) {
            for case let cell as NCMediaCell in visibleCells {
                cell.selected(false)
            }
        }

        if isEditMode {
            tabBarSelect.show()
        } else {
            tabBarSelect.hide()
        }
    }

    func createMenuElements() -> [UIMenuElement] {
        let layoutForView = database.getLayoutForView(account: session.account, key: global.layoutViewMedia, serverUrl: "")
        var layout = layoutForView?.layout ?? global.mediaLayoutRatio
        /// Overwrite default value
        if layout == global.layoutList { layout = global.mediaLayoutRatio }
        ///
        let layoutTitle = (layout == global.mediaLayoutRatio) ? NSLocalizedString("_media_square_", comment: "") : NSLocalizedString("_media_ratio_", comment: "")
        let layoutImage = (layout == global.mediaLayoutRatio) ? utility.loadImage(named: "square.grid.3x3") : utility.loadImage(named: "rectangle.grid.3x2")

        let viewFilterMenu = UIMenu(title: "", options: .displayInline, children: [
            UIAction(title: NSLocalizedString("_media_viewimage_show_", comment: ""), image: utility.loadImage(named: "photo")) { _ in
                self.showOnlyImages = true
                self.showOnlyVideos = false
                self.loadDataSource()
                self.networkRemoveAll()
            },
            UIAction(title: NSLocalizedString("_media_viewvideo_show_", comment: ""), image: utility.loadImage(named: "video")) { _ in
                self.showOnlyImages = false
                self.showOnlyVideos = true
                self.loadDataSource()
                self.networkRemoveAll()
            },
            UIAction(title: NSLocalizedString("_media_show_all_", comment: ""), image: utility.loadImage(named: "photo.on.rectangle")) { _ in
                self.showOnlyImages = false
                self.showOnlyVideos = false
                self.loadDataSource()
                self.searchMediaUI()
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
                self.updateHeadersMenu()
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
                guard let stringUrl = alert.textFields?.first?.text, !stringUrl.isEmpty, let url = URL(string: stringUrl) else { return }
                let fileName = url.lastPathComponent
                let metadata = self.database.createMetadata(fileName: fileName,
                                                            fileNameView: fileName,
                                                            ocId: NSUUID().uuidString,
                                                            serverUrl: "",
                                                            url: stringUrl,
                                                            contentType: "",
                                                            session: self.session,
                                                            sceneIdentifier: self.controller?.sceneIdentifier)
                self.database.addMetadata(metadata)
                NCViewer().view(viewController: self, metadata: metadata)
            }))
            self.present(alert, animated: true)
        }

        return [viewFilterMenu, viewLayoutMenu, viewFolderMedia, playFile, playURL]
    }
}

extension NCMedia: NCMediaSelectTabBarDelegate {
    func delete() {
        let ocIds = self.fileSelect.map { $0 }
        var alertStyle = UIAlertController.Style.actionSheet
        var indexPaths: [IndexPath] = []
        var metadatas: [tableMetadata] = []

        if UIDevice.current.userInterfaceIdiom == .pad { alertStyle = .alert }

        if !ocIds.isEmpty {
            let indices = dataSource.metadatas.enumerated().filter { ocIds.contains($0.element.ocId) }.map { $0.offset }
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: alertStyle)

            alertController.addAction(UIAlertAction(title: NSLocalizedString("_delete_selected_photos_", comment: ""), style: .destructive) { (_: UIAlertAction) in
                self.setEditMode(false)

                for ocId in ocIds {
                    if let metadata = self.database.getMetadataFromOcId(ocId) {
                        metadatas.append(metadata)
                    }
                }

                NCNetworking.shared.deleteMetadatas(metadatas, sceneIdentifier: self.controller?.sceneIdentifier)

                for index in indices {
                    let indexPath = IndexPath(row: index, section: 0)
                    if let cell = self.collectionView.cellForItem(at: indexPath) as? NCMediaCell,
                       self.dataSource.metadatas[index].ocId == cell.ocId {
                        indexPaths.append(indexPath)
                    }
                }

                self.dataSource.removeMetadata(ocIds)
                if indexPaths.count == ocIds.count {
                    self.collectionView.deleteItems(at: indexPaths)
                } else {
                    self.collectionViewReloadData()
                }
            })

            alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel) { (_: UIAlertAction) in })

            present(alertController, animated: true, completion: { })
        }
    }
}
