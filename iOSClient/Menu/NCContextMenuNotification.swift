//
//  NCNotification+Menu.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 31/08/2022.
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

import UIKit
import SwiftyJSON
import NextcloudKit

class NCContextMenuNotification: NSObject {
    let notification: NKNotifications
    weak var delegate: NCNotificationCellDelegate?

    init(notification: NKNotifications, delegate: NCNotificationCellDelegate?) {
        self.notification = notification
        self.delegate = delegate
    }

    func viewMenu() -> UIMenu {
        var actions: [UIAction] = []

        if let notificationActions = notification.actions,
           let jsonActions = JSON(notificationActions).array {
            for action in jsonActions {
                let label = action["label"].stringValue
                actions.append(
                    UIAction(title: label, image: nil) { [weak self] _ in
                        guard let self else { return }
                        self.delegate?.tapAction(with: self.notification, label: label, sender: nil)
                    }
                )
            }
        }

        return UIMenu(title: "", children: actions)
    }
}
