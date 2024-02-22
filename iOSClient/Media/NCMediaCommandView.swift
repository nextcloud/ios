//
//  NCMediaCommandView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 25/01/24.
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

import UIKit
import NextcloudKit

class NCMediaCommandView: UIView {

    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var activityIndicatorTrailing: NSLayoutConstraint!
    @IBOutlet weak var selectOrCancelButton: UIButton!
    @IBOutlet weak var selectOrCancelButtonTrailing: NSLayoutConstraint!
    @IBOutlet weak var menuButton: UIButton!

    var mediaView: NCMedia!
    var tabBarController: UITabBarController?
    var attributesZoomIn: UIMenuElement.Attributes = []
    var attributesZoomOut: UIMenuElement.Attributes = []
    let gradient: CAGradientLayer = CAGradientLayer()

    override func awakeFromNib() {
        super.awakeFromNib()

        title.text = ""

        selectOrCancelButton.backgroundColor = nil
        selectOrCancelButton.layer.cornerRadius = 15
        selectOrCancelButton.layer.masksToBounds = true
        selectOrCancelButton.setTitle( NSLocalizedString("_select_", comment: ""), for: .normal)
        selectOrCancelButton.addBlur(style: .systemThinMaterial)

        menuButton.backgroundColor = nil
        menuButton.layer.cornerRadius = 15
        menuButton.layer.masksToBounds = true
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.configuration = UIButton.Configuration.plain()
        menuButton.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        menuButton.changesSelectionAsPrimaryAction = false
        menuButton.addBlur(style: .systemThinMaterial)

        gradient.frame = bounds
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 0, y: 1)
        gradient.colors = [UIColor.black.withAlphaComponent(UIAccessibility.isReduceTransparencyEnabled ? 0.8 : 0.4).cgColor, UIColor.clear.cgColor]
        layer.insertSublayer(gradient, at: 0)
    }

    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        gradient.frame = bounds
    }

    @IBAction func selectOrCancelButtonPressed(_ sender: UIButton) {
        mediaView.isEditMode = !mediaView.isEditMode
        setSelectcancelButton()
    }

    func setSelectcancelButton() {
        mediaView.selectOcId.removeAll()
        mediaView.tabBarSelect?.selectCount = mediaView.selectOcId.count

        if mediaView.isEditMode {
            selectOrCancelButton.setTitle( NSLocalizedString("_cancel_", comment: ""), for: .normal)
            selectOrCancelButtonTrailing.constant = 8
            mediaView.tabBarSelect?.show()
        } else {
            selectOrCancelButton.setTitle( NSLocalizedString("_select_", comment: ""), for: .normal)
            selectOrCancelButtonTrailing.constant = 46
            mediaView.tabBarSelect?.hide()
        }

        mediaView.collectionView.reloadData()
    }

    func setTitleDate(_ offset: CGFloat = 10) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.title.text = ""
            let top = self.mediaView.insetsTop + self.mediaView.view.safeAreaInsets.top + offset
            if let collectionView = self.mediaView.collectionView {
                let point = CGPoint(x: offset, y: top + collectionView.contentOffset.y)
                if let indexPath = collectionView.indexPathForItem(at: point) {
                    let cell = self.mediaView.collectionView(collectionView, cellForItemAt: indexPath) as? NCGridMediaCell
                    if let date = cell?.fileDate {
                        self.title.text = self.mediaView.utility.getTitleFromDate(date)
                    }
                } else {
                    if offset < 20 {
                        self.setTitleDate(20)
                    } else {
                        print("no indexPath found")
                    }
                }
            }
        }
    }

    func setColor(isTop: Bool) {
        if isTop {
            title.textColor = .label
            activityIndicator.color = .label
            selectOrCancelButton.setTitleColor(.label, for: .normal)
            menuButton.setImage(UIImage(systemName: "ellipsis")?.withTintColor(.label, renderingMode: .alwaysOriginal), for: .normal)
            gradient.isHidden = true
        } else {
            title.textColor = .white
            activityIndicator.color = .white
            selectOrCancelButton.setTitleColor(.white, for: .normal)
            menuButton.setImage(UIImage(systemName: "ellipsis")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
            gradient.isHidden = false
        }
    }

    func createMenu() {
        var itemForLine = 0

        if let layout = (mediaView.collectionView.collectionViewLayout as? NCMediaDynamicLayout) {
            itemForLine = layout.itemForLine
        } else if let layout = (mediaView.collectionView.collectionViewLayout as? NCMediaGridLayout) {
            itemForLine = Int(layout.itemForLine)
        }

        if let maxImageGrid = mediaView?.maxImageGrid {
            if CGFloat(itemForLine) >= maxImageGrid - 1 {
                self.attributesZoomIn = []
                self.attributesZoomOut = .disabled
            } else if itemForLine <= 1 {
                self.attributesZoomIn = .disabled
                self.attributesZoomOut = []
            } else {
                self.attributesZoomIn = []
                self.attributesZoomOut = []
            }
        }

        let topAction = UIMenu(title: "", options: .displayInline, children: [
            UIMenu(title: NSLocalizedString("_zoom_", comment: ""), children: [
                UIAction(title: NSLocalizedString("_zoom_out_", comment: ""), image: UIImage(systemName: "minus.magnifyingglass"), attributes: self.attributesZoomOut) { _ in
                    guard let mediaView = self.mediaView else { return }
                    UIView.animate(withDuration: 0.0, animations: {
                        let newItemForLine = itemForLine + 2
                        if let layout = (mediaView.collectionView.collectionViewLayout as? NCMediaDynamicLayout) {
                            layout.itemForLine = newItemForLine
                        } else if let layout = (mediaView.collectionView.collectionViewLayout as? NCMediaGridLayout) {
                            layout.itemForLine = newItemForLine
                        }
                        self.createMenu()
                        mediaView.collectionView.collectionViewLayout.invalidateLayout()
                        NCKeychain().mediaItemForLine = newItemForLine
                    })
                },
                UIAction(title: NSLocalizedString("_zoom_in_", comment: ""), image: UIImage(systemName: "plus.magnifyingglass"), attributes: self.attributesZoomIn) { _ in
                    UIView.animate(withDuration: 0.0, animations: {
                        guard let mediaView = self.mediaView else { return }
                        let newItemForLine = itemForLine - 2
                        if let layout = (mediaView.collectionView.collectionViewLayout as? NCMediaDynamicLayout) {
                            layout.itemForLine = newItemForLine
                        } else if let layout = (mediaView.collectionView.collectionViewLayout as? NCMediaGridLayout) {
                            layout.itemForLine = newItemForLine
                        }
                        self.createMenu()
                        self.mediaView.collectionView.collectionViewLayout.invalidateLayout()
                        NCKeychain().mediaItemForLine = newItemForLine
                    })
                }
            ]),
            UIMenu(title: NSLocalizedString("_media_view_options_", comment: ""), children: [
                UIAction(title: NSLocalizedString("_media_viewimage_show_", comment: ""), image: UIImage(systemName: "photo")) { _ in
                    self.mediaView.showOnlyImages = true
                    self.mediaView.showOnlyVideos = false
                    self.mediaView.reloadDataSource()
                },
                UIAction(title: NSLocalizedString("_media_viewvideo_show_", comment: ""), image: UIImage(systemName: "video")) { _ in
                    self.mediaView.showOnlyImages = false
                    self.mediaView.showOnlyVideos = true
                    self.mediaView.reloadDataSource()
                },
                UIAction(title: NSLocalizedString("_media_show_all_", comment: ""), image: UIImage(systemName: "photo.on.rectangle")) { _ in
                    self.mediaView.showOnlyImages = false
                    self.mediaView.showOnlyVideos = false
                    self.mediaView.reloadDataSource()
                }
            ]),
            UIAction(title: NSLocalizedString("_select_media_folder_", comment: ""), image: UIImage(systemName: "folder"), handler: { _ in
                guard let navigationController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateInitialViewController() as? UINavigationController,
                      let viewController = navigationController.topViewController as? NCSelect else { return }
                viewController.delegate = self.mediaView
                viewController.typeOfCommandView = .select
                viewController.type = "mediaFolder"
                self.mediaView.present(navigationController, animated: true, completion: nil)
            })
        ])

        let playFile = UIAction(title: NSLocalizedString("_play_from_files_", comment: ""), image: UIImage(systemName: "play.circle")) { _ in
            guard let tabBarController = self.mediaView.appDelegate.window?.rootViewController as? UITabBarController else { return }
            self.mediaView.documentPickerViewController = NCDocumentPickerViewController(tabBarController: tabBarController, isViewerMedia: true, allowsMultipleSelection: false, viewController: self.mediaView)
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
                let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
                let metadata = NCManageDatabase.shared.createMetadata(account: appDelegate.account, user: appDelegate.user, userId: appDelegate.userId, fileName: fileName, fileNameView: fileName, ocId: NSUUID().uuidString, serverUrl: "", urlBase: appDelegate.urlBase, url: stringUrl, contentType: "")
                NCManageDatabase.shared.addMetadata(metadata)
                NCViewer().view(viewController: self.mediaView, metadata: metadata, metadatas: [metadata], imageIcon: nil)
            }))
            self.mediaView.present(alert, animated: true)
        }

        menuButton.menu = UIMenu(title: "", children: [topAction, playFile, playURL])
    }
}

// MARK: - NCMediaTabBarSelectDelegate

extension NCMediaCommandView: NCMediaSelectTabBarDelegate {
    func delete() {
        if !mediaView.selectOcId.isEmpty {
            let selectOcId = mediaView.selectOcId
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

                self.mediaView.isEditMode = false
                self.setSelectcancelButton()
            })
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .default) { (_: UIAlertAction) in })

            mediaView.present(alertController, animated: true, completion: { })
        }
    }
}
