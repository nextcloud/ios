//
//  NCViewerImageVideo.swift
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

class NCViewerImageVideo: UIViewController {
    
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var closeView: UIView!
    @IBOutlet weak var closeButton: UIButton!

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    @objc var metadata = tableMetadata()

    required init?(coder: NSCoder) {
        super.init(coder: coder)        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        
        closeView.layer.cornerRadius = 7
        closeView.backgroundColor = .yellow
        
        let image = CCGraphics.changeThemingColorImage(UIImage(named: "exit"), width: 50, height: 50, color: .black)
        closeButton.setImage(image, for: .normal)
        
        NCViewerVideoCommon.shared.viewMedia(metadata, view: videoView, frame: CGRect(x: 0, y: 0, width: videoView.frame.width, height: videoView.frame.height))
    }
    
    @IBAction func touchUpInsidecloseButton(_ sender: Any) {
        
        if appDelegate.player != nil && appDelegate.player.rate != 0 {
            appDelegate.player.pause()
        }
        
        if appDelegate.isMediaObserver {
            appDelegate.isMediaObserver = false
            NCViewerVideoCommon.shared.removeObserver()
        }

        dismiss(animated: false) { }
    }
}
