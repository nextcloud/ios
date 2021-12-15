//
//  NCShareCommon.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 25/07/2019.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
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

import UIKit
import FSCalendar
import DropDown

class NCShareCommon: NSObject {
    @objc static let shared: NCShareCommon = {
        let instance = NCShareCommon()
        return instance
    }()

    let SHARE_TYPE_USER = 0
    let SHARE_TYPE_GROUP = 1
    let SHARE_TYPE_LINK = 3
    let SHARE_TYPE_EMAIL = 4
    let SHARE_TYPE_CONTACT = 5
    let SHARE_TYPE_REMOTE = 6
    let SHARE_TYPE_CIRCLE = 7
    let SHARE_TYPE_GUEST = 8
    let SHARE_TYPE_REMOTE_GROUP = 9
    let SHARE_TYPE_ROOM = 10

    func createLinkAvatar(imageName: String, colorCircle: UIColor) -> UIImage? {

        let size: CGFloat = 200

        let bottomImage = UIImage(named: "circle.fill")!.image(color: colorCircle, size: size/2)
        let topImage = UIImage(named: imageName)!.image(color: .white, size: size/2)
        UIGraphicsBeginImageContextWithOptions(CGSize(width: size, height: size), false, UIScreen.main.scale)
        bottomImage.draw(in: CGRect(origin: CGPoint.zero, size: CGSize(width: size, height: size)))
        topImage.draw(in: CGRect(origin: CGPoint(x: size/4, y: size/4), size: CGSize(width: size/2, height: size/2)))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image
    }

    func openViewMenuShareLink(shareViewController: NCShare, tableShare: tableShare?, metadata: tableMetadata) -> (shareLinkMenuView: NCShareLinkMenuView, viewWindow: UIView) {

        var shareLinkMenuView: NCShareLinkMenuView
        let window = UIApplication.shared.keyWindow!
        let viewWindow = UIView(frame: window.bounds)

        window.addSubview(viewWindow)
        viewWindow.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        if metadata.directory {
            shareLinkMenuView = Bundle.main.loadNibNamed("NCShareLinkFolderMenuView", owner: self, options: nil)?.first as! NCShareLinkMenuView
        } else {
            shareLinkMenuView = Bundle.main.loadNibNamed("NCShareLinkMenuView", owner: self, options: nil)?.first as! NCShareLinkMenuView
        }

        shareLinkMenuView.width = 250
        if metadata.directory {
            shareLinkMenuView.height = 600
        } else {
            shareLinkMenuView.height = 500
        }

        shareLinkMenuView.backgroundColor = NCBrandColor.shared.systemBackground
        shareLinkMenuView.metadata = metadata
        shareLinkMenuView.viewWindow = viewWindow
        shareLinkMenuView.shareViewController = shareViewController
        shareLinkMenuView.reloadData(idShare: tableShare?.idShare ?? 0)
        shareLinkMenuView.translatesAutoresizingMaskIntoConstraints = false
        viewWindow.addSubview(shareLinkMenuView)

        NSLayoutConstraint.activate([
            shareLinkMenuView.widthAnchor.constraint(equalToConstant: shareLinkMenuView.width),
            shareLinkMenuView.heightAnchor.constraint(equalToConstant: shareLinkMenuView.height),
            shareLinkMenuView.centerXAnchor.constraint(equalTo: viewWindow.centerXAnchor),
            shareLinkMenuView.centerYAnchor.constraint(equalTo: viewWindow.centerYAnchor)
        ])

        return(shareLinkMenuView: shareLinkMenuView, viewWindow: viewWindow)
    }

    func openViewMenuUser(shareViewController: NCShare, tableShare: tableShare?, metadata: tableMetadata) -> (shareUserMenuView: NCShareUserMenuView, viewWindow: UIView) {

        var shareUserMenuView: NCShareUserMenuView
        let window = UIApplication.shared.keyWindow!
        let viewWindow = UIView(frame: window.bounds)

        window.addSubview(viewWindow)
        viewWindow.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        if metadata.directory {
            shareUserMenuView = Bundle.main.loadNibNamed("NCShareUserFolderMenuView", owner: self, options: nil)?.first as! NCShareUserMenuView
        } else {
            shareUserMenuView = Bundle.main.loadNibNamed("NCShareUserMenuView", owner: self, options: nil)?.first as! NCShareUserMenuView
        }

        shareUserMenuView.width = 250
        if metadata.directory {
            shareUserMenuView.height = 420
        } else {
            shareUserMenuView.height = 270
        }

        shareUserMenuView.backgroundColor = NCBrandColor.shared.systemBackground
        shareUserMenuView.metadata = metadata
        shareUserMenuView.viewWindow = viewWindow
        shareUserMenuView.shareViewController = shareViewController
        shareUserMenuView.reloadData(idShare: tableShare?.idShare ?? 0)
        shareUserMenuView.translatesAutoresizingMaskIntoConstraints = false
        viewWindow.addSubview(shareUserMenuView)

        NSLayoutConstraint.activate([
            shareUserMenuView.widthAnchor.constraint(equalToConstant: shareUserMenuView.width),
            shareUserMenuView.heightAnchor.constraint(equalToConstant: shareUserMenuView.height),
            shareUserMenuView.centerXAnchor.constraint(equalTo: viewWindow.centerXAnchor),
            shareUserMenuView.centerYAnchor.constraint(equalTo: viewWindow.centerYAnchor)
        ])

        return(shareUserMenuView: shareUserMenuView, viewWindow: viewWindow)
    }

    func openCalendar(view: UIView, width: CGFloat, height: CGFloat) -> (calendarView: FSCalendar, viewWindow: UIView) {

        let globalPoint = view.superview?.convert(view.frame.origin, to: nil)

        let window = UIApplication.shared.keyWindow!
        let viewWindow = UIView(frame: window.bounds)
        window.addSubview(viewWindow)

        let calendar = FSCalendar(frame: CGRect(x: globalPoint!.x + 10, y: globalPoint!.y + 10, width: width - 20, height: 300))

        if #available(iOS 13.0, *) {
            calendar.appearance.headerTitleColor = .label
        } else {
            calendar.appearance.headerTitleColor = .black
        }
        calendar.backgroundColor = NCBrandColor.shared.systemBackground
        calendar.placeholderType = .none
        calendar.appearance.headerMinimumDissolvedAlpha = 0.0

        calendar.layer.borderColor = UIColor.lightGray.cgColor
        calendar.layer.borderWidth = 0.5
        calendar.layer.masksToBounds = false
        calendar.layer.cornerRadius = 5
        calendar.layer.masksToBounds = false
        calendar.layer.shadowOffset = CGSize(width: 2, height: 2)
        calendar.layer.shadowOpacity = 0.2

        calendar.appearance.headerTitleFont = UIFont.systemFont(ofSize: 13)

        calendar.appearance.weekdayTextColor = NCBrandColor.shared.gray
        calendar.appearance.weekdayFont = UIFont.systemFont(ofSize: 13)

        calendar.appearance.todayColor = NCBrandColor.shared.brandElement
        calendar.appearance.titleFont = UIFont.systemFont(ofSize: 13)

        viewWindow.addSubview(calendar)

        return(calendarView: calendar, viewWindow: viewWindow)
    }

    func copyLink(link: String, viewController: UIViewController, sender: Any) {
        let objectsToShare = [link]

        let activityViewController = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)

        if UIDevice.current.userInterfaceIdiom == .pad {
            if activityViewController.responds(to: #selector(getter: UIViewController.popoverPresentationController)) {
                activityViewController.popoverPresentationController?.sourceView = sender as? UIView
                activityViewController.popoverPresentationController?.sourceRect = (sender as AnyObject).bounds
            }
        }

        viewController.present(activityViewController, animated: true, completion: nil)
    }

    func getImageShareType(shareType: Int) -> UIImage? {

        switch shareType {
        case SHARE_TYPE_USER:
            return UIImage(named: "shareTypeUser")?.imageColor(NCBrandColor.shared.label)
        case self.SHARE_TYPE_GROUP:
            return UIImage(named: "shareTypeGroup")?.imageColor(NCBrandColor.shared.label)
        case self.SHARE_TYPE_LINK:
            return UIImage(named: "shareTypeLink")?.imageColor(NCBrandColor.shared.label)
        case self.SHARE_TYPE_EMAIL:
            return UIImage(named: "shareTypeEmail")?.imageColor(NCBrandColor.shared.label)
        case self.SHARE_TYPE_CONTACT:
            return UIImage(named: "shareTypeUser")?.imageColor(NCBrandColor.shared.label)
        case self.SHARE_TYPE_REMOTE:
            return UIImage(named: "shareTypeUser")?.imageColor(NCBrandColor.shared.label)
        case self.SHARE_TYPE_CIRCLE:
            return UIImage(named: "shareTypeCircles")?.imageColor(NCBrandColor.shared.label)
        case self.SHARE_TYPE_GUEST:
            return UIImage(named: "shareTypeUser")?.imageColor(NCBrandColor.shared.label)
        case self.SHARE_TYPE_REMOTE_GROUP:
            return UIImage(named: "shareTypeGroup")?.imageColor(NCBrandColor.shared.label)
        case self.SHARE_TYPE_ROOM:
            return UIImage(named: "shareTypeRoom")?.imageColor(NCBrandColor.shared.label)
        default:
            return UIImage(named: "shareTypeUser")?.imageColor(NCBrandColor.shared.label)
        }
    }
}
