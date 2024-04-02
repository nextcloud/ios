//
//  NCMedia+Command.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 24/02/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import NextcloudKit

extension NCMedia {
    @IBAction func selectOrCancelButtonPressed(_ sender: UIButton) {
        isEditMode = !isEditMode
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
            titleDate?.textColor = .label
            activityIndicator.color = .label
            selectOrCancelButton.setTitleColor(.label, for: .normal)
            menuButton.setImage(UIImage(systemName: "ellipsis")?.withTintColor(.label, renderingMode: .alwaysOriginal), for: .normal)
            gradientView.isHidden = true
        } else {
            titleDate?.textColor = .white
            activityIndicator.color = .white
            selectOrCancelButton.setTitleColor(.white, for: .normal)
            menuButton.setImage(UIImage(systemName: "ellipsis")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
            gradientView.isHidden = false
        }
    }

    func createMenu() {
        var columnCount = NCKeychain().mediaColumnCount
        let layout = NCKeychain().mediaTypeLayout
        let layoutTitle = (layout == NCGlobal.shared.mediaLayoutRatio) ? NSLocalizedString("_media_square_", comment: "") : NSLocalizedString("_media_ratio_", comment: "")
        let layoutImage = (layout == NCGlobal.shared.mediaLayoutRatio) ? UIImage(systemName: "square.grid.3x3") : UIImage(systemName: "rectangle.grid.3x2")

        if UIDevice.current.userInterfaceIdiom == .phone, UIDevice.current.orientation.isLandscape {
            columnCount += 2
        }

        if CGFloat(columnCount) >= maxImageGrid - 1 {
            self.attributesZoomIn = []
            self.attributesZoomOut = .disabled
        } else if columnCount <= 1 {
            self.attributesZoomIn = .disabled
            self.attributesZoomOut = []
        } else {
            self.attributesZoomIn = []
            self.attributesZoomOut = []
        }

        let viewFilterMenu = UIMenu(title: "", options: .displayInline, children: [
            UIAction(title: NSLocalizedString("_media_viewimage_show_", comment: ""), image: UIImage(systemName: "photo")) { _ in
                self.showOnlyImages = true
                self.showOnlyVideos = false
                self.reloadDataSource()
            },
            UIAction(title: NSLocalizedString("_media_viewvideo_show_", comment: ""), image: UIImage(systemName: "video")) { _ in
                self.showOnlyImages = false
                self.showOnlyVideos = true
                self.reloadDataSource()
            },
            UIAction(title: NSLocalizedString("_media_show_all_", comment: ""), image: UIImage(systemName: "photo.on.rectangle")) { _ in
                self.showOnlyImages = false
                self.showOnlyVideos = false
                self.reloadDataSource()
            }
        ])
        let viewLayoutMenu = UIAction(title: layoutTitle, image: layoutImage) { _ in
            if layout == NCGlobal.shared.mediaLayoutRatio {
                NCKeychain().mediaTypeLayout = NCGlobal.shared.mediaLayoutSquare
            } else {
                NCKeychain().mediaTypeLayout = NCGlobal.shared.mediaLayoutRatio
            }
            self.createMenu()
            self.collectionViewReloadData()
        }

        let zoomViewMediaFolder = UIMenu(title: "", options: .displayInline, children: [
            UIMenu(title: NSLocalizedString("_zoom_", comment: ""), children: [
                UIAction(title: NSLocalizedString("_zoom_out_", comment: ""), image: UIImage(systemName: "minus.magnifyingglass"), attributes: self.attributesZoomOut) { _ in
                    UIView.animate(withDuration: 0.0, animations: {
                        NCKeychain().mediaColumnCount = columnCount + 1
                        self.createMenu()
                        self.collectionViewReloadData()
                    })
                },
                UIAction(title: NSLocalizedString("_zoom_in_", comment: ""), image: UIImage(systemName: "plus.magnifyingglass"), attributes: self.attributesZoomIn) { _ in
                    UIView.animate(withDuration: 0.0, animations: {
                        NCKeychain().mediaColumnCount = columnCount - 1
                        self.createMenu()
                        self.collectionViewReloadData()
                    })
                }
            ]),
            UIMenu(title: NSLocalizedString("_media_view_options_", comment: ""), children: [viewFilterMenu, viewLayoutMenu]),
            UIAction(title: NSLocalizedString("_select_media_folder_", comment: ""), image: UIImage(systemName: "folder"), handler: { _ in
                guard let navigationController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateInitialViewController() as? UINavigationController,
                      let viewController = navigationController.topViewController as? NCSelect else { return }
                viewController.delegate = self
                viewController.typeOfCommandView = .select
                viewController.type = "mediaFolder"
                self.present(navigationController, animated: true)
            })
        ])

        let playFile = UIAction(title: NSLocalizedString("_play_from_files_", comment: ""), image: UIImage(systemName: "play.circle")) { _ in
            guard let tabBarController = self.tabBarController else { return }
            self.documentPickerViewController = NCDocumentPickerViewController(tabBarController: tabBarController, isViewerMedia: true, allowsMultipleSelection: false, viewController: self)
        }

        let playURL = UIAction(title: NSLocalizedString("_play_from_url_", comment: ""), image: UIImage(systemName: "link")) { _ in
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

        menuButton.menu = UIMenu(title: "", children: [zoomViewMediaFolder, playFile, playURL])
    }
}

extension NCMedia: NCMediaSelectTabBarDelegate {
    func delete() {
        let selectOcId = self.selectOcId.map { $0 }
        if !selectOcId.isEmpty {
            let alertController = UIAlertController(
                title: NSLocalizedString("_delete_selected_photos_", comment: ""),
                message: "",
                preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_", comment: ""), style: .default) { (_: UIAlertAction) in

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
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .default) { (_: UIAlertAction) in })

            present(alertController, animated: true, completion: { })
        }
    }
}
