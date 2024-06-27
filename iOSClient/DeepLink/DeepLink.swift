//
//  DeepLink.swift
//  Nextcloud
//
//  Created by Amrut Waghmare on 29/05/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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

enum DeepLink: String {
    case openFiles              // nextcloud://openFiles
    case openFavorites          // nextcloud://openFavorites
    case openMedia              // nextcloud://openMedia
    case openShared             // nextcloud://openShared
    case openOffline            // nextcloud://openOffline
    case openNotifications      // nextcloud://openNotifications
    case openDeleted            // nextcloud://openDeleted
    case openSettings           // nextcloud://openSettings
    case openAutoUpload         // nextcloud://openAutoUpload
    case openUrl                // nextcloud://openUrl?url=https://nextcloud.com
    case createNew              // nextcloud://createNew
    case checkAppUpdate         // nextcloud://checkAppUpdate
}
