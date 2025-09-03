// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

class NCMediaNavigationController: NCMainNavigationController {

    // MARK: - Right

    override func createRightMenu() async -> UIMenu? {
        guard let media = topViewController as? NCMedia else {
            return nil
        }
        let layoutForView = database.getLayoutForView(account: session.account, key: global.layoutViewMedia, serverUrl: "", layout: global.mediaLayoutRatio)
        var layout = layoutForView.layout
        /// Overwrite default value
        if layout == global.layoutList {
            layout = global.mediaLayoutRatio
        }
        ///
        let layoutTitle = (layout == global.mediaLayoutRatio) ? NSLocalizedString("_media_square_", comment: "") : NSLocalizedString("_media_ratio_", comment: "")
        let layoutImage = (layout == global.mediaLayoutRatio) ? utility.loadImage(named: "square.grid.3x3") : utility.loadImage(named: "rectangle.grid.3x2")

        let select = UIAction(title: NSLocalizedString("_select_", comment: ""),
                              image: utility.loadImage(named: "checkmark.circle")) { _ in
            media.isEditMode = !media.isEditMode
            media.setSelectcancelButton()
        }

        let viewFilterMenu = UIMenu(title: "", options: .displayInline, children: [
        UIAction(title: NSLocalizedString("_media_viewimage_show_", comment: ""), image: utility.loadImage(named: "photo")) { _ in
            media.showOnlyImages = true
            media.showOnlyVideos = false
            Task {
                await media.loadDataSource()
                await media.networkRemoveAll()
            }
        },
            UIAction(title: NSLocalizedString("_media_viewvideo_show_", comment: ""), image: utility.loadImage(named: "video")) { _ in
                media.showOnlyImages = false
                media.showOnlyVideos = true
                Task {
                    await media.loadDataSource()
                    await media.networkRemoveAll()
                }
            },
            UIAction(title: NSLocalizedString("_media_show_all_", comment: ""), image: utility.loadImage(named: "photo.on.rectangle")) { _ in
                media.showOnlyImages = false
                media.showOnlyVideos = false
                Task {
                    await media.loadDataSource()
                    await media.networkRemoveAll()
                }
            }
        ])

        let viewLayoutMenu = UIMenu(title: "", options: .displayInline, children: [
            UIAction(title: layoutTitle, image: layoutImage) { _ in
                Task {
                    if layout == self.global.mediaLayoutRatio {
                        self.database.setLayoutForView(account: self.session.account, key: self.global.layoutViewMedia, serverUrl: "", layout: self.global.mediaLayoutSquare)
                        media.layoutType = self.global.mediaLayoutSquare
                    } else {
                        self.database.setLayoutForView(account: self.session.account, key: self.global.layoutViewMedia, serverUrl: "", layout: self.global.mediaLayoutRatio)
                        media.layoutType = self.global.mediaLayoutRatio
                    }
                    await self.updateRightMenu()
                    media.collectionViewReloadData()
                }
            }
        ])

        let viewFolderMedia = UIMenu(title: "", options: .displayInline, children: [
            UIAction(title: NSLocalizedString("_select_media_folder_", comment: ""), image: utility.loadImage(named: "folder"), handler: { _ in
                guard let navigationController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateInitialViewController() as? UINavigationController,
                      let viewController = navigationController.topViewController as? NCSelect else { return }
                viewController.delegate = media
                viewController.typeOfCommandView = .select
                viewController.type = "mediaFolder"
                viewController.session = self.session
                self.present(navigationController, animated: true)
            })
        ])

        let playFile = UIAction(title: NSLocalizedString("_play_from_files_", comment: ""), image: utility.loadImage(named: "play.circle")) { _ in
            guard let controller = self.controller else { return }
            media.documentPickerViewController = NCDocumentPickerViewController(controller: controller, isViewerMedia: true, allowsMultipleSelection: false, viewController: media)
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

                    if let vc = await NCViewer().getViewerController(metadata: metadata, delegate: self) {
                        self.navigationController?.pushViewController(vc, animated: true)
                    }
                }
            }))
            self.present(alert, animated: true)
        }

        return UIMenu(title: "", children: [select, viewFilterMenu, viewLayoutMenu, viewFolderMedia, playFile, playURL])

        /*
        guard let items = await self.createRightMenuActions(),
              let collectionViewCommon
        else {
            return nil
        }

        if collectionViewCommon.layoutKey == global.layoutViewFavorite {
            let fileSettings = UIMenu(title: "", options: .displayInline, children: [items.directoryOnTop, items.hiddenFiles])

            return UIMenu(children: [items.select, items.viewStyleSubmenu, items.sortSubmenu, fileSettings])
        } else {
            let fileSettings = UIMenu(title: "", options: .displayInline, children: [items.directoryOnTop, items.hiddenFiles])
            let additionalSettings = UIMenu(title: "", options: .displayInline, children: [items.showDescription])

            return UIMenu(children: [items.select, items.viewStyleSubmenu, items.sortSubmenu, fileSettings, additionalSettings])
        }
        */
    }
}
