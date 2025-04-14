//
//  NCMainTabBar.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/01/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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

class NCMainTabBar: UITabBar {
    private var fillColor: UIColor!
    private var shapeLayer: CALayer?
    private let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    private let centerButtonY: CGFloat = -28
    public var color = NCBrandColor.shared.customer

    public var menuRect: CGRect {
        let tabBarItemWidth = Int(self.frame.size.width) / (self.items?.count ?? 0)
        let rect = CGRect(x: 0, y: -5, width: tabBarItemWidth, height: Int(self.frame.size.height))
        return rect
    }

    // MARK: - Life Cycle

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        NotificationCenter.default.addObserver(self, selector: #selector(updateBadgeNumber(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUpdateBadgeNumber), object: nil)

        if let activeTableAccount = NCManageDatabase.shared.getActiveTableAccount() {
            self.color = NCBrandColor.shared.getElement(account: activeTableAccount.account)
            tintColor = color
        }
    }

    override var backgroundColor: UIColor? {
        get {
            return self.fillColor
        }
        set {
            fillColor = newValue
            self.setNeedsDisplay()
        }
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let button = self.viewWithTag(105)
        if self.bounds.contains(point) || (button != nil && button!.frame.contains(point)) {
            return true
        } else {
            return false
        }
    }

    override func draw(_ rect: CGRect) {
        self.subviews.forEach({ $0.removeFromSuperview() })

        addShape()
        createButtons()
    }

    private func addShape() {
        let blurEffect = UIBlurEffect(style: .systemThinMaterial)

        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = self.bounds

        let maskLayer = CAShapeLayer()
        maskLayer.path = createPath()

        blurView.layer.mask = maskLayer

        let border = CALayer()
        border.backgroundColor = UIColor.separator.cgColor
        border.frame = CGRect(x: 0, y: 0, width: blurView.frame.width, height: 0.5)

        blurView.layer.addSublayer(border)

        self.addSubview(blurView)
    }

    private func createPath() -> CGPath {

        let height: CGFloat = 28
        let margin: CGFloat = 6
        let path = UIBezierPath()
        let centerWidth = self.frame.width / 2

        path.move(to: CGPoint(x: 0, y: 0)) // start top left
        path.addLine(to: CGPoint(x: (centerWidth - height - margin), y: 0)) // the beginning of the trough
        // first curve down
        path.addArc(withCenter: CGPoint(x: centerWidth, y: 0), radius: height + margin, startAngle: CGFloat(180 * Double.pi / 180), endAngle: CGFloat(0 * Double.pi / 180), clockwise: false)
        // complete the rect
        path.addLine(to: CGPoint(x: self.frame.width, y: 0))
        path.addLine(to: CGPoint(x: self.frame.width, y: self.frame.height))
        path.addLine(to: CGPoint(x: 0, y: self.frame.height))
        path.close()

        return path.cgPath
    }

    private func createButtons() {

        // File
        if let item = items?[0] {
            item.title = NSLocalizedString("_home_", comment: "")
            item.image = UIImage(systemName: "folder.fill")
            item.selectedImage = item.image
            item.tag = 100
        }

        // Favorite
        if let item = items?[1] {
            item.title = NSLocalizedString("_favorites_", comment: "")
            item.image = UIImage(systemName: "star.fill")
            item.selectedImage = item.image
            item.tag = 101
        }

        // +
        let imagePlus = UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(scale: .large))?.applyingSymbolConfiguration(UIImage.SymbolConfiguration(paletteColors: [.white]))
        if let item = items?[2] {
            item.title = ""
            item.image = nil
            item.isEnabled = false
            item.tag = 102
        }

        // Media
        if let item = items?[3] {
            item.title = NSLocalizedString("_media_", comment: "")
            item.image = UIImage(systemName: "photo")
            item.selectedImage = item.image
            item.tag = 103
        }

        // More
        if let item = items?[4] {
            item.title = NSLocalizedString("_more_", comment: "")
            item.image = UIImage(systemName: "line.3.horizontal")
            item.image = UIImage(systemName: "ellipsis")
            item.selectedImage = item.image
            item.tag = 104
        }

        // Center button

        if let centerButton = self.viewWithTag(105) {
            centerButton.removeFromSuperview()
        }

        let centerButtonHeight: CGFloat = 57
        let centerButton = UIButton(frame: CGRect(x: (self.bounds.width / 2) - (centerButtonHeight / 2), y: centerButtonY, width: centerButtonHeight, height: centerButtonHeight))

        centerButton.setTitle("", for: .normal)
        centerButton.setImage(imagePlus, for: .normal)
        centerButton.backgroundColor = color
        centerButton.tintColor = UIColor.white
        centerButton.tag = 105
        centerButton.accessibilityLabel = NSLocalizedString("_accessibility_add_upload_", comment: "")
        centerButton.layer.cornerRadius = centerButton.frame.size.width / 2.0
        centerButton.layer.masksToBounds = false
        centerButton.layer.shadowOffset = CGSize(width: 0, height: 0)
        centerButton.layer.shadowRadius = 3.0
        centerButton.layer.shadowOpacity = 0.5
        centerButton.action(for: .touchUpInside) { _ in
            if let controller = self.window?.rootViewController as? NCMainTabBarController {
                let serverUrl = controller.currentServerUrl()
                if let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", NCSession.shared.getSession(controller: controller).account, serverUrl)) {
                    if !directory.permissions.contains("CK") {
                        let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_add_file_")
                        NCContentPresenter().showWarning(error: error)
                        return
                    }
                }

                let fileFolderPath = NCUtilityFileSystem().getFileNamePath("", serverUrl: serverUrl, session: NCSession.shared.getSession(controller: controller))
                let fileFolderName = (serverUrl as NSString).lastPathComponent

                if !FileNameValidator.checkFolderPath(fileFolderPath, account: controller.account) {
                    controller.present(UIAlertController.warning(message: "\(String(format: NSLocalizedString("_file_name_validator_error_reserved_name_", comment: ""), fileFolderName)) \(NSLocalizedString("_please_rename_file_", comment: ""))"), animated: true)

                    return
                }

                self.appDelegate.toggleMenu(controller: controller)
            }
        }

        self.addSubview(centerButton)
    }

    @objc func updateBadgeNumber(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let counterDownload = userInfo["counterDownload"] as? Int,
              let counterUpload = userInfo["counterUpload"] as? Int
            else { return }

        self.updateBadgeNumberUI(counterDownload: counterDownload, counterUpload: counterUpload)
    }

    func updateBadgeNumberUI(counterDownload: Int, counterUpload: Int) {
        UIApplication.shared.applicationIconBadgeNumber = counterDownload + counterUpload

        if let item = self.items?[0] {
            if counterDownload == 0, counterUpload == 0 {
                item.badgeValue = nil
            } else if counterDownload > 0, counterUpload == 0 {
                let badgeValue = String("↓ \(counterDownload)")
                item.badgeValue = badgeValue
            } else if counterDownload == 0, counterUpload > 0 {
                let badgeValue = String("↑ \(counterUpload)")
                item.badgeValue = badgeValue
            } else {
                let badgeValueDownload = String("↓ \(counterDownload)")
                let badgeValueUpload = String("↑ \(counterUpload)")
                item.badgeValue = badgeValueDownload + " " + badgeValueUpload
            }
        }
    }

    func getCenterButton() -> UIView? {
        if let centerButton = self.viewWithTag(105) {
            return centerButton
        } else {
            return nil
        }
    }

    func getHeight() -> CGFloat {
        return (frame.size.height - centerButtonY)
    }
}
