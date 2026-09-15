// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

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
