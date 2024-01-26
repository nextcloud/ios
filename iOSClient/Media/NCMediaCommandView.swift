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
    @IBOutlet weak var selectButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var moreButton: UIButton!

    var mediaView: NCMedia?
    var attributesZoomIn: UIMenuElement.Attributes = []
    var attributesZoomOut: UIMenuElement.Attributes = []
    private let gradient: CAGradientLayer = CAGradientLayer()

    override func awakeFromNib() {

        title.text = ""

        selectButton.backgroundColor = .systemGray4.withAlphaComponent(0.6)
        selectButton.layer.cornerRadius = 15
        selectButton.layer.masksToBounds = true
        selectButton.setTitle( NSLocalizedString("_select_", comment: ""), for: .normal)

        moreButton.changesSelectionAsPrimaryAction = false
        setMoreButton()

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

    @IBAction func selectButtonPressed(_ sender: UIButton) {
        if let mediaView = self.mediaView {
            if mediaView.isEditMode {
                setMoreButton()
            } else {
                setMoreButtonDelete()
            }
        }
    }

    @IBAction func trashButtonPressed(_ sender: UIButton) {

        if let mediaView = self.mediaView,
           !mediaView.selectOcId.isEmpty {
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

                self.setMoreButton()

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
            })
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_delete_", comment: ""), style: .default) { (_: UIAlertAction) in })

            mediaView.present(alertController, animated: true, completion: { })
        }
    }

    func setMoreButton() {

        moreButton.backgroundColor = .systemGray4.withAlphaComponent(0.6)
        moreButton.layer.cornerRadius = 15
        moreButton.layer.masksToBounds = true
        moreButton.showsMenuAsPrimaryAction = true
        moreButton.configuration = UIButton.Configuration.plain()
        let image = UIImage(systemName: "ellipsis")
        moreButton.setImage(image, for: .normal)

        mediaView?.isEditMode = false
        mediaView?.selectOcId.removeAll()
        mediaView?.collectionView?.reloadData()

        selectButton.setTitle( NSLocalizedString("_select_", comment: ""), for: .normal)
    }

    func setMoreButtonDelete() {

        moreButton.backgroundColor = .clear
        moreButton.showsMenuAsPrimaryAction = false
        moreButton.configuration = UIButton.Configuration.plain()
        let image = UIImage(systemName: "trash.circle", withConfiguration: UIImage.SymbolConfiguration(pointSize: 25))?.withTintColor(.red, renderingMode: .alwaysOriginal)
        moreButton.setImage(image, for: .normal)

        mediaView?.isEditMode = true

        selectButton.setTitle( NSLocalizedString("_cancel_", comment: ""), for: .normal)
    }

    func createMenu() {

        if let itemForLine = mediaView?.gridLayout.itemForLine, let maxImageGrid = mediaView?.maxImageGrid {
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
                        mediaView.gridLayout.itemForLine += 1
                        self.createMenu()
                        mediaView.collectionView.collectionViewLayout.invalidateLayout()
                        NCKeychain().mediaWidthImage = Int(mediaView.gridLayout.itemForLine)
                    })
                },
                UIAction(title: NSLocalizedString("_zoom_in_", comment: ""), image: UIImage(systemName: "plus.magnifyingglass"), attributes: self.attributesZoomIn) { _ in
                    guard let mediaView = self.mediaView else { return }
                    UIView.animate(withDuration: 0.0, animations: {
                        mediaView.gridLayout.itemForLine -= 1
                        self.createMenu()
                        mediaView.collectionView.collectionViewLayout.invalidateLayout()
                        NCKeychain().mediaWidthImage = Int(mediaView.gridLayout.itemForLine)
                    })
                }
            ]),
            UIMenu(title: NSLocalizedString("_media_view_options_", comment: ""), children: [
                UIAction(title: NSLocalizedString("_media_viewimage_show_", comment: ""), image: UIImage(systemName: "photo")) { _ in
                    guard let mediaView = self.mediaView else { return }
                    mediaView.showOnlyImages = true
                    mediaView.showOnlyVideos = false
                    mediaView.reloadDataSource()
                },
                UIAction(title: NSLocalizedString("_media_viewvideo_show_", comment: ""), image: UIImage(systemName: "video")) { _ in
                    guard let mediaView = self.mediaView else { return }
                    mediaView.showOnlyImages = false
                    mediaView.showOnlyVideos = true
                    mediaView.reloadDataSource()
                },
                UIAction(title: NSLocalizedString("_media_show_all_", comment: ""), image: UIImage(systemName: "photo.on.rectangle")) { _ in
                    guard let mediaView = self.mediaView else { return }
                    mediaView.showOnlyImages = false
                    mediaView.showOnlyVideos = false
                    mediaView.reloadDataSource()
                }
            ]),
            UIAction(title: NSLocalizedString("_select_media_folder_", comment: ""), image: UIImage(systemName: "folder"), handler: { _ in
                guard let mediaView = self.mediaView,
                      let navigationController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateInitialViewController() as? UINavigationController,
                      let viewController = navigationController.topViewController as? NCSelect else { return }
                viewController.delegate = mediaView
                viewController.typeOfCommandView = .select
                viewController.type = "mediaFolder"
                mediaView.present(navigationController, animated: true, completion: nil)
            })
        ])

        let playFile = UIAction(title: NSLocalizedString("_play_from_files_", comment: ""), image: UIImage(systemName: "play.circle")) { _ in
            guard let mediaView = self.mediaView,
                  let tabBarController = mediaView.appDelegate.window?.rootViewController as? UITabBarController else { return }
            mediaView.documentPickerViewController = NCDocumentPickerViewController(tabBarController: tabBarController, isViewerMedia: true, allowsMultipleSelection: false, viewController: mediaView)
        }
        let playURL = UIAction(title: NSLocalizedString("_play_from_url_", comment: ""), image: UIImage(systemName: "link")) { _ in
            guard let mediaView = self.mediaView else { return }
            let alert = UIAlertController(title: NSLocalizedString("_valid_video_url_", comment: ""), message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: nil))
            alert.addTextField(configurationHandler: { textField in
                textField.placeholder = "http://myserver.com/movie.mkv"
            })
            alert.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in
                guard let stringUrl = alert.textFields?.first?.text, !stringUrl.isEmpty, let url = URL(string: stringUrl) else { return }
                let fileName = url.lastPathComponent
                let metadata = NCManageDatabase.shared.createMetadata(account: mediaView.appDelegate.account, user: mediaView.appDelegate.user, userId: mediaView.appDelegate.userId, fileName: fileName, fileNameView: fileName, ocId: NSUUID().uuidString, serverUrl: "", urlBase: mediaView.appDelegate.urlBase, url: stringUrl, contentType: "")
                NCManageDatabase.shared.addMetadata(metadata)
                NCViewer().view(viewController: mediaView, metadata: metadata, metadatas: [metadata], imageIcon: nil)
            }))
            mediaView.present(alert, animated: true)
        }

        moreButton.menu = UIMenu(title: "", children: [topAction, playFile, playURL])
    }

    func toggleEmptyView(isEmpty: Bool) {
        if isEmpty {
            UIView.animate(withDuration: 0.3) {
                self.gradient.isHidden = true
            }
        } else {
            UIView.animate(withDuration: 0.3) {
                self.gradient.isHidden = false
            }
        }
    }
}
