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

class NCMediaCommandView: UIView {

    @IBOutlet weak var moreView: UIVisualEffectView!
    @IBOutlet weak var gridSwitchButton: UIButton!
    @IBOutlet weak var separatorView: UIView!
    @IBOutlet weak var buttonControlWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var zoomInButton: UIButton!
    @IBOutlet weak var zoomOutButton: UIButton!
    @IBOutlet weak var moreButton: UIButton!
    @IBOutlet weak var controlButtonView: UIVisualEffectView!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    var mediaView: NCMedia?
    private let gradient: CAGradientLayer = CAGradientLayer()

    override func awakeFromNib() {

        moreView.layer.cornerRadius = 20
        moreView.layer.masksToBounds = true

        controlButtonView.layer.cornerRadius = 20
        controlButtonView.layer.masksToBounds = true
        controlButtonView.effect = UIBlurEffect(style: .dark)

        gradient.frame = bounds
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 0, y: 1)
        gradient.colors = [UIColor.black.withAlphaComponent(UIAccessibility.isReduceTransparencyEnabled ? 0.8 : 0.4).cgColor, UIColor.clear.cgColor]
        layer.insertSublayer(gradient, at: 0)

        moreButton.showsMenuAsPrimaryAction = true
        moreButton.changesSelectionAsPrimaryAction = false
        moreButton.setImage(UIImage(named: "more")!.image(color: .white, size: 25), for: .normal)

        createMenu()
    }

    func createMenu() {

        let topAction = UIMenu(title: "", options: .displayInline, children: [
            UIMenu(title: NSLocalizedString("_media_view_options_", comment: ""), children: [
                UIAction(title: NSLocalizedString("_media_viewimage_show_", comment: ""), image: UIImage(systemName: "photo")) { _ in
                    self.mediaView?.showOnlyImages = true
                    self.mediaView?.showOnlyVideos = false
                    self.mediaView?.reloadDataSource()
                },
                UIAction(title: NSLocalizedString("_media_viewvideo_show_", comment: ""), image: UIImage(systemName: "video")) { _ in
                    self.mediaView?.showOnlyImages = false
                    self.mediaView?.showOnlyVideos = true
                    self.mediaView?.reloadDataSource()
                },
                UIAction(title: NSLocalizedString("_media_show_all_", comment: ""), image: UIImage(systemName: "photo.on.rectangle")) { _ in
                    self.mediaView?.showOnlyImages = false
                    self.mediaView?.showOnlyVideos = false
                    self.mediaView?.reloadDataSource()
                }
            ]),
            UIAction(title: NSLocalizedString("_select_media_folder_", comment: ""), image: UIImage(systemName: "folder"), handler: { _ in
                if let navigationController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateInitialViewController() as? UINavigationController,
                   let mediaView = self.mediaView,
                   let viewController = navigationController.topViewController as? NCSelect {
                    viewController.delegate = mediaView
                    viewController.typeOfCommandView = .select
                    viewController.type = "mediaFolder"
                    viewController.selectIndexPath = mediaView.selectIndexPath
                    mediaView.present(navigationController, animated: true, completion: nil)
                }
            })
        ])

        let playFile = UIAction(title: NSLocalizedString("_play_from_files_", comment: ""), image: UIImage(systemName: "play.circle")) { _ in
            if let mediaView = self.mediaView,
               let tabBarController = mediaView.appDelegate.window?.rootViewController as? UITabBarController {
                mediaView.documentPickerViewController = NCDocumentPickerViewController(tabBarController: tabBarController, isViewerMedia: true, allowsMultipleSelection: false, viewController: mediaView)
            }
        }
        let playURL = UIAction(title: NSLocalizedString("_play_from_url_", comment: ""), image: UIImage(systemName: "link")) { _ in
            if let mediaView = self.mediaView {
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
        }

        moreButton.menu = UIMenu(title: "", children: [topAction, playFile, playURL])
    }

    func toggleEmptyView(isEmpty: Bool) {
        if isEmpty {
            UIView.animate(withDuration: 0.3) {
                self.moreView.effect = UIBlurEffect(style: .dark)
                self.gradient.isHidden = true
                self.controlButtonView.isHidden = true
            }
        } else {
            UIView.animate(withDuration: 0.3) {
                self.moreView.effect = UIBlurEffect(style: .dark)
                self.gradient.isHidden = false
                self.controlButtonView.isHidden = false
            }
        }
    }

    @IBAction func zoomInPressed(_ sender: UIButton) {
        mediaView?.zoomInGrid()
    }

    @IBAction func zoomOutPressed(_ sender: UIButton) {
        mediaView?.zoomOutGrid()
    }

    @IBAction func gridSwitchButtonPressed(_ sender: Any) {
        self.collapseControlButtonView(false)
    }

    func collapseControlButtonView(_ collapse: Bool) {
        if collapse {
            self.buttonControlWidthConstraint.constant = 40
            UIView.animate(withDuration: 0.25) {
                self.zoomOutButton.isHidden = true
                self.zoomInButton.isHidden = true
                self.separatorView.isHidden = true
                self.gridSwitchButton.isHidden = false
                self.layoutIfNeeded()
            }
        } else {
            self.buttonControlWidthConstraint.constant = 80
            UIView.animate(withDuration: 0.25) {
                self.zoomOutButton.isHidden = false
                self.zoomInButton.isHidden = false
                self.separatorView.isHidden = false
                self.gridSwitchButton.isHidden = true
                self.layoutIfNeeded()
            }
        }
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return moreView.frame.contains(point) || controlButtonView.frame.contains(point)
    }

    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        gradient.frame = bounds
    }
}
