//
//  NCGlobal.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 22/02/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
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

@objc class NCGlobal: NSObject {
    @objc static let shared: NCGlobal = {
        let instance = NCGlobal()
        return instance
    }()

    // Struct for Progress
    struct progressType {
        var progress: Float
        var totalBytes: Int64
        var totalBytesExpected: Int64
    }
    
    // Directory on Group
    @objc let appDatabaseNextcloud                  = "Library/Application Support/Nextcloud"
    @objc let appApplicationSupport                 = "Library/Application Support"
    @objc let appUserData                           = "Library/Application Support/UserData"
    @objc let appCertificates                       = "Library/Application Support/Certificates"
    @objc let appScan                               = "Library/Application Support/Scan"
    @objc let directoryProviderStorage              = "File Provider Storage"

    // Service
    @objc let serviceShareKeyChain                  = "Crypto Cloud"
    @objc let metadataKeyedUnarchiver               = "it.twsweb.nextcloud.metadata"
    @objc let refreshTask                           = "com.nextcloud.refreshTask"
    @objc let processingTask                        = "com.nextcloud.processingTask"
    
    // Nextcloud version
    @objc let nextcloudVersion12: Int               =  12
    let nextcloudVersion15: Int                     =  15
    let nextcloudVersion17: Int                     =  17
    let nextcloudVersion18: Int                     =  18
    let nextcloudVersion20: Int                     =  20

    // Database Realm
    let databaseDefault                             = "nextcloud.realm"
    let databaseSchemaVersion: UInt64               = 162
    
    // Intro selector
    @objc let introLogin: Int                       = 0
    @objc let introSignup: Int                      = 1
    
    // Avatar & Preview
    let avatarSize: CGFloat                         = 512
    @objc let sizePreview: CGFloat                  = 1024
    @objc let sizeIcon: CGFloat                     = 512
    
    // E2EE
    let e2eeMaxFileSize: UInt64                     = 524288000   // 500 MB
    let e2eePassphraseTest                          = "more over television factory tendency independence international intellectual impress interest sentence pony"
    @objc let e2eeVersion                           = "1.1"
    
    // Max Size Upload
    let uploadMaxFileSize: UInt64                   = 524288000   // 500 MB
    
    // Max Cache Proxy Video
    let maxHTTPCache: Int64                         = 10737418240 // 10 GB
    
    // NCSharePaging
    let indexPageActivity: Int                      = 0
    let indexPageComments: Int                      = 1
    let indexPageSharing: Int                       = 2
    
    // NCViewerProviderContextMenu
    let maxAutoDownload: UInt64                     = 104857600 // 100MB
    let maxAutoDownloadCellular: UInt64             = 10485760  // 10MB

    // Nextcloud unsupported
    let nextcloud_unsupported_version: Int          = 13
    
    // Layout
    let layoutList                                  = "typeLayoutList"
    let layoutGrid                                  = "typeLayoutGrid"
    
    let layoutViewMove                              = "LayoutMove"
    let layoutViewTrash                             = "LayoutTrash"
    let layoutViewOffline                           = "LayoutOffline"
    let layoutViewFavorite                          = "LayoutFavorite"
    let layoutViewFiles                             = "LayoutFiles"
    let layoutViewViewInFolder                      = "ViewInFolder"
    let layoutViewTransfers                         = "LayoutTransfers"
    let layoutViewRecent                            = "LayoutRecent"
    let layoutViewShares                            = "LayoutShares"
    
    // Button Type in Cell list/grid
    let buttonMoreMore                              = "more"
    let buttonMoreStop                              = "stop"
    
    // Text -  OnlyOffice - Collabora
    let editorText                                  = "text"
    let editorOnlyoffice                            = "onlyoffice"
    let editorCollabora                             = "collabora"

    let onlyofficeDocx                              = "onlyoffice_docx"
    let onlyofficeXlsx                              = "onlyoffice_xlsx"
    let onlyofficePptx                              = "onlyoffice_pptx"

    // Template
    let templateDocument                            = "document"
    let templateSpreadsheet                         = "spreadsheet"
    let templatePresentation                        = "presentation"
    
    // Rich Workspace
    let fileNameRichWorkspace                       = "Readme.md"
    
    @objc let dismissAfterSecond: TimeInterval      = 4
    @objc let dismissAfterSecondLong: TimeInterval  = 10
    
    // Error
    @objc let ErrorBadRequest: Int                  = 400
    @objc let ErrorResourceNotFound: Int            = 404
    @objc let ErrorConflict: Int                    = 409
    @objc let ErrorBadServerResponse: Int           = -1011
    @objc let ErrorInternalError: Int               = -99999
    @objc let ErrorFileNotSaved: Int                = -99998
    @objc let ErrorDecodeMetadata: Int              = -99997
    @objc let ErrorE2EENotEnabled: Int              = -99996
    @objc let ErrorOffline: Int                     = -99994
    @objc let ErrorCharactersForbidden: Int         = -99993
    @objc let ErrorCreationFile: Int                = -99992
    
    // Constants to identify the different permissions of a file
    @objc let permissionShared                      = "S"
    @objc let permissionCanShare                    = "R"
    @objc let permissionMounted                     = "M"
    @objc let permissionFileCanWrite                = "W"
    @objc let permissionCanCreateFile               = "C"
    @objc let permissionCanCreateFolder             = "K"
    @objc let permissionCanDelete                   = "D"
    @objc let permissionCanRename                   = "N"
    @objc let permissionCanMove                     = "V"
    
    //Share permission
    //permissions - (int) 1 = read; 2 = update; 4 = create; 8 = delete; 16 = share; 31 = all (default: 31, for public shares: 1)
    @objc let permissionReadShare: Int              = 1
    @objc let permissionUpdateShare: Int            = 2
    @objc let permissionCreateShare: Int            = 4
    @objc let permissionDeleteShare: Int            = 8
    @objc let permissionShareShare: Int             = 16
    
    @objc let permissionMinFileShare: Int           = 1
    @objc let permissionMaxFileShare: Int           = 19
    @objc let permissionMinFolderShare: Int         = 1
    @objc let permissionMaxFolderShare: Int         = 31
    @objc let permissionDefaultFileRemoteShareNoSupportShareOption: Int     = 3
    @objc let permissionDefaultFolderRemoteShareNoSupportShareOption: Int   = 15
    
    // Metadata : FileType
    @objc let metadataTypeFileAudio                 = "audio"
    @objc let metadataTypeFileCompress              = "compress"
    @objc let metadataTypeFileDirectory             = "directory"
    @objc let metadataTypeFileDocument              = "document"
    @objc let metadataTypeFileImage                 = "image"
    @objc let metadataTypeFileUnknown               = "unknow"
    @objc let metadataTypeFileVideo                 = "video"
    @objc let metadataTypeFileImagemeter            = "imagemeter"
    
    // Filename Mask and Type
    @objc let keyFileNameMask                       = "fileNameMask"
    @objc let keyFileNameType                       = "fileNameType"
    @objc let keyFileNameAutoUploadMask             = "fileNameAutoUploadMask"
    @objc let keyFileNameAutoUploadType             = "fileNameAutoUploadType"
    @objc let keyFileNameOriginal                   = "fileNameOriginal"
    @objc let keyFileNameOriginalAutoUpload         = "fileNameOriginalAutoUpload"

    // Selector
    @objc let selectorDownloadFile                  = "downloadFile"
    @objc let selectorDownloadAllFile               = "downloadAllFile"
    @objc let selectorReadFile                      = "readFile"
    @objc let selectorListingFavorite               = "listingFavorite"
    @objc let selectorLoadFileView                  = "loadFileView"
    @objc let selectorLoadFileQuickLook             = "loadFileQuickLook"
    @objc let selectorLoadCopy                      = "loadCopy"
    @objc let selectorLoadOffline                   = "loadOffline"
    @objc let selectorOpenIn                        = "openIn"
    @objc let selectorUploadAutoUpload              = "uploadAutoUpload"
    @objc let selectorUploadAutoUploadAll           = "uploadAutoUploadAll"
    @objc let selectorUploadFile                    = "uploadFile"
    @objc let selectorSaveAlbum                     = "saveAlbum"
    @objc let selectorSaveAlbumLivePhotoIMG         = "saveAlbumLivePhotoIMG"
    @objc let selectorSaveAlbumLivePhotoMOV         = "saveAlbumLivePhotoMOV"

    // Metadata : Status
    //
    // 1) wait download/upload
    // 2) in download/upload
    // 3) downloading/uploading
    // 4) done or error
    //
    @objc let metadataStatusNormal: Int             = 0

    @objc let metadataStatustypeDownload: Int       = 1

    @objc let metadataStatusWaitDownload: Int       = 2
    @objc let metadataStatusInDownload: Int         = 3
    @objc let metadataStatusDownloading: Int        = 4
    @objc let metadataStatusDownloadError: Int      = 5

    @objc let metadataStatusTypeUpload: Int         = 6

    @objc let metadataStatusWaitUpload: Int         = 7
    @objc let metadataStatusInUpload: Int           = 8
    @objc let metadataStatusUploading: Int          = 9
    @objc let metadataStatusUploadError: Int        = 10
    @objc let metadataStatusUploadForcedStart: Int  = 11
    
    // Notification Center

    @objc let notificationCenterApplicationDidEnterBackground   = "applicationDidEnterBackground"
    @objc let notificationCenterApplicationWillEnterForeground  = "applicationWillEnterForeground"

    @objc let notificationCenterInitializeMain                  = "initializeMain"
    @objc let notificationCenterChangeTheming                   = "changeTheming"
    @objc let notificationCenterChangeUserProfile               = "changeUserProfile"
    @objc let notificationCenterRichdocumentGrabFocus           = "richdocumentGrabFocus"
    @objc let notificationCenterReloadDataNCShare               = "reloadDataNCShare"
    @objc let notificationCenterCloseRichWorkspaceWebView       = "closeRichWorkspaceWebView"
    @objc let notificationCenterUpdateBadgeNumber               = "updateBadgeNumber"

    @objc let notificationCenterReloadDataSource                = "reloadDataSource"                 // userInfo: ocId?, serverUrl?
    @objc let notificationCenterReloadDataSourceNetworkForced   = "reloadDataSourceNetworkForced"    // userInfo: serverUrl?

    @objc let notificationCenterChangeStatusFolderE2EE          = "changeStatusFolderE2EE"           // userInfo: serverUrl

    @objc let notificationCenterDownloadStartFile               = "downloadStartFile"                // userInfo: ocId
    @objc let notificationCenterDownloadedFile                  = "downloadedFile"                   // userInfo: ocId, selector, errorCode, errorDescription
    @objc let notificationCenterDownloadCancelFile              = "downloadCancelFile"               // userInfo: ocId

    @objc let notificationCenterUploadStartFile                 = "uploadStartFile"                  // userInfo: ocId
    @objc let notificationCenterUploadedFile                    = "uploadedFile"                     // userInfo: ocId, ocIdTemp, errorCode, errorDescription
    @objc let notificationCenterUploadCancelFile                = "uploadCancelFile"                 // userInfo: ocId

    @objc let notificationCenterProgressTask                    = "progressTask"                     // userInfo: account, ocId, serverUrl, status, progress, totalBytes, totalBytesExpected
    
    @objc let notificationCenterCreateFolder                    = "createFolder"                     // userInfo: ocId
    @objc let notificationCenterDeleteFile                      = "deleteFile"                       // userInfo: ocId, fileNameView, typeFile, onlyLocal
    @objc let notificationCenterRenameFile                      = "renameFile"                       // userInfo: ocId, errorCode, errorDescription
    @objc let notificationCenterMoveFile                        = "moveFile"                         // userInfo: ocId, serverUrlTo
    @objc let notificationCenterCopyFile                        = "copyFile"                         // userInfo: ocId, serverUrlFrom
    @objc let notificationCenterFavoriteFile                    = "favoriteFile"                     // userInfo: ocId

    @objc let notificationCenterMenuSearchTextPDF               = "menuSearchTextPDF"
    @objc let notificationCenterMenuDetailClose                 = "menuDetailClose"
    
    @objc let notificationCenterChangedLocation                 = "changedLocation"
    @objc let notificationStatusAuthorizationChangedLocation    = "statusAuthorizationChangedLocation"
}

//DispatchQueue.main.async
//DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)
//DispatchQueue.global().async
//DispatchQueue.global(qos: .background).async

//#if targetEnvironment(simulator)
//#endif


//dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//dispatch_async(dispatch_get_main_queue(), ^{
//dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {

//#if TARGET_OS_SIMULATOR
//#endif
