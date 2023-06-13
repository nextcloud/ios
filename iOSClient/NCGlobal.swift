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

import UIKit
import SwiftyJSON

class NCGlobal: NSObject {
    @objc static let shared: NCGlobal = {
        let instance = NCGlobal()
        return instance
    }()

    func usernameToColor(_ username: String) -> CGColor {
        // Normalize hash
        let lowerUsername = username.lowercased()
        var hash: String

        let regex = try! NSRegularExpression(pattern: "^([0-9a-f]{4}-?){8}$")
        let matches = regex.matches(
            in: username,
            range: NSRange(username.startIndex..., in: username))

        if !matches.isEmpty {
            // Already a md5 hash?
            // done, use as is.
            hash = lowerUsername
        } else {
            hash = lowerUsername.md5()
        }

        hash = hash.replacingOccurrences(of: "[^0-9a-f]", with: "", options: .regularExpression)

        // userColors has 18 colors by default
        let userColorIx = NCGlobal.hashToInt(hash: hash, maximum: 18)
        return NCBrandColor.shared.userColors[userColorIx]
    }

    // Convert a string to an integer evenly
    // hash is hex string
    static func hashToInt(hash: String, maximum: Int) -> Int {
        let result = hash.compactMap(\.hexDigitValue)
        return result.reduce(0, { $0 + $1 }) % maximum
    }

    // Struct for Progress
    //
    struct progressType {
        var progress: Float
        var totalBytes: Int64
        var totalBytesExpected: Int64
    }

    // Directory on Group
    //
    @objc let directoryProviderStorage              = "File Provider Storage"
    @objc let appApplicationSupport                 = "Library/Application Support"
    @objc let appCertificates                       = "Library/Application Support/Certificates"
    @objc let appDatabaseNextcloud                  = "Library/Application Support/Nextcloud"
    @objc let appScan                               = "Library/Application Support/Scan"
    @objc let appUserData                           = "Library/Application Support/UserData"

    // Service
    //
    @objc let serviceShareKeyChain                  = "Crypto Cloud"
    let metadataKeyedUnarchiver                     = "it.twsweb.nextcloud.metadata"
    let refreshTask                                 = "com.nextcloud.refreshTask"
    let processingTask                              = "com.nextcloud.processingTask"

    // Name
    //
    @objc let appName                               = "files"
    @objc let talkName                              = "talk-message"
    @objc let appScheme                             = "nextcloud"

    // Nextcloud version
    //
    let nextcloudVersion12: Int                     =  12
    let nextcloudVersion15: Int                     =  15
    let nextcloudVersion17: Int                     =  17
    let nextcloudVersion18: Int                     =  18
    let nextcloudVersion20: Int                     =  20
    let nextcloudVersion23: Int                     =  23
    let nextcloudVersion24: Int                     =  24
    let nextcloudVersion25: Int                     =  25
    let nextcloudVersion26: Int                     =  26
    let nextcloudVersion27: Int                     =  27

    // Nextcloud unsupported
    //
    let nextcloud_unsupported_version: Int          = 16

    // Intro selector
    //
    @objc let introLogin: Int                       = 0
    let introSignup: Int                            = 1

    // Varie size GUI
    //
    @objc let heightCellSettings: CGFloat           = 50

    // Avatar & Preview size
    //
    let avatarSize: Int                             = 128 * Int(UIScreen.main.scale)
    let avatarSizeRounded: Int                      = 128
    let sizePreview: Int                            = 1024
    let sizeIcon: Int                               = 512

    // E2EE
    //
    let e2eeMaxFileSize: UInt64                     = 500000000     // 500 MB
    let e2eePassphraseTest                          = "more over television factory tendency independence international intellectual impress interest sentence pony"
    @objc let e2eeReadVersions                      = ["1.1", "1.2"]

    // Video
    //
    let maxHTTPCache: Int64                         = 10000000000   // 10 GB
    let fileNameVideoEncoded: String                = "video_encoded.mp4"

    // NCViewerProviderContextMenu
    //
    let maxAutoDownload: UInt64                     = 50000000      // 50MB
    let maxAutoDownloadCellular: UInt64             = 10000000      // 10MB

    // Layout
    //
    let layoutList                                  = "typeLayoutList"
    let layoutGrid                                  = "typeLayoutGrid"

    let layoutViewMove                              = "LayoutMove"
    let layoutViewTrash                             = "LayoutTrash"
    let layoutViewOffline                           = "LayoutOffline"
    let layoutViewFavorite                          = "LayoutFavorite"
    let layoutViewFiles                             = "LayoutFiles"
    let layoutViewViewInFolder                      = "LayoutViewInFolder"
    let layoutViewTransfers                         = "LayoutTransfers"
    let layoutViewRecent                            = "LayoutRecent"
    let layoutViewShares                            = "LayoutShares"
    let layoutViewShareExtension                    = "LayoutShareExtension"
    let layoutViewGroupfolders                      = "LayoutGroupfolders"

    // Button Type in Cell list/grid
    //
    let buttonMoreMore                              = "more"
    let buttonMoreStop                              = "stop"
    let buttonMoreLock                              = "moreLock"

    // Standard height sections header/footer
    //
    let heightButtonsCommand: CGFloat               = 50
    let heightButtonsView: CGFloat                  = 50
    let heightSection: CGFloat                      = 30
    let heightFooter: CGFloat                       = 1
    let heightFooterButton: CGFloat                 = 30
    let endHeightFooter: CGFloat                    = 85

    // Text -  OnlyOffice - Collabora - QuickLook
    //
    let editorText                                  = "text"
    let editorOnlyoffice                            = "onlyoffice"
    let editorCollabora                             = "collabora"
    let editorQuickLook                             = "quicklook"

    let onlyofficeDocx                              = "onlyoffice_docx"
    let onlyofficeXlsx                              = "onlyoffice_xlsx"
    let onlyofficePptx                              = "onlyoffice_pptx"

    // Template
    //
    let templateDocument                            = "document"
    let templateSpreadsheet                         = "spreadsheet"
    let templatePresentation                        = "presentation"

    // Rich Workspace
    //
    let fileNameRichWorkspace                       = "Readme.md"

    // Extension
    //
    @objc let extensionPreview                      = "ico"

    // ContentPresenter
    //
    @objc let dismissAfterSecond: TimeInterval      = 4
    @objc let dismissAfterSecondLong: TimeInterval  = 10

    // Error
    //
    @objc let errorRequestExplicityCancelled: Int   = 15
    @objc let errorNotModified: Int                 = 304
    @objc let errorBadRequest: Int                  = 400
    @objc let errorUnauthorized401: Int             = 401
    @objc let errorForbidden: Int                   = 403
    @objc let errorResourceNotFound: Int            = 404
    @objc let errordMethodNotSupported: Int         = 405
    @objc let errorConflict: Int                    = 409
    @objc let errorPreconditionFailed: Int          = 412
    @objc let errorUnauthorized997: Int             = 997
    @objc let errorConnectionLost: Int              = -1005
    @objc let errorNetworkNotAvailable: Int         = -1009
    @objc let errorBadServerResponse: Int           = -1011
    @objc let errorInternalError: Int               = -99999
    @objc let errorFileNotSaved: Int                = -99998
    @objc let errorDecodeMetadata: Int              = -99997
    @objc let errorE2EENotEnabled: Int              = -99996
    @objc let errorE2EE: Int                        = -99995
    @objc let errorOffline: Int                     = -99994
    @objc let errorCharactersForbidden: Int         = -99993
    @objc let errorCreationFile: Int                = -99992
    @objc let errorReadFile: Int                    = -99991
    @objc let errorUnauthorizedFilesPasscode: Int   = -99990
    @objc let errorDisableFilesApp: Int             = -99989

    // Constants to identify the different permissions of a file
    //
    @objc let permissionShared                      = "S"
    @objc let permissionCanShare                    = "R"
    @objc let permissionMounted                     = "M"
    @objc let permissionFileCanWrite                = "W"
    @objc let permissionCanCreateFile               = "C"
    @objc let permissionCanCreateFolder             = "K"
    @objc let permissionCanDelete                   = "D"
    @objc let permissionCanRename                   = "N"
    @objc let permissionCanMove                     = "V"

    // Share permission
    // permissions - (int) 1 = read; 2 = update; 4 = create; 8 = delete; 16 = share; 31 = all
    //
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

    // Filename Mask and Type
    //
    let keyFileNameMask                             = "fileNameMask"
    let keyFileNameType                             = "fileNameType"
    let keyFileNameAutoUploadMask                   = "fileNameAutoUploadMask"
    let keyFileNameAutoUploadType                   = "fileNameAutoUploadType"
    let keyFileNameOriginal                         = "fileNameOriginal"
    let keyFileNameOriginalAutoUpload               = "fileNameOriginalAutoUpload"

    // Selector
    //
    let selectorDownloadFile                        = "downloadFile"
    let selectorDownloadAllFile                     = "downloadAllFile"
    let selectorReadFile                            = "readFile"
    let selectorListingFavorite                     = "listingFavorite"
    let selectorLoadFileView                        = "loadFileView"
    let selectorLoadFileQuickLook                   = "loadFileQuickLook"
    let selectorLoadOffline                         = "loadOffline"
    let selectorOpenIn                              = "openIn"
    let selectorPrint                               = "print"
    let selectorUploadAutoUpload                    = "uploadAutoUpload"
    let selectorUploadAutoUploadAll                 = "uploadAutoUploadAll"
    let selectorUploadFile                          = "uploadFile"
    let selectorUploadFileNODelete                  = "UploadFileNODelete"
    let selectorUploadFileShareExtension            = "uploadFileShareExtension"
    let selectorSaveAlbum                           = "saveAlbum"
    let selectorSaveAlbumLivePhotoIMG               = "saveAlbumLivePhotoIMG"
    let selectorSaveAlbumLivePhotoMOV               = "saveAlbumLivePhotoMOV"
    let selectorSaveAsScan                          = "saveAsScan"
    let selectorOpenDetail                          = "openDetail"

    // Metadata : Status
    //
    // 1) wait download/upload
    // 2) in download/upload
    // 3) downloading/uploading
    // 4) done or error
    //
    let metadataStatusNormal: Int                   = 0

    let metadataStatusWaitDownload: Int             = -1
    let metadataStatusInDownload: Int               = -2
    let metadataStatusDownloading: Int              = -3
    let metadataStatusDownloadError: Int            = -4

    let metadataStatusWaitUpload: Int               = 1
    let metadataStatusInUpload: Int                 = 2
    let metadataStatusUploading: Int                = 3
    let metadataStatusUploadError: Int              = 4

    //  Hidden files included in the read
    //
    let includeHiddenFiles: [String]                = [".LivePhoto"]

    // Notification Center
    //
    @objc let notificationCenterApplicationDidEnterBackground   = "applicationDidEnterBackground"
    let notificationCenterApplicationWillEnterForeground        = "applicationWillEnterForeground"
    let notificationCenterApplicationDidBecomeActive            = "applicationDidBecomeActive"
    let notificationCenterApplicationWillResignActive           = "applicationWillResignActive"

    @objc let notificationCenterInitialize                      = "initialize"
    @objc let notificationCenterChangeTheming                   = "changeTheming"
    let notificationCenterRichdocumentGrabFocus                 = "richdocumentGrabFocus"
    let notificationCenterReloadDataNCShare                     = "reloadDataNCShare"
    let notificationCenterCloseRichWorkspaceWebView             = "closeRichWorkspaceWebView"
    let notificationCenterUpdateBadgeNumber                     = "updateBadgeNumber"               // userInfo: counter
    let notificationCenterReloadAvatar                          = "reloadAvatar"

    @objc let notificationCenterReloadDataSource                = "reloadDataSource"                // userInfo: serverUrl?
    let notificationCenterReloadDataSourceNetwork               = "reloadDataSourceNetwork"         // userInfo: serverUrl?
    let notificationCenterReloadDataSourceNetworkForced         = "reloadDataSourceNetworkForced"

    let notificationCenterChangeStatusFolderE2EE                = "changeStatusFolderE2EE"          // userInfo: serverUrl

    let notificationCenterDownloadStartFile                     = "downloadStartFile"               // userInfo: ocId, serverUrl, account
    let notificationCenterDownloadedFile                        = "downloadedFile"                  // userInfo: ocId, serverUrl, account, selector, error
    let notificationCenterDownloadCancelFile                    = "downloadCancelFile"              // userInfo: ocId, serverUrl, account

    let notificationCenterUploadStartFile                       = "uploadStartFile"                 // userInfo: ocId, serverUrl, account, fileName, sessionSelector
    @objc let notificationCenterUploadedFile                    = "uploadedFile"                    // userInfo: ocId, serverUrl, account, fileName, ocIdTemp, error
    let notificationCenterUploadCancelFile                      = "uploadCancelFile"                // userInfo: ocId, serverUrl, account

    let notificationCenterProgressTask                          = "progressTask"                    // userInfo: account, ocId, serverUrl, status, progress, totalBytes, totalBytesExpected

    let notificationCenterCreateFolder                          = "createFolder"                    // userInfo: ocId, serverUrl, account, e2ee, withPush
    let notificationCenterDeleteFile                            = "deleteFile"                      // userInfo: account, ocIds, error
    let notificationCenterRenameFile                            = "renameFile"                      // userInfo: ocId, account
    let notificationCenterMoveFile                              = "moveFile"                        // userInfo: ocId, account, serverUrlFrom
    let notificationCenterCopyFile                              = "copyFile"                        // userInfo: ocId, serverUrlTo
    let notificationCenterFavoriteFile                          = "favoriteFile"                    // userInfo: ocId, serverUrl

    let notificationCenterOperationReadFile                     = "operationReadFile"               // userInfo: ocId

    let notificationCenterMenuSearchTextPDF                     = "menuSearchTextPDF"
    let notificationCenterMenuGotToPageInPDF                    = "menuGotToPageInPDF"
    let notificationCenterMenuDetailClose                       = "menuDetailClose"

    let notificationCenterDownloadedThumbnail                   = "DownloadedThumbnail"             // userInfo: ocId

    let notificationCenterOpenMediaDetail                       = "openMediaDetail"                 // userInfo: ocId
    
    let notificationCenterDismissScanDocument                   = "dismissScanDocument"
    let notificationCenterDismissUploadAssets                   = "dismissUploadAssets"

    let notificationCenterEnableSwipeGesture                    = "enableSwipeGesture"
    let notificationCenterDisableSwipeGesture                   = "disableSwipeGesture"

    // TIP
    //
    let tipNCViewerPDFThumbnail                                 = "tipncviewerpdfthumbnail"
    let tipNCCollectionViewCommonAccountRequest                 = "tipnccollectionviewcommonaccountrequest"
    let tipNCScanAddImage                                       = "tipncscanaddimage"
    let tipNCViewerMediaDetailView                              = "tipncviewermediadetailview"
    
    // ACTION
    //
    let actionNoAction                                          = "no-action"
    let actionUploadAsset                                       = "upload-asset"
    let actionScanDocument                                      = "add-scan-document"
    let actionTextDocument                                      = "create-text-document"
    let actionVoiceMemo                                         = "create-voice-memo"
    
    // WIDGET ACTION
    //
    let widgetActionNoAction                                    = "nextcloud://open-action?action=no-action"
    let widgetActionUploadAsset                                 = "nextcloud://open-action?action=upload-asset"
    let widgetActionScanDocument                                = "nextcloud://open-action?action=add-scan-document"
    let widgetActionTextDocument                                = "nextcloud://open-action?action=create-text-document"
    let widgetActionVoiceMemo                                   = "nextcloud://open-action?action=create-voice-memo"
    
    // APPCONFIG
    //
    let configuration_brand                                     = "brand"

    let configuration_serverUrl                                 = "serverUrl"
    let configuration_username                                  = "username"
    let configuration_password                                  = "password"
    let configuration_apppassword                               = "apppassword"
    
    let configuration_disable_intro                             = "disable_intro"
    let configuration_disable_multiaccount                      = "disable_multiaccount"
    let configuration_disable_crash_service                     = "disable_crash_service"
    let configuration_disable_log                               = "disable_log"
    let configuration_disable_manage_account                    = "disable_manage_account"
    let configuration_disable_more_external_site                = "disable_more_external_site"
    let configuration_disable_openin_file                       = "disable_openin_file"

    // CAPABILITIES
    //
    var capabilityServerVersionMajor: Int                       = 0
    @objc var capabilityServerVersion: String                   = ""
    
    var capabilityFileSharingApiEnabled: Bool                   = false
    var capabilityFileSharingPubPasswdEnforced: Bool            = false
    var capabilityFileSharingPubExpireDateEnforced: Bool        = false
    var capabilityFileSharingPubExpireDateDays: Int             = 0
    var capabilityFileSharingInternalExpireDateEnforced: Bool   = false
    var capabilityFileSharingInternalExpireDateDays: Int        = 0
    var capabilityFileSharingRemoteExpireDateEnforced: Bool     = false
    var capabilityFileSharingRemoteExpireDateDays: Int          = 0
    var capabilityFileSharingDefaultPermission: Int             = 0

    var capabilityThemingColor: String                          = ""
    var capabilityThemingColorElement: String                   = ""
    var capabilityThemingColorText: String                      = ""
    @objc var capabilityThemingName: String                     = ""
    @objc var capabilityThemingSlogan: String                   = ""

    @objc var capabilityE2EEEnabled: Bool                       = false
    @objc var capabilityE2EEApiVersion: String                  = ""

    var capabilityRichdocumentsMimetypes: [String]              = []
    var capabilityActivity: [String]                            = []
    var capabilityNotification: [String]                        = []

    var capabilityFilesUndelete: Bool                           = false
    var capabilityFilesLockVersion: String                      = ""    // NC 24
    var capabilityFilesComments: Bool                           = false // NC 20

    @objc var capabilityUserStatusEnabled: Bool                 = false
    var capabilityExternalSites: Bool                           = false
    var capabilityGroupfoldersEnabled: Bool                     = false // NC27
}
