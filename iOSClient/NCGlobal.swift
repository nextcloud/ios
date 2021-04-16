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

class NCGlobal: NSObject {
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
    let metadataKeyedUnarchiver                     = "it.twsweb.nextcloud.metadata"
    let refreshTask                                 = "com.nextcloud.refreshTask"
    let processingTask                              = "com.nextcloud.processingTask"
    
    // Nextcloud version
    let nextcloudVersion12: Int                     =  12
    let nextcloudVersion15: Int                     =  15
    let nextcloudVersion17: Int                     =  17
    let nextcloudVersion18: Int                     =  18
    let nextcloudVersion20: Int                     =  20

    // Database Realm
    let databaseDefault                             = "nextcloud.realm"
    let databaseSchemaVersion: UInt64               = 175
    
    // Intro selector
    @objc let introLogin: Int                       = 0
    let introSignup: Int                            = 1
    
    // Avatar & Preview
    let avatarSize: CGFloat                         = 512
    let sizePreview: CGFloat                        = 1024
    let sizeIcon: CGFloat                           = 512
    
    // E2EE
    let e2eeMaxFileSize: UInt64                     = 500000000     // 500 MB
    let e2eePassphraseTest                          = "more over television factory tendency independence international intellectual impress interest sentence pony"
    @objc let e2eeVersion                           = "1.1"
    
    // Max Size Upload
    let uploadMaxFileSize: UInt64                   = 500000000     // 500 MB
        
    // Max Cache Proxy Video
    let maxHTTPCache: Int64                         = 10000000000   // 10 GB
    
    // NCSharePaging
    let indexPageActivity: Int                      = 0
    let indexPageComments: Int                      = 1
    let indexPageSharing: Int                       = 2
    
    // NCViewerProviderContextMenu
    let maxAutoDownload: UInt64                     = 100000000     // 100MB
    let maxAutoDownloadCellular: UInt64             = 10000000      // 10MB

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
    @objc let errorRequestExplicityCancelled: Int   = 15
    @objc let errorBadRequest: Int                  = 400
    @objc let errorResourceNotFound: Int            = 404
    @objc let errordMethodNotSupported: Int         = 405
    @objc let errorConflict: Int                    = 409
    @objc let errorConnectionLost: Int              = -1005
    @objc let errorBadServerResponse: Int           = -1011
    @objc let errorInternalError: Int               = -99999
    @objc let errorFileNotSaved: Int                = -99998
    @objc let errorDecodeMetadata: Int              = -99997
    @objc let errorE2EENotEnabled: Int              = -99996
    @objc let errorOffline: Int                     = -99994
    @objc let errorCharactersForbidden: Int         = -99993
    @objc let errorCreationFile: Int                = -99992
    @objc let errorReadFile: Int                    = -99991
    
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
    let keyFileNameMask                             = "fileNameMask"
    let keyFileNameType                             = "fileNameType"
    let keyFileNameAutoUploadMask                   = "fileNameAutoUploadMask"
    let keyFileNameAutoUploadType                   = "fileNameAutoUploadType"
    let keyFileNameOriginal                         = "fileNameOriginal"
    let keyFileNameOriginalAutoUpload               = "fileNameOriginalAutoUpload"

    // Selector
    let selectorDownloadFile                        = "downloadFile"
    let selectorDownloadAllFile                     = "downloadAllFile"
    let selectorReadFile                            = "readFile"
    let selectorListingFavorite                     = "listingFavorite"
    let selectorLoadFileView                        = "loadFileView"
    let selectorLoadFileQuickLook                   = "loadFileQuickLook"
    let selectorLoadCopy                            = "loadCopy"
    let selectorLoadOffline                         = "loadOffline"
    let selectorOpenIn                              = "openIn"
    let selectorPrint                               = "print"
    let selectorUploadAutoUpload                    = "uploadAutoUpload"
    let selectorUploadAutoUploadAll                 = "uploadAutoUploadAll"
    let selectorUploadFile                          = "uploadFile"
    let selectorSaveAlbum                           = "saveAlbum"
    let selectorSaveAlbumLivePhotoIMG               = "saveAlbumLivePhotoIMG"
    let selectorSaveAlbumLivePhotoMOV               = "saveAlbumLivePhotoMOV"

    // Metadata : Status
    //
    // 1) wait download/upload
    // 2) in download/upload
    // 3) downloading/uploading
    // 4) done or error
    //
    let metadataStatusNormal: Int                   = 0

    let metadataStatustypeDownload: Int             = 1

    let metadataStatusWaitDownload: Int             = 2
    let metadataStatusInDownload: Int               = 3
    let metadataStatusDownloading: Int              = 4
    let metadataStatusDownloadError: Int            = 5

    let metadataStatusTypeUpload: Int               = 6

    let metadataStatusWaitUpload: Int               = 7
    let metadataStatusInUpload: Int                 = 8
    let metadataStatusUploading: Int                = 9
    let metadataStatusUploadError: Int              = 10
    let metadataStatusUploadForcedStart: Int        = 11
    
    // Notification Center

    @objc let notificationCenterApplicationDidEnterBackground   = "applicationDidEnterBackground"
    let notificationCenterApplicationWillEnterForeground        = "applicationWillEnterForeground"
    let notificationCenterApplicationDidBecomeActive            = "applicationDidBecomeActive"

    @objc let notificationCenterInitializeMain                  = "initializeMain"
    @objc let notificationCenterChangeTheming                   = "changeTheming"
    let notificationCenterRichdocumentGrabFocus                 = "richdocumentGrabFocus"
    let notificationCenterReloadDataNCShare                     = "reloadDataNCShare"
    let notificationCenterCloseRichWorkspaceWebView             = "closeRichWorkspaceWebView"
    let notificationCenterUpdateBadgeNumber                     = "updateBadgeNumber"

    @objc let notificationCenterReloadDataSource                = "reloadDataSource"                 // userInfo: ocId?, serverUrl?
    let notificationCenterReloadDataSourceNetworkForced         = "reloadDataSourceNetworkForced"    // userInfo: serverUrl?

    let notificationCenterChangeStatusFolderE2EE                = "changeStatusFolderE2EE"           // userInfo: serverUrl

    let notificationCenterDownloadStartFile                     = "downloadStartFile"                // userInfo: ocId
    let notificationCenterDownloadedFile                        = "downloadedFile"                   // userInfo: ocId, selector, errorCode, errorDescription
    let notificationCenterDownloadCancelFile                    = "downloadCancelFile"               // userInfo: ocId

    let notificationCenterUploadStartFile                       = "uploadStartFile"                  // userInfo: ocId
    @objc let notificationCenterUploadedFile                    = "uploadedFile"                     // userInfo: ocId, ocIdTemp, errorCode, errorDescription
    let notificationCenterUploadCancelFile                      = "uploadCancelFile"                 // userInfo: ocId, serverUrl, account

    let notificationCenterProgressTask                          = "progressTask"                     // userInfo: account, ocId, serverUrl, status, progress, totalBytes, totalBytesExpected
    
    let notificationCenterCreateFolder                          = "createFolder"                     // userInfo: ocId
    let notificationCenterDeleteFile                            = "deleteFile"                       // userInfo: ocId, fileNameView, typeFile, onlyLocal
    let notificationCenterRenameFile                            = "renameFile"                       // userInfo: ocId, errorCode, errorDescription
    let notificationCenterMoveFile                              = "moveFile"                         // userInfo: ocId, serverUrlTo
    let notificationCenterCopyFile                              = "copyFile"                         // userInfo: ocId, serverUrlFrom
    let notificationCenterFavoriteFile                          = "favoriteFile"                     // userInfo: ocId

    let notificationCenterMenuSearchTextPDF                     = "menuSearchTextPDF"
    let notificationCenterMenuDetailClose                       = "menuDetailClose"
    
    let notificationCenterChangedLocation                       = "changedLocation"
    let notificationStatusAuthorizationChangedLocation          = "statusAuthorizationChangedLocation"
}

//let rootView = UIApplication.shared.keyWindow?.rootViewController?.view

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
