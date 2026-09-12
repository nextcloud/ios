// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit

extension NotificationCenter {
    func postOnMainThread(name: String, object anObject: Any? = nil, userInfo aUserInfo: [AnyHashable: Any]? = nil, second: Double = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + second) {
            NotificationCenter.default.post(name: Notification.Name(rawValue: name), object: anObject, userInfo: aUserInfo)
        }
    }

    func postOnGlobalThread(name: String, object anObject: Any? = nil, userInfo aUserInfo: [AnyHashable: Any]? = nil, second: Double = 0) {
        DispatchQueue.global().asyncAfter(deadline: .now() + second) {
            NotificationCenter.default.post(name: Notification.Name(rawValue: name), object: anObject, userInfo: aUserInfo)
        }
    }
}
