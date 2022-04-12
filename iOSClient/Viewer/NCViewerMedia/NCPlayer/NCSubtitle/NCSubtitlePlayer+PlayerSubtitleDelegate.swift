//
//  NCSubtitlePlayer+PlayerSubtitleDelegate.swift
//  Nextcloud
//
//  Created by Federico Malagoni on 11/03/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
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
import NCCommunication
import UIKit
import AVFoundation
import MediaPlayer
import Alamofire
import RealmSwift

public protocol PlayerSubtitleDelegate: AnyObject {
    func hideOrShowSubtitle()
    func showAlertSubtitles()
}

extension NCPlayer: PlayerSubtitleDelegate {

    func hideOrShowSubtitle() {
        if self.isSubtitleShowed {
            self.hideSubtitle()
            self.isSubtitleShowed = false
        } else {
            self.showAlertSubtitles()
        }
    }

    internal func showAlertSubtitles() {

        let alert = UIAlertController(title: nil, message: NSLocalizedString("_subtitle_", comment: ""), preferredStyle: .actionSheet)

        for url in subtitleUrls {

            print("Play Subtitle at:\n\(url.path)")

            let videoUrlTitle = self.metadata.fileName.alphanumeric.dropLast(3)
            let subtitleUrlTitle = url.lastPathComponent.alphanumeric.dropLast(3)

            var titleSubtitle = String(subtitleUrlTitle.dropFirst(videoUrlTitle.count))
            if titleSubtitle.isEmpty {
                titleSubtitle = NSLocalizedString("_subtitle_", comment: "")
            }

            alert.addAction(UIAlertAction(title: titleSubtitle, style: .default, handler: { [self] _ in

                if NCUtilityFileSystem.shared.getFileSize(filePath: url.path) > 0 {

                    self.open(fileFromLocal: url)
                    if let viewController = viewController {
                        self.addSubtitlesTo(viewController, self.playerToolBar)
                        self.isSubtitleShowed = true
                        self.showSubtitle()
                    }

                } else {

                    let alertError = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: NSLocalizedString("_subtitle_not_found_", comment: ""), preferredStyle: .alert)
                    alertError.addAction(UIKit.UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: nil))

                    viewController?.present(alertError, animated: true, completion: nil)
                    self.isSubtitleShowed = false
                }
            }))
        }

        alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: { _ in
            self.isSubtitleShowed = false
        }))

        alert.popoverPresentationController?.sourceView = self.viewController?.view

        self.viewController?.present(alert, animated: true, completion: nil)
    }
}
