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

import Foundation
import FSCalendar
import DropDown

class NCShareCommon: NSObject {
    @objc static let sharedInstance: NCShareCommon = {
        let instance = NCShareCommon()
        return instance
    }()
    
    func createLinkAvatar() -> UIImage? {
        
        let size: CGFloat = 200
        
        let bottomImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "circle"), width: size, height: size, color: NCBrandColor.sharedInstance.brand)
        let topImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "sharebylink"), width: size, height: size, color: UIColor.white)
        UIGraphicsBeginImageContextWithOptions(CGSize(width: size, height: size), false, 0.0)
        bottomImage?.draw(in: CGRect(origin: CGPoint.zero, size: CGSize(width: size, height: size)))
        topImage?.draw(in: CGRect(origin:  CGPoint(x: size/4, y: size/4), size: CGSize(width: size/2, height: size/2)))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
    
    func openViewMenuShareLink(shareViewController: NCShare, tableShare: tableShare?, metadata: tableMetadata) -> (shareLinkMenuView: NCShareLinkMenuView, viewWindow: UIView) {
        
        var shareLinkMenuView: NCShareLinkMenuView
        let window = UIApplication.shared.keyWindow!
        let viewWindow = UIView(frame: window.bounds)
//        let globalPoint = shareViewController.view.superview?.convert(shareViewController.view.frame.origin, to: nil)
//        let constantTrailingAnchor = window.bounds.width - shareViewController.view.bounds.width - globalPoint!.x + 40
//        var constantBottomAnchor: CGFloat = 10
//        if #available(iOS 11.0, *) {
//            constantBottomAnchor = constantBottomAnchor + UIApplication.shared.keyWindow!.safeAreaInsets.bottom
//        }
        
        window.addSubview(viewWindow)
        viewWindow.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        if metadata.directory {
            shareLinkMenuView = Bundle.main.loadNibNamed("NCShareLinkFolderMenuView", owner: self, options: nil)?.first as! NCShareLinkMenuView
        } else {
            shareLinkMenuView = Bundle.main.loadNibNamed("NCShareLinkMenuView", owner: self, options: nil)?.first as! NCShareLinkMenuView
        }
        
        shareLinkMenuView.width = 250
        if metadata.directory {
            shareLinkMenuView.height = 540
        } else {
            shareLinkMenuView.height = 440
        }
        
        shareLinkMenuView.backgroundColor = NCBrandColor.sharedInstance.backgroundForm
        shareLinkMenuView.metadata = metadata
        shareLinkMenuView.viewWindow = viewWindow
        shareLinkMenuView.shareViewController = shareViewController
        shareLinkMenuView.reloadData(idRemoteShared: tableShare?.idRemoteShared ?? 0)
        shareLinkMenuView.translatesAutoresizingMaskIntoConstraints = false
        viewWindow.addSubview(shareLinkMenuView)
        
        NSLayoutConstraint.activate([
            shareLinkMenuView.widthAnchor.constraint(equalToConstant: shareLinkMenuView.width),
            shareLinkMenuView.heightAnchor.constraint(equalToConstant: shareLinkMenuView.height),
            shareLinkMenuView.centerXAnchor.constraint(equalTo: viewWindow.centerXAnchor),
            shareLinkMenuView.centerYAnchor.constraint(equalTo: viewWindow.centerYAnchor),
        ])
        
        return(shareLinkMenuView: shareLinkMenuView, viewWindow: viewWindow)
    }
    
    func openViewMenuUser(shareViewController: NCShare, tableShare: tableShare?, metadata: tableMetadata) -> (shareUserMenuView: NCShareUserMenuView, viewWindow: UIView) {
        
        var shareUserMenuView: NCShareUserMenuView
        let window = UIApplication.shared.keyWindow!
        let viewWindow = UIView(frame: window.bounds)
//        let globalPoint = shareViewController.view.superview?.convert(shareViewController.view.frame.origin, to: nil)
//        let constantTrailingAnchor = window.bounds.width - shareViewController.view.bounds.width - globalPoint!.x + 40
//        var constantBottomAnchor: CGFloat = 10
//        if #available(iOS 11.0, *) {
//            constantBottomAnchor = constantBottomAnchor + UIApplication.shared.keyWindow!.safeAreaInsets.bottom
//        }
        
        window.addSubview(viewWindow)
        viewWindow.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        if metadata.directory {
            shareUserMenuView = Bundle.main.loadNibNamed("NCShareUserFolderMenuView", owner: self, options: nil)?.first as! NCShareUserMenuView
        } else {
            shareUserMenuView = Bundle.main.loadNibNamed("NCShareUserMenuView", owner: self, options: nil)?.first as! NCShareUserMenuView
        }
        
        shareUserMenuView.width = 250
        if metadata.directory {
            shareUserMenuView.height = 410
        } else {
            shareUserMenuView.height = 260
        }
        
        shareUserMenuView.backgroundColor = NCBrandColor.sharedInstance.backgroundForm
        shareUserMenuView.metadata = metadata
        shareUserMenuView.viewWindow = viewWindow
        shareUserMenuView.shareViewController = shareViewController
        shareUserMenuView.reloadData(idRemoteShared: tableShare?.idRemoteShared ?? 0)
        shareUserMenuView.translatesAutoresizingMaskIntoConstraints = false
        viewWindow.addSubview(shareUserMenuView)

        NSLayoutConstraint.activate([
            shareUserMenuView.widthAnchor.constraint(equalToConstant: shareUserMenuView.width),
            shareUserMenuView.heightAnchor.constraint(equalToConstant: shareUserMenuView.height),
            shareUserMenuView.centerXAnchor.constraint(equalTo: viewWindow.centerXAnchor),
            shareUserMenuView.centerYAnchor.constraint(equalTo: viewWindow.centerYAnchor),
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
            calendar.backgroundColor = .systemBackground
            calendar.appearance.headerTitleColor = .label
        } else {
            calendar.backgroundColor = .white
            calendar.appearance.headerTitleColor = .black
        }
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
        
        calendar.appearance.weekdayTextColor = UIColor(red: 100/255, green: 100/255, blue: 100/255, alpha: 1)
        calendar.appearance.weekdayFont = UIFont.systemFont(ofSize: 12)
        
        calendar.appearance.todayColor = NCBrandColor.sharedInstance.brand
        calendar.appearance.titleFont = UIFont.systemFont(ofSize: 12)
        
        viewWindow.addSubview(calendar)
        
        return(calendarView: calendar, viewWindow: viewWindow)
    }
    
    func copyLink(tableShare: tableShare?, viewController: UIViewController, sender: Any) {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        var url: String = ""
        
        guard let tableShare = tableShare else { return }
        
        if tableShare.token.hasPrefix("http://") || tableShare.token.hasPrefix("https://") {
            url = tableShare.token
        } else if tableShare.url != "" {
            url = tableShare.url
        } else {
            url = appDelegate.activeUrl + "/" + k_share_link_middle_part_url_after_version_8 + tableShare.token
        }
        
        if let name = URL(string: url), !name.absoluteString.isEmpty {
            let objectsToShare = [name]
            
            let activityViewController = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                if activityViewController.responds(to: #selector(getter: UIViewController.popoverPresentationController)) {
                    activityViewController.popoverPresentationController?.sourceView = sender as? UIView
                    activityViewController.popoverPresentationController?.sourceRect = (sender as AnyObject).bounds
                }
            }
            
            viewController.present(activityViewController, animated: true, completion: nil)
        }
    }
}
