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

import Foundation

@IBDesignable class NCMainTabBar: UITabBar {

    private var fillColor: UIColor!
    private var shapeLayer: CALayer?
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    override var traitCollection: UITraitCollection {
        return UITraitCollection(horizontalSizeClass: .compact)
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

    override func layoutSubviews() {
        
        super.layoutSubviews()
        layer.shadowPath = createPath()
        layer.shadowRadius = 5
        layer.shadowOffset = .zero
        layer.shadowOpacity = 0.25
    }

    override func draw(_ rect: CGRect) {
        addShape()
        createButtons()
    }

    private func addShape() {
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = createPath()
        shapeLayer.fillColor = backgroundColor?.cgColor

        if let oldShapeLayer = self.shapeLayer {
            self.layer.replaceSublayer(oldShapeLayer, with: shapeLayer)
        } else {
            self.layer.insertSublayer(shapeLayer, at: 0)
        }

        self.shapeLayer = shapeLayer
    }
    
    private func createPath() -> CGPath {
        
        let height: CGFloat = 28
        let margin: CGFloat = 8
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
        if let item = items?[Int(k_tabBarApplicationIndexFile)] {
            item.title = NSLocalizedString("_home_", comment: "")
            item.image = CCGraphics.changeThemingColorImage(UIImage(named: "tabBarFiles"), width: 50, height: 50, color: NCBrandColor.sharedInstance.brandElement)
            item.selectedImage = item.image
        }
        
        // Favorite
        if let item = items?[Int(k_tabBarApplicationIndexFavorite)] {
            item.title = NSLocalizedString("_favorites_", comment: "")
            item.image = CCGraphics.changeThemingColorImage(UIImage(named: "favorite"), width: 50, height: 50, color: NCBrandColor.sharedInstance.brandElement)
            item.selectedImage = item.image
        }
        
        // +
        if let item = items?[Int(k_tabBarApplicationIndexPlusHide)] {
            item.title = ""
            item.image = nil
            item.isEnabled = false
        }
        
        // Media
        if let item = items?[Int(k_tabBarApplicationIndexMedia)] {
            item.title = NSLocalizedString("_media_", comment: "")
            item.image = CCGraphics.changeThemingColorImage(UIImage(named: "media"), width: 50, height: 50, color: NCBrandColor.sharedInstance.brandElement)
            item.selectedImage = item.image
        }
        
        // More
        if let item = items?[Int(k_tabBarApplicationIndexMore)] {
            item.title = NSLocalizedString("_more_", comment: "")
            item.image = CCGraphics.changeThemingColorImage(UIImage(named: "tabBarMore"), width: 50, height: 50, color: NCBrandColor.sharedInstance.brandElement)
            item.selectedImage = item.image
        }
        
        // Center button
        
        if let centerButton = self.viewWithTag(99) {
            centerButton.removeFromSuperview()
        }
        let centerButtonHeight: CGFloat = 57
        let centerButtonY: CGFloat = -28
        
        let centerButton = UIButton(frame: CGRect(x: (self.bounds.width / 2)-(centerButtonHeight/2), y: centerButtonY, width: centerButtonHeight, height: centerButtonHeight))
        
        centerButton.setTitle("", for: .normal)
        centerButton.setImage(CCGraphics.changeThemingColorImage(UIImage(named: "tabBarPlus"), width: 100, height: 100, color: .white), for: .normal)
        centerButton.backgroundColor = NCBrandColor.sharedInstance.brandElement
        centerButton.tintColor = UIColor.white
        centerButton.tag = 99
        centerButton.accessibilityLabel = NSLocalizedString("_accessibility_add_upload_", comment: "")
        centerButton.layer.cornerRadius = centerButton.frame.size.width / 2.0
        centerButton.layer.masksToBounds = false
        centerButton.layer.shadowOffset = CGSize(width: 0, height: 0)
        centerButton.layer.shadowRadius = 3.0
        centerButton.layer.shadowOpacity = 0.5
        
        centerButton.addTarget(self, action: #selector(self.centerButtonAction), for: .touchUpInside)
        
        self.addSubview(centerButton)
    }
    
    // Menu Button Touch Action
    @objc func centerButtonAction(sender: UIButton) {
        
        if appDelegate.maintenanceMode { return }
        if let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, appDelegate.activeServerUrl)) {
            
            if !directory.permissions.contains("CK") {
                NCContentPresenter.shared.messageNotification("_warning_", description: "_no_permission_add_file_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.info, errorCode: Int(k_CCErrorInternalError))
                return
            }
        }
        
        if let viewController = self.window?.rootViewController {
            appDelegate.showMenuIn(viewController: viewController)
        }
    }
}

