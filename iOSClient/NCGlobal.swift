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

class NCGlobal: NSObject {
    static let shared: NCGlobal = {
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

    func getHeightHeaderEmptyData(view: UIView, portraitOffset: CGFloat, landscapeOffset: CGFloat, isHeaderMenuTransferViewEnabled: Bool = false) -> CGFloat {
        var height: CGFloat = 0
        if UIDevice.current.orientation.isPortrait {
            height = (view.frame.height / 2) - (view.safeAreaInsets.top / 2) + portraitOffset
        } else {
            height = (view.frame.height / 2) + landscapeOffset + CGFloat(isHeaderMenuTransferViewEnabled ? 35 : 0)
        }
        return height
    }

    // Convert a string to an integer evenly
    // hash is hex string
    static func hashToInt(hash: String, maximum: Int) -> Int {
        let result = hash.compactMap(\.hexDigitValue)
        return result.reduce(0, { $0 + $1 }) % maximum
    }

    // ENUM
    //
    public enum TypeFilterScanDocument: String {
        case document = "document"
        case original = "original"
    }

    // Sharing & Comments
    //
    var disableSharesView: Bool {
        if !capabilityFileSharingApiEnabled && !capabilityFilesComments && capabilityActivity.isEmpty {
            return true
        } else {
            return false
        }
    }

    // Directory on Group
    //
    let directoryProviderStorage                    = "File Provider Storage"
    let appApplicationSupport                       = "Library/Application Support"
    let appCertificates                             = "Library/Application Support/Certificates"
    let appDatabaseNextcloud                        = "Library/Application Support/Nextcloud"
    let appScan                                     = "Library/Application Support/Scan"
    let appUserData                                 = "Library/Application Support/UserData"

    // Service
    //
    let metadataKeyedUnarchiver                     = "it.twsweb.nextcloud.metadata"
    let refreshTask                                 = "com.nextcloud.refreshTask"
    let processingTask                              = "com.nextcloud.processingTask"

    // App
    //
    let appName                                     = "files"
    let appScheme                                   = "nextcloud"
    let talkName                                    = "talk-message"
    let spreedName                                  = "spreed"
    let twoFactorNotificatioName                    = "twofactor_nextcloud_notification"

    // Nextcloud version
    //
    let nextcloudVersion12: Int                     = 12
    let nextcloudVersion15: Int                     = 15
    let nextcloudVersion17: Int                     = 17
    let nextcloudVersion18: Int                     = 18
    let nextcloudVersion20: Int                     = 20
    let nextcloudVersion23: Int                     = 23
    let nextcloudVersion24: Int                     = 24
    let nextcloudVersion25: Int                     = 25
    let nextcloudVersion26: Int                     = 26
    let nextcloudVersion27: Int                     = 27
    let nextcloudVersion28: Int                     = 28

    // Nextcloud unsupported
    //
    let nextcloud_unsupported_version: Int = 16

    // Intro selector
    //
    let introLogin: Int                             = 0
    let introSignup: Int                            = 1

    // Avatar & Preview size
    //
    let avatarSize: Int                             = 128 * Int(UIScreen.main.scale)
    let avatarSizeRounded: Int                      = 128
    let sizePreview: Int                            = 1024
    let sizeIcon: Int                               = 512

    // E2EE
    //
    let e2eePassphraseTest                          = "more over television factory tendency independence international intellectual impress interest sentence pony"
    let e2eeVersions                                = ["1.1", "1.2", "2.0"]
    let e2eeVersionV11                              = "1.1"
    let e2eeVersionV12                              = "1.2"
    let e2eeVersionV20                              = "2.0"

    // CHUNK
    let chunkSizeMBCellular                         = 10000000
    let chunkSizeMBEthernetOrWiFi                   = 100000000

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
    let layoutPhotoRatio                            = "typeLayoutPhotoRatio"
    let layoutPhotoSquare                           = "typeLayoutPhotoSquare"

    let layoutViewTrash                             = "LayoutTrash"
    let layoutViewOffline                           = "LayoutOffline"
    let layoutViewFavorite                          = "LayoutFavorite"
    let layoutViewFiles                             = "LayoutFiles"
    let layoutViewTransfers                         = "LayoutTransfers"
    let layoutViewRecent                            = "LayoutRecent"
    let layoutViewShares                            = "LayoutShares"
    let layoutViewShareExtension                    = "LayoutShareExtension"
    let layoutViewGroupfolders                      = "LayoutGroupfolders"
    let layoutViewMedia                             = "LayoutMedia"

    // Button Type in Cell list/grid
    //
    let buttonMoreMore                              = "more"
    let buttonMoreStop                              = "stop"
    let buttonMoreLock                              = "moreLock"

    // Standard height sections header/footer
    //
    let heightButtonsView: CGFloat                  = 50
    let heightHeaderTransfer: CGFloat               = 50
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
    let fileNameRichWorkspace = "Readme.md"

    // Image extension
    //
    let storageExtIcon                              = ".small.ico"
    let storageExtPreview                           = ".preview.ico"

    // ContentPresenter
    //
    let dismissAfterSecond: TimeInterval        = 4
    let dismissAfterSecondLong: TimeInterval    = 10

    // Error
    //
    let errorRequestExplicityCancelled: Int     = 15
    let errorNotModified: Int                   = 304
    let errorBadRequest: Int                    = 400
    let errorUnauthorized401: Int               = 401
    let errorForbidden: Int                     = 403
    let errorResourceNotFound: Int              = 404
    let errorMethodNotSupported: Int            = 405
    let errorConflict: Int                      = 409
    let errorPreconditionFailed: Int            = 412
    let errorUnsupportedMediaType: Int          = 415
    let errorInternalServerError: Int           = 500
    let errorQuota: Int                         = 507
    let errorUnauthorized997: Int               = 997
    let errorExplicitlyCancelled: Int           = -999
    let errorConnectionLost: Int                = -1005
    let errorNetworkNotAvailable: Int           = -1009
    let errorBadServerResponse: Int             = -1011
    let errorInternalError: Int                 = -99999
    let errorFileNotSaved: Int                  = -99998
    let errorOffline: Int                       = -99997
    let errorCharactersForbidden: Int           = -99996
    let errorCreationFile: Int                  = -99995
    let errorReadFile: Int                      = -99994
    let errorUnauthorizedFilesPasscode: Int     = -99993
    let errorDisableFilesApp: Int               = -99992
    let errorUnexpectedResponseFromDB: Int      = -99991
    // E2EE
    let errorE2EENotEnabled: Int                = -98000
    let errorE2EEVersion: Int                   = -98001
    let errorE2EEKeyChecksums: Int              = -98002
    let errorE2EEKeyEncodeMetadata: Int         = -98003
    let errorE2EEKeyDecodeMetadata: Int         = -98004
    let errorE2EEKeyVerifySignature: Int        = -98005
    let errorE2EEKeyCiphertext: Int             = -98006
    let errorE2EEKeyFiledropCiphertext: Int     = -98007
    let errorE2EEJSon: Int                      = -98008
    let errorE2EELock: Int                      = -98009
    let errorE2EEEncryptFile: Int               = -98010
    let errorE2EEEncryptPayloadFile: Int        = -98011
    let errorE2EECounter: Int                   = -98012
    let errorE2EEGenerateKey: Int               = -98013
    let errorE2EEEncodedKey: Int                = -98014
    let errorE2EENoUserFound: Int               = -98015
    let errorE2EEUploadInProgress: Int          = -98016

    // Selector
    //
    let selectorDownloadFile                    = "downloadFile"
    let selectorReadFile                        = "readFile"
    let selectorListingFavorite                 = "listingFavorite"
    let selectorLoadFileView                    = "loadFileView"
    let selectorLoadFileQuickLook               = "loadFileQuickLook"
    let selectorOpenIn                          = "openIn"
    let selectorUploadAutoUpload                = "uploadAutoUpload"
    let selectorUploadAutoUploadAll             = "uploadAutoUploadAll"
    let selectorUploadFile                      = "uploadFile"
    let selectorUploadFileNODelete              = "UploadFileNODelete"
    let selectorUploadFileShareExtension        = "uploadFileShareExtension"
    let selectorSaveAlbum                       = "saveAlbum"
    let selectorSaveAsScan                      = "saveAsScan"
    let selectorOpenDetail                      = "openDetail"
    let selectorSynchronizationOffline          = "synchronizationOffline"

    // Metadata : Status
    //
    //   0 normal
    // ± 1 wait download/upload
    // ± 2 downloading/uploading
    // ± 3 error
    //
    let metadataStatusNormal: Int               = 0

    let metadataStatusWaitDownload: Int         = -1
    let metadataStatusDownloading: Int          = -2
    let metadataStatusDownloadError: Int        = -3

    let metadataStatusWaitUpload: Int           = 1
    let metadataStatusUploading: Int            = 2
    let metadataStatusUploadError: Int          = 3

    //  Hidden files included in the read
    //
    let includeHiddenFiles: [String] = [".LivePhoto"]

    // Auto upload subfolder granularity
    //
    let subfolderGranularityDaily               = 2
    let subfolderGranularityMonthly             = 1
    let subfolderGranularityYearly              = 0

    // Notification Center
    //
    let notificationCenterChangeUser                            = "changeUser"
    let notificationCenterChangeTheming                         = "changeTheming"
    let notificationCenterRichdocumentGrabFocus                 = "richdocumentGrabFocus"
    let notificationCenterReloadDataNCShare                     = "reloadDataNCShare"
    let notificationCenterCloseRichWorkspaceWebView             = "closeRichWorkspaceWebView"
    let notificationCenterReloadAvatar                          = "reloadAvatar"
    let notificationCenterCreateMediaCacheEnded                 = "createMediaCacheEnded"

    let notificationCenterReloadDataSource                      = "reloadDataSource"
    let notificationCenterReloadDataSourceNetwork               = "reloadDataSourceNetwork"         // userInfo: withQueryDB

    let notificationCenterChangeStatusFolderE2EE                = "changeStatusFolderE2EE"          // userInfo: serverUrl

    let notificationCenterDownloadStartFile                     = "downloadStartFile"               // userInfo: ocId, serverUrl, account
    let notificationCenterDownloadedFile                        = "downloadedFile"                  // userInfo: ocId, serverUrl, account, selector, error
    let notificationCenterDownloadCancelFile                    = "downloadCancelFile"              // userInfo: ocId, serverUrl, account

    let notificationCenterUploadStartFile                       = "uploadStartFile"                 // userInfo: ocId, serverUrl, account, fileName, sessionSelector
    let notificationCenterUploadedFile                          = "uploadedFile"                    // userInfo: ocId, serverUrl, account, fileName, ocIdTemp, error
    let notificationCenterUploadedLivePhoto                     = "uploadedLivePhoto"               // userInfo: ocId, serverUrl, account, fileName, ocIdTemp, error

    let notificationCenterUploadCancelFile                      = "uploadCancelFile"                // userInfo: ocId, serverUrl, account

    let notificationCenterProgressTask                          = "progressTask"                    // userInfo: account, ocId, serverUrl, status, chunk, e2eEncrypted, progress, totalBytes, totalBytesExpected

    let notificationCenterUpdateBadgeNumber                     = "updateBadgeNumber"               // userInfo: counterDownload, counterUpload

    let notificationCenterCreateFolder                          = "createFolder"                    // userInfo: ocId, serverUrl, account, withPush, sceneIdentifier
    let notificationCenterDeleteFile                            = "deleteFile"                      // userInfo: [ocId], onlyLocalCache, error
    let notificationCenterMoveFile                              = "moveFile"                        // userInfo: [ocId], error, dragdrop
    let notificationCenterCopyFile                              = "copyFile"                        // userInfo: [ocId], error, dragdrop
    let notificationCenterRenameFile                            = "renameFile"                      // userInfo: ocId, account, indexPath
    let notificationCenterFavoriteFile                          = "favoriteFile"                    // userInfo: ocId, serverUrl

    let notificationCenterOperationReadFile                     = "operationReadFile"               // userInfo: ocId

    let notificationCenterMenuSearchTextPDF                     = "menuSearchTextPDF"
    let notificationCenterMenuGotToPageInPDF                    = "menuGotToPageInPDF"

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
    let configuration_disable_more_external_site                = "disable_more_external_site"
    let configuration_disable_openin_file                       = "disable_openin_file"

    // CAPABILITIES
    //
    var capabilityServerVersionMajor: Int                       = 0
    var capabilityServerVersion: String                         = ""

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
    var capabilityThemingName: String                           = ""
    var capabilityThemingSlogan: String                         = ""

    var capabilityE2EEEnabled: Bool                             = false
    var capabilityE2EEApiVersion: String                        = ""

    var capabilityRichDocumentsEnabled: Bool                    = false
    var capabilityRichDocumentsMimetypes = ThreadSafeArray<String>()
    var capabilityActivity = ThreadSafeArray<String>()
    var capabilityNotification = ThreadSafeArray<String>()

    var capabilityFilesUndelete: Bool                           = false
    var capabilityFilesLockVersion: String                      = ""    // NC 24
    var capabilityFilesComments: Bool                           = false // NC 20
    var capabilityFilesBigfilechunking: Bool                    = false

    var capabilityUserStatusEnabled: Bool                       = false
    var capabilityExternalSites: Bool                           = false
    var capabilityGroupfoldersEnabled: Bool                     = false // NC27
    var capabilityAssistantEnabled: Bool                        = false // NC28
    var isLivePhotoServerAvailable: Bool {                              // NC28
        return capabilityServerVersionMajor >= nextcloudVersion28
    }

    var capabilitySecurityGuardDiagnostics                      = false

    var capabilityForbiddenFileNames: [String]                    = []
    var capabilityForbiddenFileNameBasenames: [String]            = []
    var capabilityForbiddenFileNameCharacters: [String]           = []
    var capabilityForbiddenFileNameExtensions: [String]           = []

    // MORE NEXTCLOUD APPS
    let talkSchemeUrl                                           = "nextcloudtalk://"
    let notesSchemeUrl                                          = "nextcloudnotes://"
    let talkAppStoreUrl                                         = "https://apps.apple.com/in/app/nextcloud-talk/id1296825574"
    let notesAppStoreUrl                                        = "https://apps.apple.com/in/app/nextcloud-notes/id813973264"
    let moreAppsUrl                                             = "itms-apps://search.itunes.apple.com/WebObjects/MZSearch.woa/wa/search?media=software&term=nextcloud"

    // SNAPSHOT PREVIEW
    //
    let defaultSnapshotConfiguration = "DefaultPreviewConfiguration"

    // FORBIDDEN CHARACTERS
    //
    // TODO: Remove this
    let forbiddenCharacters = ["/", "\\", ":", "\"", "|", "?", "*", "<", ">"]

    // DIAGNOSTICS CLIENTS
    //
    let diagnosticIssueSyncConflicts        = "sync_conflicts"
    let diagnosticIssueProblems             = "problems"
    let diagnosticIssueVirusDetected        = "virus_detected"
    let diagnosticIssueE2eeErrors           = "e2ee_errors"

    let diagnosticProblemsForbidden         = "CHARACTERS_FORBIDDEN"
    let diagnosticProblemsBadResponse       = "BAD_SERVER_RESPONSE"
    let diagnosticProblemsUploadServerError = "UploadError.SERVER_ERROR"

    // MEDIA LAYOUT
    //
    let mediaLayoutRatio                    = "mediaLayoutRatio"
    let mediaLayoutSquare                   = "mediaLayoutSquare"

    // DRAG & DROP
    //
    let metadataOcIdDataRepresentation      = "text/com.nextcloud.ocId"

    // GROUP AMIN
    //
    let groupAdmin                          = "admin"
}
