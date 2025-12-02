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
import NextcloudKit

enum NCShareCommon {
    static let itemTypeFile = "file"
    static let itemTypeFolder = "folder"

    static func createLinkAvatar(imageName: String, colorCircle: UIColor) -> UIImage? {
        let size: CGFloat = 200

        let bottomImage = UIImage(named: "circle_fill")!.image(color: colorCircle, size: size / 2)
        let topImage = NCUtility().loadImage(named: imageName, colors: [NCBrandColor.shared.iconImageColor])
        UIGraphicsBeginImageContextWithOptions(CGSize(width: size, height: size), false, UIScreen.main.scale)
        bottomImage.draw(in: CGRect(origin: CGPoint.zero, size: CGSize(width: size, height: size)))
        topImage.draw(in: CGRect(origin: CGPoint(x: size / 4, y: size / 4), size: CGSize(width: size / 2, height: size / 2)))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image
    }

    static func copyLink(link: String, viewController: UIViewController, sender: Any) {
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

    static func getImageShareType(shareType: Int) -> UIImage? {
        typealias type = NKShare.ShareType

        switch shareType {
        case type.group.rawValue:
            return UIImage(named: "shareTypeGroup")?.withTintColor(NCBrandColor.shared.textColor, renderingMode: .alwaysOriginal)
        case type.publicLink.rawValue:
            return UIImage(named: "shareTypeLink")?.withTintColor(NCBrandColor.shared.textColor, renderingMode: .alwaysOriginal)
        case type.email.rawValue:
            return UIImage(named: "shareTypeEmail")?.withTintColor(NCBrandColor.shared.textColor, renderingMode: .alwaysOriginal)
        case type.team.rawValue:
            return UIImage(named: "shareTypeTeam")?.withTintColor(NCBrandColor.shared.textColor, renderingMode: .alwaysOriginal)
        case type.federatedGroup.rawValue:
            return UIImage(named: "shareTypeGroup")?.withTintColor(NCBrandColor.shared.textColor, renderingMode: .alwaysOriginal)
        case type.talkConversation.rawValue:
            return UIImage(named: "shareTypeRoom")?.withTintColor(NCBrandColor.shared.textColor, renderingMode: .alwaysOriginal)
        default:
            return UIImage(named: "shareTypeUser")?.withTintColor(NCBrandColor.shared.textColor, renderingMode: .alwaysOriginal)
        }
    }
}
