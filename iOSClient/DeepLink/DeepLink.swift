//
//  DeepLink.swift
//  Nextcloud
//
//  Created by Amrut Waghmare on 29/05/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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
