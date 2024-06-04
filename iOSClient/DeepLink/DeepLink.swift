//
//  DeepLink.swift
//  Nextcloud
//
//  Created by Amrut Waghmare on 29/05/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation

enum DeepLink: String {
    case openFiles = "openFiles"                //nextcloud://openFiles
    case openFavorites = "openFavorites"        //nextcloud://openFavorites
    case openMedia = "openMedia"                //nextcloud://openMedia
    case openShared = "openShared"              //nextcloud://openShared
    case openOffline = "openOffline"            //nextcloud://openOffline
    case openNotifications = "openNotifications"//nextcloud://openNotifications
    case openDeleted = "openDeleted"            //nextcloud://openDeleted
    case openSettings = "openSettings"          //nextcloud://openSettings
    case openAutoUpload = "openAutoUpload"      //nextcloud://openAutoUpload
    case openUrl = "openUrl"                    //nextcloud://openUrl?url=https://nextcloud.com
    case createNew = "createNew"                //nextcloud://createNew
    case checkAppUpdate = "checkAppUpdate"      //nextcloud://checkAppUpdate
}
