// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import SwiftUI

class NCMediaNavigationController: NCMainNavigationController {
    static let photosAddedToAlbumNotification = Notification.Name("NCMediaPhotosAddedToAlbumNotification")

    // MARK: - Right

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(handlePhotosAddedToAlbumNotification(_:)), name: Self.photosAddedToAlbumNotification, object: nil)
    }

    override func setNavigationRightItems() async {
        guard let media = topViewController as? NCMedia else {
            return
        }

        if media.isEditMode {
            media.tabBarSelect.show()
            await collectionViewCommonTrailingItemGroups()
        } else {
            media.tabBarSelect.hide()
            await mediaTrailingItemGroups()
            await collectionViewCommonTrailingItemGroups()
        }
    }

    private func mediaTrailingItemGroups() async {
        let capabilities = await NKCapabilities.shared.getCapabilities(for: session.account)
        var desiredItems: [UIBarButtonItem] = []

        if controller?.availableNotifications ?? false {
            desiredItems.append(notificationsButtonItem)
        }

        if capabilities.assistantEnabled {
            desiredItems.append(assistantButtonItem)
        }

        desiredItems.append(transfersButtonItem)

        if let optionMenu = await self.createOptionMenu() {
            setOptionMenu(optionMenu)
            desiredItems.append(optionButtonItem)
        }

        let group = UIBarButtonItemGroup(
            barButtonItems: desiredItems,
            representativeItem: nil
        )

        topViewController?.navigationItem.trailingItemGroups = [group]
    }

    override func createOptionMenu() async -> UIMenu? {
        guard let media = topViewController as? NCMedia else {
            return nil
        }
        let select = UIAction(title: NSLocalizedString("_select_", comment: ""),
                              image: utility.loadImage(named: "checkmark.circle")) { _ in
            media.setEditMode(true)
            Task {
                await self.updateMenuOption()
            }
        }

        let cancel = UIAction(title: NSLocalizedString("_cancel_", comment: ""),
                              image: utility.loadImage(named: "xmark", colors: [NCBrandColor.shared.iconImageColor], size: 24).withTintColor(NCBrandColor.shared.iconImageColor)) { _ in
            media.setEditMode(false)
            Task {
                await media.loadDataSource()
                await media.networkRemoveAll()
            }
        }

        let viewFilterMenu = UIMenu(title: "", options: .displayInline, children: [
            UIDeferredMenuElement.uncached { [weak self, weak media] completion in
                guard let self, let media else {
                    completion([])
                    return
                }
                let actions = [
                    UIAction(title: NSLocalizedString("_media_viewimage_show_", comment: ""), image: self.utility.loadImage(named: "photo"), state: media.showOnlyImages ? .on : .off) { _ in
                        media.showOnlyImages = true
                        media.showOnlyVideos = false
                        Task {
                            await media.loadDataSource()
                            await media.networkRemoveAll()
                        }
                    },

                    UIAction(title: NSLocalizedString("_media_viewvideo_show_", comment: ""), image: self.utility.loadImage(named: "video"), state: media.showOnlyVideos ? .on : .off) { _ in
                        media.showOnlyImages = false
                        media.showOnlyVideos = true
                        Task {
                            await media.loadDataSource()
                            await media.networkRemoveAll()
                        }
                    },

                    UIAction(title: NSLocalizedString("_media_show_all_", comment: ""), image: self.utility.loadImage(named: "photo.on.rectangle"), state: (!media.showOnlyImages && !media.showOnlyVideos) ? .on : .off) { _ in
                        media.showOnlyImages = false
                        media.showOnlyVideos = false
                        Task {
                            await media.loadDataSource()
                            await media.networkRemoveAll()
                        }
                    }
                ]

                completion(actions)
            }
        ])

        let viewLayoutMenu = UIMenu(title: "", options: .displayInline, children: [
            UIDeferredMenuElement.uncached { [weak self] completion in
                guard let self else {
                    completion([])
                    return
                }

                let layoutForView = self.database.getLayoutForView(account: self.session.account, key: self.global.layoutViewMedia, serverUrl: "", layoutType: self.global.mediaLayoutRatio)
                var layout = layoutForView.layout

                // Overwrite default value
                if layout == self.global.layoutList {
                    layout = self.global.mediaLayoutRatio
                }

                let layoutTitle = (layout == self.global.mediaLayoutRatio) ? NSLocalizedString("_media_square_", comment: "") : NSLocalizedString("_media_ratio_", comment: "")
                let layoutImage = (layout == self.global.mediaLayoutRatio) ? self.utility.loadImage(named: "square.grid.3x3") : self.utility.loadImage(named: "rectangle.grid.3x2")

                let action = UIAction(title: layoutTitle, image: layoutImage) { _ in
                    Task {
                        if layout == self.global.mediaLayoutRatio {
                            self.database.setLayoutForView(account: self.session.account, key: self.global.layoutViewMedia, serverUrl: "", layout: self.global.mediaLayoutSquare)
                            media.layoutType = self.global.mediaLayoutSquare
                        } else {
                            self.database.setLayoutForView(account: self.session.account, key: self.global.layoutViewMedia, serverUrl: "", layout: self.global.mediaLayoutRatio)
                            media.layoutType = self.global.mediaLayoutRatio
                        }

                        media.collectionViewReloadData()
                    }
                }

                completion([action])
            }
        ])
        let viewFolderMedia = UIMenu(title: "", options: .displayInline, children: [
            UIDeferredMenuElement.uncached { [weak self] completion in
                guard let self else {
                    completion([])
                    return
                }

                let mediaPath = self.database.getTableAccount(account: self.session.account)?.mediaPath.replacingOccurrences(of: "/", with: "") ?? ""

                let selectMediaFolderAction = UIAction(title: NSLocalizedString("_select_media_folder_", comment: ""), subtitle: mediaPath, image: self.utility.loadImage(named: "folder"), handler: { _ in
                    guard let navigationController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateInitialViewController() as? UINavigationController,
                          let viewController = navigationController.topViewController as? NCSelect else { return }
                    viewController.delegate = media
                    viewController.typeOfCommandView = .select
                    viewController.type = "mediaFolder"
                    viewController.session = self.session
                    viewController.controller = self.controller
                    self.present(navigationController, animated: true)
                })

                completion([selectMediaFolderAction])
            }
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
                    let metadata = await NCManageDatabaseCreateMetadata().createMetadataAsync(
                        fileName: fileName,
                        ocId: NSUUID().uuidString,
                        serverUrl: "",
                        url: stringUrl,
                        session: self.session,
                        sceneIdentifier: self.controller?.sceneIdentifier)
                    await self.database.addMetadataAsync(metadata)

                    if let vc = await NCViewer().getViewerController(metadata: metadata, delegate: self, viewerTransitionSource: nil) {
                        self.navigationController?.pushViewController(vc, animated: true)
                    }
                }
            }))
            self.present(alert, animated: true)
        }

        let selectAll = UIMenu(title: "", options: .displayInline, children: [
            UIAction(
                title: NSLocalizedString("_select_all_", comment: ""),
                image: utility.loadImage(named: "checkmark.circle.fill"),
                handler: { _ in
                    // Ensure edit mode is enabled so selection is visible
                    if !media.isEditMode {
                        media.setEditMode(true)
                    }

                    // Toggle select all / clear selection
                    if !media.fileSelect.isEmpty, media.dataSource.compactMetadatas.count == media.fileSelect.count {
                        media.fileSelect = []
                    } else {
                        media.fileSelect = media.dataSource.compactMetadatas.compactMap { $0.ocId }
                    }

                    // Update selection count and refresh UI without reloading data source
                    media.tabBarSelect.selectCount = media.fileSelect.count
                    media.collectionViewReloadData()
                }
            )
        ])

        let actionsInEditMode: [UIAction] = [
            UIAction(
                title: NSLocalizedString("_add_to_album", comment: ""),
                image: utility.loadImage(named: "photo.badge.plus.fill"),
                handler: { _ in
                    guard let controller = self.controller else { return }
                    NCMediaNavigationController.presentExistingAlbums(controller: controller, selectedPhotos: media.fileSelect)
                }
            ),

            UIAction(
                title: NSLocalizedString("_albums_list_new_album_popup_title_", comment: ""),
                image: utility.loadImage(named: "photo.stack.fill"),
                handler: { _ in
                    guard let controller = self.controller else { return }
                    NCMediaNavigationController.presentInputAlbumNameAlert(on: controller) { albumName in
                        NCMediaNavigationController.createNewAlbum(for: albumName, selectedPhotos: media.fileSelect, controller: controller)
                    } onCancel: { }
                }
            )
        ]

        let editModeMenu = UIMenu(
            title: "",
            options: .displayInline,
            children: actionsInEditMode
        )
        return UIMenu(title: "", children: !media.isEditMode ? [select, viewFilterMenu, viewLayoutMenu, viewFolderMedia, playFile, playURL] : [cancel, selectAll, editModeMenu])
    }

    // MARK: - Album related handling
    @objc private func handlePhotosAddedToAlbumNotification(_ notification: Notification) {
        guard let sourceController = notification.object as? NCMainTabBarController,
              sourceController === controller,
              let media = topViewController as? NCMedia else { return }
        media.setEditMode(false)
        Task {
            await media.loadDataSource()
            await media.networkRemoveAll()
//            await self.updateMenuOption()
        }
    }

    static func presentInputAlbumNameAlert(
         on viewController: UIViewController,
         onCreate: @escaping (String) -> Void,
         onCancel: @escaping () -> Void
    ) {
        let alert = UIAlertController(
         title: NSLocalizedString("_albums_list_new_album_popup_title_", comment: ""),
         message: NSLocalizedString("_albums_list_new_album_popup_desc_", comment: ""),
         preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = NSLocalizedString("_albums_list_new_album_popup_hint_", comment: "")
        }

        alert.addAction(UIAlertAction(title: NSLocalizedString("_albums_list_new_album_popup_negative_btn_", comment: ""), style: .default) { _ in
            onCancel()
        })

        alert.addAction(UIAlertAction(title: NSLocalizedString("_albums_list_new_album_popup_positive_btn_", comment: ""), style: .default) { _ in
            let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text.isEmpty {
                let emptyAlert = UIAlertController(
                    title: NSLocalizedString("_albums_list_new_album_popup_title_", comment: ""),
                    message: NSLocalizedString("_albums_list_new_album_popup_hint_", comment: ""),
                    preferredStyle: .alert
                )
                emptyAlert.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default))
                viewController.present(emptyAlert, animated: true)
            } else {
                onCreate(text)
            }
        })

        alert.view.tintColor = NCBrandColor.shared.customer
        viewController.present(alert, animated: true)
    }

     static private func createNewAlbum(for name: String, selectedPhotos: [String], controller: NCMainTabBarController) {
         let loader = NCLoadingAlert.show(on: controller)

         NextcloudKit.shared.createNewAlbum(for: controller.account, albumName: name) { result in
             NCLoadingAlert.hide(loader)
             switch result {
             case .success(let account):
                 AlbumsManager.shared.syncAlbums(for: account) { resultAlbums in
                     if let newAlbum = resultAlbums.first(where: { $0.name == name }) {
                         if selectedPhotos.isEmpty {
                             showAlbumAndNotify(newAlbum, controller: controller)
                         } else {
                             addPhotosToAlbum(album: newAlbum, selectedPhotos: selectedPhotos, controller: controller)
                         }
                     } else {
                         // Album not yet visible in the sync result; still notify UI to refresh
                         NotificationCenter.default.post(name: NCMediaNavigationController.photosAddedToAlbumNotification, object: controller)
                     }
                 }

             case .failure(let error):
                 Task {
                     await showErrorBanner(windowScene: controller.viewIfLoaded?.window?.windowScene, error: error)
                 }
             }
         }
     }

    static func presentExistingAlbums(controller: NCMainTabBarController, selectedPhotos: [String]) {
        let viewModel = AlbumsListViewModel(controller: controller)
        let albumListView = AddToAlbumsListView(viewModel: viewModel, controller: controller, onFinish: { selectedAlbum in
            controller.dismiss(animated: true) {
                addPhotosToAlbum(album: selectedAlbum, selectedPhotos: selectedPhotos, controller: controller)
            }
        }, onDismiss: {
            controller.dismiss(animated: true)
        }, onCreateAlbum: {
            controller.dismiss(animated: true) {
                presentInputAlbumNameAlert(on: controller) { albumName in
                    createNewAlbum(for: albumName, selectedPhotos: selectedPhotos, controller: controller)
                } onCancel: { }
            }
        })

        let hostingController = UIHostingController(rootView: albumListView)
        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        controller.present(hostingController, animated: true, completion: nil)
    }

    private static func showAlbumAndNotify(_ album: Album, controller: NCMainTabBarController) {
        DispatchQueue.main.async {
            guard controller.viewIfLoaded?.window != nil,
                  let navigationController = controller.viewControllers?.compactMap({ $0 as? NCMoreNavigationController }).first,
                  let albumsController = UIStoryboard(name: "NCAlbums", bundle: nil)
                    .instantiateInitialViewController() as? AlbumsViewController else {
                return
            }

            albumsController.initialAlbum = album
            controller.selectedViewController = navigationController
            guard let moreController = navigationController.viewControllers.first else { return }
            navigationController.setViewControllers([moreController, albumsController], animated: true)
            NotificationCenter.default.post(name: photosAddedToAlbumNotification, object: controller)
        }
    }

    static func addPhotosToAlbum(album: Album, selectedPhotos: [String], controller: NCMainTabBarController) {
        if selectedPhotos.isEmpty {
            showAlbumAndNotify(album, controller: controller)
            return
        }

        var completed = 0
        var succeeded = 0
        let total = selectedPhotos.count
        func finishIfDone() {
            completed += 1
            guard completed == total, succeeded > 0 else { return }
            AlbumsManager.shared.invalidatePhotoRequest(for: album)
            AlbumsManager.shared.syncAlbums(for: controller.account)
            showAlbumAndNotify(album, controller: controller)
        }

        for photo in selectedPhotos {
            guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(photo) else {
                Task {
                    await showErrorBanner(windowScene: controller.viewIfLoaded?.window?.windowScene, error: .invalidData)
                }
                finishIfDone()
                continue
            }

            NextcloudKit.shared.copyPhotoToAlbum(
                account: controller.account,
                sourcePath: metadata.serverUrlFileName,
                albumName: album.name,
                fileName: metadata.fileName
            ) { result in
                switch result {
                case .success:
                    succeeded += 1
                    finishIfDone()
                case .failure(let error):
                    Task {
                        await showErrorBanner(windowScene: controller.viewIfLoaded?.window?.windowScene, error: error)
                    }
                    finishIfDone()
                }
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: Self.photosAddedToAlbumNotification, object: nil)
    }
}
