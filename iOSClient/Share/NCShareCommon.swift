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

        let bottomImage = UIImage(named: "circle_fill")!.image(color: colorCircle, size: size/2)
        let topImage = UIImage(named: imageName)!.image(color: .white, size: size/2)
        UIGraphicsBeginImageContextWithOptions(CGSize(width: size, height: size), false, UIScreen.main.scale)
        bottomImage.draw(in: CGRect(origin: CGPoint.zero, size: CGSize(width: size, height: size)))
        topImage.draw(in: CGRect(origin: CGPoint(x: size/4, y: size/4), size: CGSize(width: size/2, height: size/2)))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image
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
        DispatchQueue.main.async {
            viewController.present(activityViewController, animated: true, completion: nil)
        }
    }

    func getImageShareType(shareType: Int) -> UIImage? {

        switch shareType {
        case SHARE_TYPE_USER:
            return UIImage(named: "shareTypeUser")?.withTintColor(.label, renderingMode: .alwaysOriginal)
        case self.SHARE_TYPE_GROUP:
            return UIImage(named: "shareTypeGroup")?.withTintColor(.label, renderingMode: .alwaysOriginal)
        case self.SHARE_TYPE_LINK:
            return UIImage(named: "shareTypeLink")?.withTintColor(.label, renderingMode: .alwaysOriginal)
        case self.SHARE_TYPE_EMAIL:
            return UIImage(named: "shareTypeEmail")?.withTintColor(.label, renderingMode: .alwaysOriginal)
        case self.SHARE_TYPE_CONTACT:
            return UIImage(named: "shareTypeUser")?.withTintColor(.label, renderingMode: .alwaysOriginal)
        case self.SHARE_TYPE_REMOTE:
            return UIImage(named: "shareTypeUser")?.withTintColor(.label, renderingMode: .alwaysOriginal)
        case self.SHARE_TYPE_CIRCLE:
            return UIImage(named: "shareTypeCircles")?.withTintColor(.label, renderingMode: .alwaysOriginal)
        case self.SHARE_TYPE_GUEST:
            return UIImage(named: "shareTypeUser")?.withTintColor(.label, renderingMode: .alwaysOriginal)
        case self.SHARE_TYPE_REMOTE_GROUP:
            return UIImage(named: "shareTypeGroup")?.withTintColor(.label, renderingMode: .alwaysOriginal)
        case self.SHARE_TYPE_ROOM:
            return UIImage(named: "shareTypeRoom")?.withTintColor(.label, renderingMode: .alwaysOriginal)
        default:
            return UIImage(named: "shareTypeUser")?.withTintColor(.label, renderingMode: .alwaysOriginal)
        }
    }
}
