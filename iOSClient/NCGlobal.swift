// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2021 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

final class NCGlobal: Sendable {
    static let shared = NCGlobal()

    init() { }

    // ENUM
    //
    public enum TypeFilterScanDocument: String {
        case document = "document"
        case original = "original"
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
    let termsOfServiceName                          = "terms_of_service"

    // Nextcloud version
    //
    let nextcloudVersion18: Int                     = 18
    let nextcloudVersion20: Int                     = 20
    let nextcloudVersion23: Int                     = 23
    let nextcloudVersion24: Int                     = 24
    let nextcloudVersion25: Int                     = 25
    let nextcloudVersion26: Int                     = 26
    let nextcloudVersion27: Int                     = 27
    let nextcloudVersion28: Int                     = 28
    let nextcloudVersion30: Int                     = 30
    let nextcloudVersion31: Int                     = 31

    // Nextcloud unsupported
    //
    let nextcloud_unsupported_version: Int = 17

    // Intro selector
    //
    let introLogin: Int                             = 0
    let introSignUpWithProvider: Int                = 1

    // Avatar
    //
    let avatarSize: Int                             = 128 * Int(UIScreen.main.scale)
    let avatarSizeRounded: Int                      = 128

    // Preview size
    //
    let size1024: CGSize                            = CGSize(width: 1024, height: 1024)
    let size512: CGSize                             = CGSize(width: 512, height: 512)
    let size256: CGSize                             = CGSize(width: 256, height: 256)
    // Image extension
    let previewExt1024                              = ".1024.preview.jpg"
    let previewExt512                               = ".512.preview.jpg"
    let previewExt256                               = ".256.preview.jpg"

    func getSizeExtension(column: Int) -> String {
        if column == 0 { return previewExt256 }
        let width = UIScreen.main.bounds.width / CGFloat(column)

         switch (width * 4) {
         case 0...384:
              return previewExt256
         case 385...768:
             return previewExt512
         default:
             return previewExt1024
         }
    }

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
    let buttonMoreLock                              = "moreLock"

    // Rich Workspace
    //
    let fileNameRichWorkspace                       = "Readme.md"

    // ContentPresenter
    //
    let dismissAfterSecond: TimeInterval        = 4
    let dismissAfterSecondLong: TimeInterval    = 7

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
    let errorMaintenance: Int                   = 503
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
    let errorIncorrectFileName: Int             = -99990

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

    let metadataStatusWaitCreateFolder: Int     = 10
    let metadataStatusWaitDelete: Int           = 11
    let metadataStatusWaitRename: Int           = 12
    let metadataStatusWaitFavorite: Int         = 13
    let metadataStatusWaitCopy: Int             = 14
    let metadataStatusWaitMove: Int             = 15

    let metadataStatusUploadingAllMode          = [1,2,3]
    let metadataStatusDownloadingAllMode        = [-1, -2, -3]
    let metadataStatusForScreenAwake            = [-1, -2, 1, 2]
    let metadataStatusHideInView                = [1, 2, 3, 11]
    let metadataStatusWaitWebDav                = [10, 11, 12, 13, 14, 15]

    // Auto upload subfolder granularity
    //
    let subfolderGranularityDaily               = 2
    let subfolderGranularityMonthly             = 1
    let subfolderGranularityYearly              = 0

    // Notification Center
    //
    let notificationCenterChangeUser                            = "changeUser"                      // userInfo: account, controller
    let notificationCenterChangeTheming                         = "changeTheming"                   // userInfo: account
    let notificationCenterRichdocumentGrabFocus                 = "richdocumentGrabFocus"
    let notificationCenterReloadDataNCShare                     = "reloadDataNCShare"
    let notificationCenterCloseRichWorkspaceWebView             = "closeRichWorkspaceWebView"
    let notificationCenterReloadAvatar                          = "reloadAvatar"
    let notificationCenterClearCache                            = "clearCache"
    let notificationCenterCheckUserDelaultErrorDone             = "checkUserDelaultErrorDone"       // userInfo: account, controller
    let notificationCenterUpdateNotification                    = "updateNotification"

    let notificationCenterMenuSearchTextPDF                     = "menuSearchTextPDF"
    let notificationCenterMenuGotToPageInPDF                    = "menuGotToPageInPDF"

    let notificationCenterOpenMediaDetail                       = "openMediaDetail"                 // userInfo: ocId

    let notificationCenterDismissScanDocument                   = "dismissScanDocument"
    let notificationCenterDismissUploadAssets                   = "dismissUploadAssets"

    let notificationCenterEnableSwipeGesture                    = "enableSwipeGesture"
    let notificationCenterDisableSwipeGesture                   = "disableSwipeGesture"

    let notificationCenterPlayerIsPlaying                       = "playerIsPlaying"
    let notificationCenterPlayerStoppedPlaying                  = "playerStoppedPlaying"

    // Networking Status
    let networkingStatusCreateFolder                            = "statusCreateFolder"
    let networkingStatusDelete                                  = "statusDelete"
    let networkingStatusRename                                  = "statusRename"
    let networkingStatusFavorite                                = "statusFavorite"

    let networkingStatusDownloading                             = "statusDownloading"
    let networkingStatusDownloaded                              = "statusDownloaded"
    let networkingStatusDownloadCancel                          = "statusDownloadCancel"

    let networkingStatusUploading                               = "statusUploading"
    let networkingStatusUploaded                                = "statusUploaded"
    let networkingStatusUploadedLivePhoto                       = "statusUploadedLivePhoto"
    let networkingStatusUploadCancel                            = "statusUploadCancel"


    let networkingStatusReloadAvatar                            = "statusReloadAvatar"


    // TIP
    //
    let tipPDFThumbnail                                         = "tipPDFThumbnail"
    let tipAccountRequest                                       = "tipAccountRequest"
    let tipScanAddImage                                         = "tipScanAddImage"
    let tipMediaDetailView                                      = "tipMediaDetailView"
    let tipAutoUploadButton                                     = "tipAutoUploadButton"

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
    let configuration_enforce_passcode_lock                     = "enforce_passcode_lock"

    // MORE NEXTCLOUD APPS
    //
    let talkSchemeUrl                                           = "nextcloudtalk://"
    let notesSchemeUrl                                          = "nextcloudnotes://"
    let talkAppStoreUrl                                         = "https://apps.apple.com/in/app/nextcloud-talk/id1296825574"
    let notesAppStoreUrl                                        = "https://apps.apple.com/in/app/nextcloud-notes/id813973264"
    let moreAppsUrl                                             = "itms-apps://search.itunes.apple.com/WebObjects/MZSearch.woa/wa/search?media=software&term=nextcloud"

    // SNAPSHOT PREVIEW
    //
    let defaultSnapshotConfiguration = "DefaultPreviewConfiguration"

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

    // DATA TASK DESCRIPTION
    //
    let taskDescriptionRetrievesProperties  = "retrievesProperties"
    let taskDescriptionSynchronization      = "synchronization"

    // LOG TAG
    let logTagTask                          = "BGT"
    let logTagLocation                      = "LOCATION"
    let logTagBgSync                        = "BGSYNC"
    let logTagE2EE                          = "E2EE"
    let logTagPN                            = "PUSH NOTIF"
    let logTagSync                          = "SYNC"
    let logTagServiceProficer               = "SERVICE PROVIDER"

    // USER DEFAULTS
    let udMigrationMultiDomains             = "migrationMultiDomains"
}
