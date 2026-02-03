// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import SwiftyJSON
import NextcloudKit

/// A context menu for notification actions.
/// See ``NCNotification`` for usage details.
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
                    UIAction(title: label, image: nil) { [self] _ in
                        delegate?.tapAction(with: notification, label: label, sender: nil)
                    }
                )
            }
        }

        return UIMenu(title: "", children: actions)
    }
}
