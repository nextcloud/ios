// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import SwiftUI

class NCMediaNavigationController: NCMainNavigationController {

    static let photosAddedToAlbumNotification = Notification.Name("NCMediaPhotosAddedToAlbumNotification")
    static let showAlbumDetailsNotification = Notification.Name("NCMediaShowAlbumDetailsNotification")

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
            optionButtonItem.menu = optionMenu
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
        let layoutForView = database.getLayoutForView(account: session.account, key: global.layoutViewMedia, serverUrl: "", layoutType: global.mediaLayoutRatio)
        var layout = layoutForView.layout
        // Overwrite default value
        if layout == global.layoutList {
            layout = global.mediaLayoutRatio
        }
        //
        let layoutTitle = (layout == global.mediaLayoutRatio) ? NSLocalizedString("_media_square_", comment: "") : NSLocalizedString("_media_ratio_", comment: "")
        let layoutImage = (layout == global.mediaLayoutRatio) ? utility.loadImage(named: "square.grid.3x3") : utility.loadImage(named: "rectangle.grid.3x2")

        let select = UIAction(title: NSLocalizedString("_select_", comment: ""),
                              image: utility.loadImage(named: "checkmark.circle", colors: [NCBrandColor.shared.iconImageColor], size: 24).withTintColor(NCBrandColor.shared.iconImageColor)) { _ in
            media.setEditMode(true)
            Task {
                await media.loadDataSource()
                await media.networkRemoveAll()
                await self.updateMenuOption()
            }
        }
        
        let cancel = UIAction(title: NSLocalizedString("_cancel_", comment: ""),
                              image: utility.loadImage(named: "xmark", colors: [NCBrandColor.shared.iconImageColor], size: 24).withTintColor(NCBrandColor.shared.iconImageColor)) { _ in
            media.setEditMode(false)
            Task {
                await media.loadDataSource()
                await media.networkRemoveAll()
                await self.updateMenuOption()
            }
        }
        
        let viewFilterMenu = UIMenu(title: "", options: [.singleSelection, .displayInline], children: [
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
        UIAction(title: NSLocalizedString("_media_show_all_", comment: ""), image: utility.loadImage(named: "photo.on.rectangle"), state: .on) { _ in
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
                    await self.updateMenuOption()
                    media.collectionViewReloadData()
                }
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
                image: utility.loadImage(named: "checkmark.circle.fill", colors: [NCBrandColor.shared.iconImageColor], size: 24).withTintColor(NCBrandColor.shared.iconImageColor),//, colors: [NCBrandColor.shared.iconImageColor]),
                handler: { _ in
                    if !media.fileSelect.isEmpty, media.dataSource.compactMetadatas.count == media.fileSelect.count {
                        media.fileSelect = []
                    } else {
                        media.fileSelect = media.dataSource.compactMetadatas.compactMap({ $0.ocId })
                    }
                    media.tabBarSelect.selectCount = media.fileSelect.count
                    Task {
                        await media.loadDataSource()
                        await media.networkRemoveAll()
                        await self.updateMenuOption()
                    }
                }
            )
        ])
        
        let actionsInEditMode: [UIAction] = [
            
            UIAction(
                title: NSLocalizedString("_add_to_album", comment: ""),
                image: utility.loadImage(named: "plus", colors: [NCBrandColor.shared.iconImageColor], size: 24).withTintColor(NCBrandColor.shared.iconImageColor),
                handler: { _ in
                    guard let controller = self.controller else { return }
                    NCMediaNavigationController.presentExistingAlbums(presentingController: controller, selectedPhotos: media.fileSelect, account: controller.account)
                }
            ),
            
            UIAction(
                title: NSLocalizedString("_albums_list_new_album_popup_title_", comment: ""),
                image: utility.loadImage(named: "album", colors: [NCBrandColor.shared.iconImageColor], size: 24).withTintColor(NCBrandColor.shared.iconImageColor),
                handler: { _ in
                    guard let controller = self.controller else { return }
                    NCMediaNavigationController.presentInputAlbumNameAlert(on: controller) { albumName in
                        NCMediaNavigationController.createNewAlbum(for: albumName, selectedPhotos: media.fileSelect, controller: controller, account: controller.account)
                    } onCancel: {
                       
                    }
                }
            )
        ]

        let editModeMenu = UIMenu(
            title: "",
            options: .displayInline,
            children: actionsInEditMode
        )
        return UIMenu(title: "", children: !media.isEditMode ? [select, viewFilterMenu, viewLayoutMenu, viewFolderMedia, playFile, playURL] : [cancel, selectAll, editModeMenu])//, playFile, playURL])

//        return UIMenu(title: "", children: [select, viewFilterMenu, viewLayoutMenu, viewFolderMedia, playFile, playURL])
    }
    
    // MARK: - Album related handling
    @objc private func handlePhotosAddedToAlbumNotification(_ notification: Notification) {
        guard let media = topViewController as? NCMedia else { return }
        media.setEditMode(false)
        Task {
            await media.loadDataSource()
            await media.networkRemoveAll()
            await self.updateMenuOption()
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
     
     static private func createNewAlbum(for name: String, selectedPhotos: [String], controller: UIViewController, account: String) {
         
         // Use the provided account to avoid mismatches between UI and networking
         // (Do not rely on AppDelegate.account here)
         
         controller.showLoader()
         NextcloudKit.shared.createNewAlbum(for: account, albumName: name) { result in
             controller.hideLoader()
             switch result {
             case .success(_):
                 AlbumsManager.shared.syncAlbums { resultAlbums in
                     if let newAlbum = resultAlbums.first(where: { $0.name == name }) {
                         if selectedPhotos.isEmpty {
                             showAlbumAndNotify(newAlbum)
                         } else {
                             addPhotosToAlbum(album: newAlbum, selectedPhotos: selectedPhotos, account: account)
                         }
                     } else {
                         // Album not yet visible in the sync result; still notify UI to refresh
                         NotificationCenter.default.post(name: NCMediaNavigationController.photosAddedToAlbumNotification, object: nil)
                     }
                 }
                 
             case .failure(let error):
                 let nkError = NKError(error: error)
                 // Prefer friendly info alert for duplicate album names (409)
                 if let inner = nkError.error as? NKError, inner.errorCode == NCGlobal.shared.errorConflict {
                     let message = NSLocalizedString("_album_already_exists_", comment: "Album already exists")
                     let conflict = NKError(errorCode: NCGlobal.shared.errorConflict, errorDescription: message)
                     NCContentPresenter().showInfo(error: conflict)
                 } else if nkError.errorCode == NCGlobal.shared.errorConflict {
                     // Top-level conflict
                     let message = NSLocalizedString("_album_already_exists_", comment: "Album already exists")
                     let conflict = NKError(errorCode: NCGlobal.shared.errorConflict, errorDescription: message)
                     NCContentPresenter().showInfo(error: conflict)
                 } else {
                     // Other errors
                     NCContentPresenter().showError(error: nkError)
                 }
             }
         }
     }
    
    static func presentExistingAlbums(presentingController: UIViewController,selectedPhotos: [String], account: String) {
        let viewModel = AlbumsListViewModel(account: account)
        let albumListView = AddToAlbumsListView(viewModel: viewModel, localAccount: account, onFinish: { selectedAlbum in
            presentingController.dismiss(animated: true)
            addPhotosToAlbum(album: selectedAlbum, selectedPhotos: selectedPhotos, account: account)
        }, onDismiss: {
            presentingController.dismiss(animated: true)
        }, onCreateAlbum: {
            presentingController.dismiss(animated: true)
            presentInputAlbumNameAlert(on: presentingController) { albumName in
                createNewAlbum(for: albumName, selectedPhotos: selectedPhotos, controller: presentingController, account: account)
            } onCancel: {
               
            }
        })
        
        let hostingController = UIHostingController(rootView: albumListView)
        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        presentingController.present(hostingController, animated: true, completion: nil)
    }
    
    private static func showAlbumAndNotify(_ album: Album) {
        DispatchQueue.main.async {
            // Ensure Albums tab is selected and get its navigation controller
            let nav = ensureAlbumsContextSelectedAndGetNavController()
            // Pop the Albums navigation stack to root (e.g., dashboard) to ensure a clean state
            nav?.popToRootViewController(animated: false)
            // Notify listeners to show the album details
            NotificationCenter.default.post(name: NCMediaNavigationController.showAlbumDetailsNotification, object: album)
            // Let Media UI exit edit mode and refresh
            NotificationCenter.default.post(name: NCMediaNavigationController.photosAddedToAlbumNotification, object: nil)
        }
    }
    
    static func addPhotosToAlbum(album: Album, selectedPhotos: [String], account: String) {
        
        if selectedPhotos.isEmpty {
            showAlbumAndNotify(album)
            return
        }
        
        var completed = 0
        let total = selectedPhotos.count
        func finishIfDone() {
            completed += 1
            if completed >= total {
                AlbumsManager.shared.syncAlbums()
                showAlbumAndNotify(album)
            }
        }
        
        for photo in selectedPhotos {
            
            let metadata: tableMetadata? = NCManageDatabase.shared.getMetadataFromOcId(photo)
            
            NextcloudKit.shared.copyPhotoToAlbum(
                account: account,
                sourcePath: metadata?.serverUrlFileName ?? photo,
                albumName: album.name,
                fileName: metadata?.fileName ?? photo
            ) { result in
                
                switch result {
                case .success:
                    finishIfDone()
                case .failure(let error):
                    let nkError = NKError(error: error)
                    if let innerError = nkError.error as? NKError, innerError.errorCode == NCGlobal.shared.errorConflict {
                        let conflictError = NKError(errorCode: NCGlobal.shared.errorConflict, errorDescription: "_file_already_exists_")
                        NCContentPresenter().showInfo(error: conflictError)
                    } else if nkError.errorCode == NCGlobal.shared.errorConflict {
                        NCContentPresenter().showInfo(error: nkError)
                    } else {
                        NCContentPresenter().showError(error: nkError)
                    }
                    finishIfDone()
                }
            }
            
        }
    }
    
    static func ensureAlbumsContextSelectedAndGetNavController() -> UINavigationController? {
        guard let tabbarController = UIApplication.shared.firstWindow?.rootViewController as? NCMainTabBarController else { return nil }
        tabbarController.selectedIndex = NCGlobal.shared.selectedTabIndexAlbum
        // Try to fetch the selected view controller as a navigation controller
        if let nav = tabbarController.selectedViewController as? UINavigationController {
            return nav
        }
        // Fallback: if the tab bar controller has embedded navigation controllers
        return tabbarController.navigationController ?? tabbarController.selectedViewController?.navigationController
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: Self.photosAddedToAlbumNotification, object: nil)
    }
}
