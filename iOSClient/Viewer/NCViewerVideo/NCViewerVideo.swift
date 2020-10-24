//
//  NCViewerVideo.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 09/03/2020.
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

class NCViewerVideo: UIViewController {
    
    @IBOutlet weak var backgroundView: UIView!

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var metadata = tableMetadata()

    required init?(coder: NSCoder) {
        super.init(coder: coder)        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_deleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_renameFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_moveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(viewUnload), name: NSNotification.Name(rawValue: k_notificationCenter_menuDetailClose), object: nil)
        
        view.backgroundColor = .black
        let frame = CGRect(x: 0, y: 0, width: backgroundView.frame.width, height: backgroundView.frame.height)
        NCViewerVideoCommon.sharedInstance.viewMedia(metadata, view: backgroundView, frame: frame)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let buttonMore = UIBarButtonItem.init(image: CCGraphics.changeThemingColorImage(UIImage(named: "more"), width: 50, height: 50, color: NCBrandColor.sharedInstance.textView), style: .plain, target: self, action: #selector(self.openMenuMore))
        navigationItem.rightBarButtonItem = buttonMore
        
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.title = metadata.fileNameView

        appDelegate.activeViewController = self
    }
    
    @objc func viewUnload() {
        
        navigationController?.popViewController(animated: true)
    }
    
    //MARK: - NotificationCenter
   
    @objc func moveFile(_ notification: NSNotification) {
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let metadataNew = userInfo["metadataNew"] as? tableMetadata {
                if metadata.ocId == self.metadata.ocId {
                    self.metadata = metadataNew
                }
            }
        }
    }
    
    @objc func deleteFile(_ notification: NSNotification) {
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                if metadata.ocId == self.metadata.ocId {
                    viewUnload()
                }
            }
        }
    }
    
    @objc func renameFile(_ notification: NSNotification) {
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                if metadata.ocId == self.metadata.ocId {
                    self.metadata = metadata
                    navigationItem.title = metadata.fileNameView
                }
            }
        }
    }

    //MARK: - Action
    
    @objc func openMenuMore() {
        NCViewer.shared.toggleMoreMenu(viewController: self, metadata: metadata)
    }
}

extension NCViewerVideo : UINavigationControllerDelegate {

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        
        if parent == nil {
            if appDelegate.player != nil && appDelegate.player.rate != 0 {
                appDelegate.player.pause()
            }
            
            if appDelegate.isMediaObserver {
                appDelegate.isMediaObserver = false
                NCViewerVideoCommon.sharedInstance.removeObserver()
            }
        }
     }
}
