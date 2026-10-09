// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

/// Shares the app's navigation appearance and sidebar behavior with Files and Media.
class NCAlbumsNavigationController: NCMainNavigationController {
    override func collectionViewCommonTrailingItemGroups() async {
        // Album screens provide their own creation and editing actions.
        guard !(topViewController is AlbumsViewController) else { return }
        await super.collectionViewCommonTrailingItemGroups()
    }

    static func configureNavigationItems(for screen: AlbumsViewController) {
        let item = screen.navigationItem
        item.largeTitleDisplayMode = .never
        if let viewModel = screen.listViewModel {
            screen.title = NSLocalizedString("_albums_list_nav_title_", comment: "")
            item.rightBarButtonItem = UIBarButtonItem(
                title: NSLocalizedString("_albums_list_new_album_btn_", comment: ""),
                image: UIImage(systemName: "plus"),
                primaryAction: UIAction { [weak viewModel] _ in viewModel?.onNewAlbumClick() }
            )
        } else if let viewModel = screen.detailsViewModel {
            screen.title = viewModel.screenTitle
            guard !viewModel.isLoading else {
                item.rightBarButtonItems = nil
                return
            }
            let add = UIBarButtonItem(
                title: NSLocalizedString("_albums_photos_add_photos_btn_", comment: ""),
                image: UIImage(systemName: "plus"),
                primaryAction: UIAction { [weak viewModel] _ in viewModel?.onAddPhotosIntent() }
            )
            let rename = UIAction(
                title: NSLocalizedString("_albums_photos_rename_album_btn_", comment: ""),
                image: UIImage(systemName: "pencil")
            ) { [weak viewModel] _ in viewModel?.onRenameAlbumIntent() }
            let delete = UIAction(
                title: NSLocalizedString("_albums_photos_delete_album_btn_", comment: ""),
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak viewModel] _ in viewModel?.onDeleteAlbumIntent() }
            let options = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: UIMenu(children: [rename, delete]))
            options.tintColor = NCBrandColor.shared.iconImageColor
            item.rightBarButtonItems = [options, add]
        }
    }
}
