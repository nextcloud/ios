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

    public var menuRect: CGRect {
        let tabBarItemWidth = Int(self.frame.size.width) / (self.items?.count ?? 0)
        let rect = CGRect(x: 0, y: -5, width: tabBarItemWidth, height: Int(self.frame.size.height))
        return rect
    }

    // MARK: - Life Cycle

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        appDelegate.mainTabBar = self

        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil)

        let timerNotificationCenter = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateBadgeNumber), userInfo: nil, repeats: true)

        barTintColor = .secondarySystemBackground
        backgroundColor = .secondarySystemBackground

        changeTheming()
    }

    @objc func changeTheming() {
        tintColor = NCBrandColor.shared.brandElement
        if let centerButton = self.viewWithTag(99) {
            centerButton.backgroundColor = NCBrandColor.shared.brandElement
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
        let button = self.viewWithTag(99)
        if self.bounds.contains(point) || (button != nil && button!.frame.contains(point)) {
            return true
        } else {
            return false
        }
    }

//    override func viewWillLayoutSubviews() {
//
//        if let tabBar = self.tabBar as? CustomTabBar {

//            let maskLayer = CAShapeLayer()
//            maskLayer.path = tabBar.createPath()
//            maskLayer.fillRule = .evenOdd
//
//            let blurEffect = UIBlurEffect(style: .light)
//            let blurEffectView = UIVisualEffectView(effect: blurEffect)
//            blurEffectView.frame = self.tabBar.frame
//            blurEffectView.layer.mask = maskLayer
//
//            addSubview(blurEffectView)
//            bringSubviewToFront(tabBar)
//        }
//    }


    override func layoutSubviews() {
        super.layoutSubviews()

//        layer.shadowPath = createPath()
//        layer.shadowRadius = 5
//        layer.shadowOffset = .zero
//        layer.shadowOpacity = 0.25

//        let maskLayer = CAShapeLayer()
//        maskLayer.path = createPath()
//        maskLayer.fillRule = .evenOdd
//
//        let blurEffect = UIBlurEffect(style: .light)
//        let blurEffectView = UIVisualEffectView(effect: blurEffect)
//        blurEffectView.frame = frame
//        blurEffectView.layer.mask = maskLayer

//        addSubview(blurEffectView)
//        bringSubviewToFront(self)
    }

    override func draw(_ rect: CGRect) {
//        addShape()
//        createButtons()
    }

    private func addShape() {

//        let shapeLayer = CAShapeLayer()
//        shapeLayer.path = createPath()
//        shapeLayer.fillColor = backgroundColor?.cgColor
//        shapeLayer.strokeColor = UIColor.clear.cgColor
//
//        if let oldShapeLayer = self.shapeLayer {
//            self.layer.replaceSublayer(oldShapeLayer, with: shapeLayer)
//        } else {
//            self.layer.insertSublayer(shapeLayer, at: 0)
//        }

//        let maskLayer = CAShapeLayer()
//        maskLayer.path = createPath()
//        maskLayer.fillRule = .evenOdd
//
//        let blurEffect = UIBlurEffect(style: .light)
//        let blurEffectView = UIVisualEffectView(effect: blurEffect)
////        blurEffectView.frame = self.tabBar.frame
//        blurEffectView.layer.mask = maskLayer
//
//        addSubview(blurEffectView)
//        bringSubviewToFront(tabBar)

//        var blur: UIView!
//        blur = UIVisualEffectView (effect: UIBlurEffect (style: .light))
//        blur.frame = frame
//
//        let maskLayer = CAShapeLayer()
//        maskLayer.path = createPath()
//        maskLayer.fillRule = .evenOdd
//
//        let borderLayer = CAShapeLayer()
//        borderLayer.path = createPath()
//        borderLayer.strokeColor = UIColor.white.cgColor
//        borderLayer.fillColor = UIColor.clear.cgColor //Remember this line, it caused me some issues
//        borderLayer.lineWidth = 10
//
//        let maskView = UIView(frame: frame)
//        maskView.backgroundColor = UIColor.black
//        maskView.layer.mask = maskLayer
//
//        blur.layer.addSublayer(borderLayer)
//        blur.mask = maskView
//
//        self.shapeLayer = maskLayer

//        private func addBlurEffect() {
            // Create a UIBlurEffect
            let blurEffect = UIBlurEffect(style: .systemMaterial)

            // Create a UIVisualEffectView with the UIBlurEffect
            let blurView = UIVisualEffectView(effect: blurEffect)
            blurView.frame = self.bounds

            // Create your shape layer (reuse your existing method)
            let maskLayer = CAShapeLayer()
            maskLayer.path = createPath()

            // Set the mask of the blurView's layer to be the shape layer
            blurView.layer.mask = maskLayer

            // Add the blurView to your view hierarchy
            self.addSubview(blurView)
//        }
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
            item.image = UIImage(named: "tabBarFiles")?.image(color: NCBrandColor.shared.brandElement, size: 25)
            item.selectedImage = item.image
        }

        // Favorite
        if let item = items?[1] {
            item.title = NSLocalizedString("_favorites_", comment: "")
            item.image = UIImage(named: "star.fill")?.image(color: NCBrandColor.shared.brandElement, size: 25)
            item.selectedImage = item.image
        }

        // +
        if let item = items?[2] {
            item.title = ""
            item.image = nil
            item.isEnabled = false
        }

        // Media
        if let item = items?[3] {
            item.title = NSLocalizedString("_media_", comment: "")
            item.image = UIImage(named: "media")?.image(color: NCBrandColor.shared.brandElement, size: 25)
            item.selectedImage = item.image
        }

        // More
        if let item = items?[4] {
            item.title = NSLocalizedString("_more_", comment: "")
            item.image = UIImage(named: "tabBarMore")?.image(color: NCBrandColor.shared.brandElement, size: 25)
            item.selectedImage = item.image
        }

        // Center button

        if let centerButton = self.viewWithTag(99) {
            centerButton.removeFromSuperview()
        }

        let centerButtonHeight: CGFloat = 57
        let centerButton = UIButton(frame: CGRect(x: (self.bounds.width / 2) - (centerButtonHeight / 2), y: centerButtonY, width: centerButtonHeight, height: centerButtonHeight))

        centerButton.setTitle("", for: .normal)
        centerButton.setImage(UIImage(named: "tabBarPlus")?.image(color: .white, size: 100), for: .normal)
        centerButton.backgroundColor = NCBrandColor.shared.brandElement
        centerButton.tintColor = UIColor.white
        centerButton.tag = 99
        centerButton.accessibilityLabel = NSLocalizedString("_accessibility_add_upload_", comment: "")
        centerButton.layer.cornerRadius = centerButton.frame.size.width / 2.0
        centerButton.layer.masksToBounds = false
        centerButton.layer.shadowOffset = CGSize(width: 0, height: 0)
        centerButton.layer.shadowRadius = 3.0
        centerButton.layer.shadowOpacity = 0.5
        centerButton.action(for: .touchUpInside) { _ in

            if let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, self.appDelegate.activeServerUrl)) {

                if !directory.permissions.contains("CK") {
                    let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_add_file_")
                    NCContentPresenter().showWarning(error: error)
                    return
                }
            }

            if let viewController = self.window?.rootViewController {
                self.appDelegate.toggleMenu(viewController: viewController)
            }
        }

        self.addSubview(centerButton)
    }

    @objc func updateBadgeNumber() {

        var counterDownload = 0
        var counterUpload = 0

        if let results = NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "status < 0")) {
            counterDownload = results.count
        }
        if let results = NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "status > 0")) {
            counterUpload = results.count
        }

        UIApplication.shared.applicationIconBadgeNumber = counterUpload
        if let item = self.items?[0] {
            if counterDownload == 0, counterUpload == 0 {
                item.badgeValue = nil
            } else if counterDownload > 0, counterUpload == 0 {
                var badgeValue = String("↓ \(counterDownload)")
                if counterDownload >= NCBrandOptions.shared.maxConcurrentOperationDownload {
                    badgeValue = String("↓ \(NCBrandOptions.shared.maxConcurrentOperationDownload)+")
                }
                item.badgeValue = badgeValue
            } else if counterDownload == 0, counterUpload > 0 {
                var badgeValue = String("↑ \(counterUpload)")
                if counterUpload >= NCBrandOptions.shared.maxConcurrentOperationUpload {
                    badgeValue = String("↑ \(NCBrandOptions.shared.maxConcurrentOperationUpload)+")
                }
                item.badgeValue = badgeValue
            } else {
                var badgeValueDownload = String("↓ \(counterDownload)")
                if counterDownload >= NCBrandOptions.shared.maxConcurrentOperationDownload {
                    badgeValueDownload = String("↓ \(NCBrandOptions.shared.maxConcurrentOperationDownload)+")
                }
                var badgeValueUpload = String("↑ \(counterUpload)")
                if counterUpload >= NCBrandOptions.shared.maxConcurrentOperationUpload {
                    badgeValueUpload = String("↑ \(NCBrandOptions.shared.maxConcurrentOperationUpload)+")
                }
                item.badgeValue = badgeValueDownload + " " + badgeValueUpload
            }
        }
    }

    func getCenterButton() -> UIView? {
        if let centerButton = self.viewWithTag(99) {
            return centerButton
        } else {
            return nil
        }
    }

    func getHeight() -> CGFloat {
        return (frame.size.height - centerButtonY)
    }
}
