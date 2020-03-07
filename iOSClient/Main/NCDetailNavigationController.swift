//
//  NCDetailNavigationController.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 07/02/2020.
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

class NCDetailNavigationController: UINavigationController {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    var progressView: UIProgressView?
    let progressHeight: CGFloat = 1

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.triggerProgressTask(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_progressTask), object:nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.downloadFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_downloadFile), object: nil)
                
        changeTheming()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let buttonMore = UIBarButtonItem.init(image: CCGraphics.changeThemingColorImage(UIImage(named: "more"), width: 50, height: 50, color: NCBrandColor.sharedInstance.textView), style: .plain, target: self, action: #selector(self.openMenuMore))
        topViewController?.navigationItem.rightBarButtonItem = buttonMore
               
        topViewController?.navigationItem.leftBarButtonItem = nil
        if let splitViewController = self.splitViewController {
            if !splitViewController.isCollapsed {
                topViewController?.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
            }
        }
        
        setProgressBar()
    }
    
    //MARK: - NotificationCenter
    
    @objc func changeTheming() {
        navigationBar.barTintColor = NCBrandColor.sharedInstance.brand
        navigationBar.tintColor = NCBrandColor.sharedInstance.brandText
        navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor:NCBrandColor.sharedInstance.brandText]
    }
    
    @objc func triggerProgressTask(_ notification: NSNotification) {
        guard let metadata = appDelegate.activeDetail.metadata else {
            setProgressBar()
            return
        }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let account = userInfo["account"] as? String, let serverUrl = userInfo["serverUrl"] as? String, let progress = userInfo["progress"] as? Float {
                if account == metadata.account && serverUrl == metadata.serverUrl {
                    self.progress(progress)
                }
            }
        }
    }
    
    @objc func downloadFile(_ notification: NSNotification) {
        guard let metadataDetail = appDelegate.activeDetail.metadata else { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                if metadataDetail.account == metadata.account && metadataDetail.serverUrl == metadata.serverUrl {
                    setProgressBar()
                }
            }
        }
    }
    
    //MARK: - Button

    @objc func openMenuMore() {
        if let metadata = appDelegate.activeDetail?.metadata {
            self.toggleMoreMenu(viewController: self, metadata: metadata)
        }
    }
    
    //MARK: - ProgressBar

    @objc func setProgressBar() {
        if progressView != nil {
            progressView?.removeFromSuperview()
        }
        
        progressView = UIProgressView.init(progressViewStyle: .bar)
        progressView!.frame = CGRect(x: 0, y: navigationBar.frame.height-progressHeight, width: navigationBar.frame.width, height: progressHeight)
        progressView!.setProgress(0, animated: false)
        progressView!.tintColor = NCBrandColor.sharedInstance.graySoft
        progressView!.trackTintColor = .clear
        navigationBar.addSubview(progressView!)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.orientationDidChange), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    @objc func progress(_ progress: Float) {
        guard let progressView = self.progressView else { return }
        progressView.progress = progress
    }
    
    @objc func orientationDidChange() {
        guard let progressView = self.progressView else { return }
        
        progressView.frame = CGRect(x: 0, y: navigationBar.frame.height-progressHeight, width: navigationBar.frame.width, height: progressHeight)
    }
}
