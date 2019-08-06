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
    
    func downloadAvatar(user: String, cell: NCShareUserCell) {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let fileNameLocalPath = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(appDelegate.activeUser, activeUrl: appDelegate.activeUrl) + "-" + user + ".png"
        
        if FileManager.default.fileExists(atPath: fileNameLocalPath) {
            if let image = UIImage(contentsOfFile: fileNameLocalPath) {
                cell.imageItem.image = image
            }
        } else {
            DispatchQueue.global().async {
                let url = appDelegate.activeUrl + k_avatar + user + "/128"
                let encodedString = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                OCNetworking.sharedManager()?.downloadContents(ofUrl: encodedString, completion: { (data, message, errorCode) in
                    if errorCode == 0 && UIImage(data: data!) != nil {
                        do {
                            try data!.write(to: NSURL(fileURLWithPath: fileNameLocalPath) as URL, options: .atomic)
                        } catch { return }
                        cell.imageItem.image = UIImage(data: data!)
                    } else {
                        cell.imageItem.image = UIImage(named: "avatar")
                    }
                })
            }
        }
    }
    
    func downloadAvatar(user: String, cell: NCShareUserDropDownCell) {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let fileNameLocalPath = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(appDelegate.activeUser, activeUrl: appDelegate.activeUrl) + "-" + user + ".png"
        
        if FileManager.default.fileExists(atPath: fileNameLocalPath) {
            if let image = UIImage(contentsOfFile: fileNameLocalPath) {
                cell.imageItem.image = image
            }
        } else {
            DispatchQueue.global().async {
                let url = appDelegate.activeUrl + k_avatar + user + "/128"
                let encodedString = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                OCNetworking.sharedManager()?.downloadContents(ofUrl: encodedString, completion: { (data, message, errorCode) in
                    if errorCode == 0 && UIImage(data: data!) != nil {
                        do {
                            try data!.write(to: NSURL(fileURLWithPath: fileNameLocalPath) as URL, options: .atomic)
                        } catch { return }
                        cell.imageItem.image = UIImage(data: data!)
                    } else {
                        cell.imageItem.image = UIImage(named: "avatar")
                    }
                })
            }
        }
    }
    
    func openViewMenuShareLink(shareViewController: NCShare, tableShare: tableShare?, metadata: tableMetadata) -> (shareLinkMenuView: NCShareLinkMenuView, viewWindow: UIView) {
        
        var shareLinkMenuView: NCShareLinkMenuView

        let globalPoint = shareViewController.view.superview?.convert(shareViewController.view.frame.origin, to: nil)
        
        let window = UIApplication.shared.keyWindow!
        let viewWindow = UIView(frame: window.bounds)
        window.addSubview(viewWindow)
        
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
        
        shareLinkMenuView.metadata = metadata
        shareLinkMenuView.viewWindow = viewWindow
        shareLinkMenuView.shareViewController = shareViewController
        shareLinkMenuView.reloadData(idRemoteShared: tableShare?.idRemoteShared ?? 0)
        
        let shareLinkMenuViewX = shareViewController.view.bounds.width/2 - shareLinkMenuView.width/2 + globalPoint!.x
        let shareLinkMenuViewY = globalPoint!.y
        
        shareLinkMenuView.frame = CGRect(x: shareLinkMenuViewX, y: shareLinkMenuViewY, width: shareLinkMenuView.width, height: shareLinkMenuView.height)
        viewWindow.addSubview(shareLinkMenuView)
        
        return(shareLinkMenuView: shareLinkMenuView, viewWindow: viewWindow)
    }
    
    func openViewMenuUser(shareViewController: NCShare, tableShare: tableShare?, metadata: tableMetadata) -> (shareUserMenuView: NCShareUserMenuView, viewWindow: UIView) {
        
        var shareUserMenuView: NCShareUserMenuView
        
        let globalPoint = shareViewController.view.superview?.convert(shareViewController.view.frame.origin, to: nil)
        
        let window = UIApplication.shared.keyWindow!
        let viewWindow = UIView(frame: window.bounds)
        window.addSubview(viewWindow)
        
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
        
        shareUserMenuView.metadata = metadata
        shareUserMenuView.viewWindow = viewWindow
        shareUserMenuView.shareViewController = shareViewController
        shareUserMenuView.reloadData(idRemoteShared: tableShare?.idRemoteShared ?? 0)
        
        let shareUserMenuViewX = shareViewController.view.bounds.width/2 - shareUserMenuView.width/2 + globalPoint!.x
        let shareUserMenuViewY = globalPoint!.y + 100
        
        shareUserMenuView.frame = CGRect(x: shareUserMenuViewX, y: shareUserMenuViewY, width: shareUserMenuView.width, height: shareUserMenuView.height)
        viewWindow.addSubview(shareUserMenuView)
        
        return(shareUserMenuView: shareUserMenuView, viewWindow: viewWindow)
    }
    
    func openCalendar(view: UIView, width: CGFloat, height: CGFloat) -> (calendarView: FSCalendar, viewWindow: UIView) {
        
        let globalPoint = view.superview?.convert(view.frame.origin, to: nil)
        
        let window = UIApplication.shared.keyWindow!
        let viewWindow = UIView(frame: window.bounds)
        window.addSubview(viewWindow)
        
        let calendar = FSCalendar(frame: CGRect(x: globalPoint!.x + 10, y: globalPoint!.y + 100, width: width - 20, height: 300))
        
        calendar.backgroundColor = .white
        calendar.placeholderType = .none
        calendar.appearance.headerMinimumDissolvedAlpha = 0.0
        
        calendar.layer.borderColor = UIColor.lightGray.cgColor
        calendar.layer.borderWidth = 0.5
        calendar.layer.masksToBounds = false
        calendar.layer.cornerRadius = 5
        calendar.layer.masksToBounds = false
        calendar.layer.shadowOffset = CGSize(width: 2, height: 2)
        calendar.layer.shadowOpacity = 0.2
        
        calendar.appearance.headerTitleColor = .black
        calendar.appearance.headerTitleFont = UIFont.systemFont(ofSize: 13)
        
        calendar.appearance.weekdayTextColor = UIColor(red: 100/255, green: 100/255, blue: 100/255, alpha: 1)
        calendar.appearance.weekdayFont = UIFont.systemFont(ofSize: 12)
        
        calendar.appearance.todayColor = NCBrandColor.sharedInstance.brand
        calendar.appearance.titleFont = UIFont.systemFont(ofSize: 12)
        
        viewWindow.addSubview(calendar)
        
        return(calendarView: calendar, viewWindow: viewWindow)
    }
    
    func copyLink(tableShare: tableShare?, viewController: UIViewController) {
        
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
            
            let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
            viewController.present(activityVC, animated: true, completion: nil)
        }
    }
}
