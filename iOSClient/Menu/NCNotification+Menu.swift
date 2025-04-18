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
import FloatingPanel
import SwiftyJSON
import NextcloudKit

extension NCNotification {
    func toggleMenu(notification: NKNotifications, sender: Any?) {
        var actions = [NCMenuAction]()

        if let notificationActions = notification.actions, let jsonNotificationActionsActions = JSON(notificationActions).array {
            for action in jsonNotificationActionsActions {
                let label = action["label"].stringValue
                actions.append(
                    NCMenuAction(
                        title: action["label"].stringValue,
                        icon: UIImage(),
                        sender: sender,
                        action: { _ in
                            self.tapAction(with: notification, label: label, sender: sender)
                        }
                    )
                )
            }
        }

        presentMenu(with: actions, sender: sender)
    }
}
