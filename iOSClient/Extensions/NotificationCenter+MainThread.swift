//
//  NotificationCenter+MainThread.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 16/06/2020.
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
import UIKit

extension NotificationCenter {

    func postOnMainThread(name: String, object anObject: Any? = nil, userInfo aUserInfo: [AnyHashable: Any]? = nil, second: Double = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + second) {
            NotificationCenter.default.post(name: Notification.Name(rawValue: name), object: anObject, userInfo: aUserInfo)
        }
    }
}
