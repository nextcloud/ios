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
    @IBOutlet weak var selectcancelButton: UIButton!
    @IBOutlet weak var selectcancelButtonTrailing: NSLayoutConstraint!
    @IBOutlet weak var menuButton: UIButton!

    var mediaView: NCMedia!
    var tabBarController: UITabBarController?
    var attributesZoomIn: UIMenuElement.Attributes = []
    var attributesZoomOut: UIMenuElement.Attributes = []
    let gradient: CAGradientLayer = CAGradientLayer()

    override func awakeFromNib() {
        super.awakeFromNib()

        title.text = ""

        selectcancelButton.backgroundColor = .systemGray4.withAlphaComponent(0.6)
        selectcancelButton.layer.cornerRadius = 15
        selectcancelButton.layer.masksToBounds = true
        selectcancelButton.setTitle( NSLocalizedString("_select_", comment: ""), for: .normal)

        menuButton.backgroundColor = .systemGray4.withAlphaComponent(0.6)
        menuButton.layer.cornerRadius = 15
        menuButton.layer.masksToBounds = true
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.configuration = UIButton.Configuration.plain()
        menuButton.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        menuButton.changesSelectionAsPrimaryAction = false

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

    @IBAction func selectcancelButtonPressed(_ sender: UIButton) {

        mediaView.isEditMode = !mediaView.isEditMode
        setSelectcancelButton()
    }

    func setSelectcancelButton() {

        mediaView.selectOcId.removeAll()
        mediaView.tabBarSelect?.selectCount = mediaView.selectOcId.count

        if mediaView.isEditMode {
            selectcancelButton.setTitle( NSLocalizedString("_cancel_", comment: ""), for: .normal)
            selectcancelButtonTrailing.constant = 8
            mediaView.tabBarSelect?.show(animation: true)
        } else {
            selectcancelButton.setTitle( NSLocalizedString("_select_", comment: ""), for: .normal)
            selectcancelButtonTrailing.constant = 46
            mediaView.tabBarSelect?.hide(animation: true)
        }

        mediaView.collectionView.reloadData()
    }

    func setTitleDate() {

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.title.text = ""
            if let visibleCells = self.mediaView.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row }).compactMap({ self.mediaView.collectionView?.cellForItem(at: $0) }) {
                if let cell = visibleCells.first as? NCGridMediaCell {
                    self.title.text = ""
                    if let date = cell.date {
                        self.title.text = self.mediaView.utility.getTitleFromDate(date)
                    }
                }
            }
        }
    }

    func setColor(isTop: Bool) {

        if isTop {
            title.textColor = .label
            activityIndicator.color = .label
            selectcancelButton.setTitleColor(.label, for: .normal)
            menuButton.setImage(UIImage(systemName: "ellipsis")?.withTintColor(.label, renderingMode: .alwaysOriginal), for: .normal)
            gradient.isHidden = true
        } else {
            title.textColor = .white
            activityIndicator.color = .white
            selectcancelButton.setTitleColor(.white, for: .normal)
            menuButton.setImage(UIImage(systemName: "ellipsis")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
            gradient.isHidden = false
        }
    }

    func createMenu() {

        if let itemForLine = mediaView?.layout.itemForLine, let maxImageGrid = mediaView?.maxImageGrid {
            if itemForLine >= maxImageGrid - 1 {
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
                        mediaView.layout.itemForLine += 1
                        self.createMenu()
                        mediaView.collectionView.collectionViewLayout.invalidateLayout()
                        NCKeychain().mediaItemForLine = Int(mediaView.layout.itemForLine)
                    })
                },
                UIAction(title: NSLocalizedString("_zoom_in_", comment: ""), image: UIImage(systemName: "plus.magnifyingglass"), attributes: self.attributesZoomIn) { _ in
                    UIView.animate(withDuration: 0.0, animations: {
                        self.mediaView.layout.itemForLine -= 1
                        self.createMenu()
                        self.mediaView.collectionView.collectionViewLayout.invalidateLayout()
                        NCKeychain().mediaItemForLine = Int(self.mediaView.layout.itemForLine)
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

// MARK: - NCTabBarSelectDelegate

extension NCMediaCommandView: NCTabBarSelectDelegate {

    func delete() {

        if !mediaView.selectOcId.isEmpty {
            let selectOcId = mediaView.selectOcId
            var title = NSLocalizedString("_delete_", comment: "")
            if selectOcId.count > 1 {
                title = NSLocalizedString("_delete_selected_files_", comment: "")
            }
            let alertController = UIAlertController(
                title: title,
                message: "",
                preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_delete_", comment: ""), style: .default) { (_: UIAlertAction) in

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
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_delete_", comment: ""), style: .default) { (_: UIAlertAction) in })

            mediaView.present(alertController, animated: true, completion: { })
        }
    }
}
