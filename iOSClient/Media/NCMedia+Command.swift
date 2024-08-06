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
    }

    func setSelectcancelButton() {
        selectOcId.removeAll()
        tabBarSelect.selectCount = selectOcId.count
        if let visibleCells = self.collectionView?.indexPathsForVisibleItems.compactMap({ self.collectionView?.cellForItem(at: $0) }) {
            for case let cell as NCGridMediaCell in visibleCells {
                cell.selected(false)
            }
        }
        if isEditMode {
            activityIndicatorTrailing.constant = 150
            selectOrCancelButton.setTitle( NSLocalizedString("_cancel_", comment: ""), for: .normal)
            selectOrCancelButtonTrailing.constant = 10
            selectOrCancelButton.isHidden = false
            menuButton.isHidden = true
            tabBarSelect.show()
        } else {
            activityIndicatorTrailing.constant = 150
            selectOrCancelButton.setTitle( NSLocalizedString("_select_", comment: ""), for: .normal)
            selectOrCancelButtonTrailing.constant = 50
            selectOrCancelButton.isHidden = false
            menuButton.isHidden = false
            tabBarSelect.hide()
        }
    }

    func setTitleDate(_ offset: CGFloat = 10) {
        titleDate?.text = ""
        if let metadata = metadatas?.first {
            let contentOffsetY = collectionView.contentOffset.y
            let top = insetsTop + view.safeAreaInsets.top + offset
            if insetsTop + view.safeAreaInsets.top + contentOffsetY < 10 {
                titleDate?.text = utility.getTitleFromDate(metadata.date as Date)
                return
            }
            let point = CGPoint(x: offset, y: top + contentOffsetY)
            if let indexPath = collectionView.indexPathForItem(at: point) {
                let cell = self.collectionView(collectionView, cellForItemAt: indexPath) as? NCGridMediaCell
                if let date = cell?.date {
                    self.titleDate?.text = utility.getTitleFromDate(date)
                }
            } else {
                if offset < 20 {
                    self.setTitleDate(20)
                }
            }
        }
    }

    func setColor() {
        if isTop {
            UIView.animate(withDuration: 0.3) { [self] in
                gradientView.alpha = 0
                titleDate?.textColor = NCBrandColor.shared.textColor
                activityIndicator.color = NCBrandColor.shared.textColor
                selectOrCancelButton.setTitleColor(NCBrandColor.shared.textColor, for: .normal)
                menuButton.setImage(NCUtility().loadImage(named: "ellipsis", colors: [NCBrandColor.shared.textColor]), for: .normal)
            }
        } else {
            UIView.animate(withDuration: 0.3) { [self] in
                gradientView.alpha = 1
                titleDate?.textColor = .white
                activityIndicator.color = .white
                selectOrCancelButton.setTitleColor(.white, for: .normal)
                menuButton.setImage(NCUtility().loadImage(named: "ellipsis", colors: [.white]), for: .normal)
            }
        }
    }

    func createMenu() {
        let layoutForView = NCManageDatabase.shared.getLayoutForView(account: appDelegate.account, key: NCGlobal.shared.layoutViewMedia, serverUrl: "")
        let columnPhoto = layoutForView?.columnPhoto ?? 3
        let layout = layoutForView?.layout ?? NCGlobal.shared.mediaLayoutRatio
        let layoutTitle = (layout == NCGlobal.shared.mediaLayoutRatio) ? NSLocalizedString("_media_square_", comment: "") : NSLocalizedString("_media_ratio_", comment: "")
        let layoutImage = (layout == NCGlobal.shared.mediaLayoutRatio) ? utility.loadImage(named: "square.grid.3x3") : utility.loadImage(named: "rectangle.grid.3x2")

        if CGFloat(columnPhoto) >= maxImageGrid - 1 {
            self.attributesZoomIn = []
            self.attributesZoomOut = .disabled
        } else if columnPhoto <= 1 {
            self.attributesZoomIn = .disabled
            self.attributesZoomOut = []
        } else {
            self.attributesZoomIn = []
            self.attributesZoomOut = []
        }

        let viewFilterMenu = UIMenu(title: "", options: .displayInline, children: [
            UIAction(title: NSLocalizedString("_media_viewimage_show_", comment: ""), image: utility.loadImage(named: "photo")) { _ in
                self.showOnlyImages = true
                self.showOnlyVideos = false
                self.reloadDataSource()
            },
            UIAction(title: NSLocalizedString("_media_viewvideo_show_", comment: ""), image: utility.loadImage(named: "video")) { _ in
                self.showOnlyImages = false
                self.showOnlyVideos = true
                self.reloadDataSource()
            },
            UIAction(title: NSLocalizedString("_media_show_all_", comment: ""), image: utility.loadImage(named: "photo.on.rectangle")) { _ in
                self.showOnlyImages = false
                self.showOnlyVideos = false
                self.reloadDataSource()
            }
        ])
        let viewLayoutMenu = UIAction(title: layoutTitle, image: layoutImage) { _ in
            if layout == NCGlobal.shared.mediaLayoutRatio {
                NCManageDatabase.shared.setLayoutForView(account: self.appDelegate.account, key: NCGlobal.shared.layoutViewMedia, serverUrl: "", layout: NCGlobal.shared.mediaLayoutSquare)
                self.layoutType = NCGlobal.shared.mediaLayoutSquare
            } else {
                NCManageDatabase.shared.setLayoutForView(account: self.appDelegate.account, key: NCGlobal.shared.layoutViewMedia, serverUrl: "", layout: NCGlobal.shared.mediaLayoutRatio)
                self.layoutType = NCGlobal.shared.mediaLayoutRatio
            }
            self.createMenu()
            self.collectionViewReloadData()
        }

        let viewOptionsMedia = UIMenu(title: "", options: .displayInline, children: [
            UIMenu(title: NSLocalizedString("_media_view_options_", comment: ""), children: [viewFilterMenu, viewLayoutMenu]),
            UIAction(title: NSLocalizedString("_select_media_folder_", comment: ""), image: utility.loadImage(named: "folder"), handler: { _ in
                guard let navigationController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateInitialViewController() as? UINavigationController,
                      let viewController = navigationController.topViewController as? NCSelect else { return }
                viewController.delegate = self
                viewController.typeOfCommandView = .select
                viewController.type = "mediaFolder"
                self.present(navigationController, animated: true)
            })
        ])

        let zoomOut = UIAction(title: NSLocalizedString("_zoom_out_", comment: ""), image: utility.loadImage(named: "minus.magnifyingglass"), attributes: self.attributesZoomOut) { _ in
            UIView.animate(withDuration: 0.0, animations: {
                let column = columnPhoto + 1
                NCManageDatabase.shared.setLayoutForView(account: self.appDelegate.account, key: NCGlobal.shared.layoutViewMedia, serverUrl: "", columnPhoto: column)
                self.createMenu()
                self.collectionViewReloadData()
            })
        }

        let zoomIn = UIAction(title: NSLocalizedString("_zoom_in_", comment: ""), image: utility.loadImage(named: "plus.magnifyingglass"), attributes: self.attributesZoomIn) { _ in
            UIView.animate(withDuration: 0.0, animations: {
                let column = columnPhoto - 1
                NCManageDatabase.shared.setLayoutForView(account: self.appDelegate.account, key: NCGlobal.shared.layoutViewMedia, serverUrl: "", columnPhoto: column)
                self.createMenu()
                self.collectionViewReloadData()
            })
        }

        let playFile = UIAction(title: NSLocalizedString("_play_from_files_", comment: ""), image: utility.loadImage(named: "play.circle")) { _ in
            guard let controller = self.tabBarController as? NCMainTabBarController else { return }
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
                let metadata = NCManageDatabase.shared.createMetadata(account: self.activeAccount.account, user: self.activeAccount.user, userId: self.activeAccount.userId, fileName: fileName, fileNameView: fileName, ocId: NSUUID().uuidString, serverUrl: "", urlBase: self.activeAccount.urlBase, url: stringUrl, contentType: "")
                NCManageDatabase.shared.addMetadata(metadata)
                NCViewer().view(viewController: self, metadata: metadata, metadatas: [metadata], imageIcon: nil)
            }))
            self.present(alert, animated: true)
        }

        menuButton.menu = UIMenu(title: "", children: [zoomOut, zoomIn, viewOptionsMedia, playFile, playURL])
    }
}

extension NCMedia: NCMediaSelectTabBarDelegate {
    func delete() {
        let selectOcId = self.selectOcId.map { $0 }
        var alertStyle = UIAlertController.Style.actionSheet
        if UIDevice.current.userInterfaceIdiom == .pad { alertStyle = .alert }
        if !selectOcId.isEmpty {
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: alertStyle)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_delete_selected_photos_", comment: ""), style: .destructive) { (_: UIAlertAction) in
                Task {
                    var error = NKError()
                    var ocIds: [String] = []
                    for ocId in selectOcId where error == .success {
                        if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                            error = await NCNetworking.shared.deleteMetadata(metadata, onlyLocalCache: false)
                            if error == .success {
                                ocIds.append(metadata.ocId)
                            }
                        }
                    }
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDeleteFile, userInfo: ["ocId": ocIds, "onlyLocalCache": false, "error": error])
                }
                self.isEditMode = false
                self.setSelectcancelButton()
            })
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel) { (_: UIAlertAction) in })
            present(alertController, animated: true, completion: { })
        }
    }
}
