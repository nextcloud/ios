//
//  NCBrandColor.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 24/04/17.
//  Copyright (c) 2017 Marino Faggiana. All rights reserved.
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

//MARK: - Configuration

@objc class NCBrandConfiguration: NSObject {
    @objc static let shared: NCBrandConfiguration = {
        let instance = NCBrandConfiguration()
        return instance
    }()
    
    @objc public let configuration_bundleId:            String = "it.twsweb.Nextcloud"
    @objc public let configuration_serverUrl:           String = "serverUrl"
    @objc public let configuration_username:            String = "username"
    @objc public let configuration_password:            String = "password"
}

//MARK: - Options

@objc class NCBrandOptions: NSObject {
    @objc static let shared: NCBrandOptions = {
        let instance = NCBrandOptions()
        return instance
    }()
    
    @objc public var brand:                             String = "Nextcloud"
    @objc public var mailMe:                            String = "ios@nextcloud.com"
    @objc public var textCopyrightNextcloudiOS:         String = "Nextcloud Coherence for iOS %@ © 2020"
    @objc public var textCopyrightNextcloudServer:      String = "Nextcloud Server %@"
    @objc public var loginBaseUrl:                      String = "https://cloud.nextcloud.com"
    @objc public var pushNotificationServerProxy:       String = "https://push-notifications.nextcloud.com"
    @objc public var linkLoginHost:                     String = "https://nextcloud.com/install"
    @objc public var linkloginPreferredProviders:       String = "https://nextcloud.com/signup";
    @objc public var webLoginAutenticationProtocol:     String = "nc://"                                            // example "abc://"
    // Personalized
    @objc public var webCloseViewProtocolPersonalized:  String = ""                                                 // example "abc://change/plan"      Don't touch me !!
    @objc public var folderBrandAutoUpload:             String = ""                                                 // example "_auto_upload_folder_"   Don't touch me !!
    
    // Auto Upload default folder
    @objc public var folderDefaultAutoUpload:           String = "Photos"
    
    // Capabilities Group
    @objc public var capabilitiesGroups:                String = "group.it.twsweb.Crypto-Cloud"
    
    // User Agent
    @objc public var userAgent:                         String = "Nextcloud-iOS"                                    // Don't touch me !!
    
    // Options
    @objc public var use_login_web_personalized:        Bool = false                                                // Don't touch me !!
    @objc public var use_default_auto_upload:           Bool = false
    @objc public var use_themingColor:                  Bool = true
    //@objc public var use_themingBackground:             Bool = true                                               // Deprecated
    @objc public var use_themingLogo:                   Bool = false
    @objc public var use_storeLocalAutoUploadAll:       Bool = false
    @objc public var use_configuration:                 Bool = false                                                // Don't touch me !!
    @objc public var use_loginflowv2:                   Bool = false                                                // Don't touch me !!

    @objc public var disable_intro:                     Bool = false
    @objc public var disable_request_login_url:         Bool = false
    @objc public var disable_multiaccount:              Bool = false
    @objc public var disable_manage_account:            Bool = false
    @objc public var disable_more_external_site:        Bool = false
    @objc public var disable_openin_file:               Bool = false                                                // Don't touch me !!
    @objc public var disable_crash_service:             Bool = false
    
    override init() {
        
        if folderBrandAutoUpload != "" {
            folderDefaultAutoUpload = folderBrandAutoUpload
        }
    }
}

//MARK: - Color

class NCBrandColor: NSObject {
    @objc static let shared: NCBrandColor = {
        let instance = NCBrandColor()
        instance.setDarkMode()
        return instance
    }()

    // Color
    @objc public let customer:              UIColor = UIColor(red: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 1.0)    // BLU NC : #0082c9
    @objc public var customerText:          UIColor = .white
    
    @objc public var brand:                 UIColor                                                                                 // don't touch me
    @objc public var brandElement:          UIColor                                                                                 // don't touch me
    @objc public var brandText:             UIColor                                                                                 // don't touch me

    @objc public var connectionNo:          UIColor = UIColor(red: 204.0/255.0, green: 204.0/255.0, blue: 204.0/255.0, alpha: 1.0)
    @objc public var encrypted:             UIColor = .red
    @objc public var backgroundView:        UIColor = .white
    @objc public var backgroundCell:        UIColor = .white
    @objc public var backgroundForm:        UIColor = UIColor(red: 244.0/255.0, green: 244.0/255.0, blue: 244.0/255.0, alpha: 1.0)
    @objc public var textView:              UIColor = .black
    @objc public var separator:             UIColor = UIColor(red: 235.0/255.0, green: 235.0/255.0, blue: 235.0/255.0, alpha: 1.0)
    @objc public var tabBar:                UIColor = .white
    @objc public let nextcloud:             UIColor = UIColor(red: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 1.0)
    @objc public let nextcloudSoft:         UIColor = UIColor(red: 90.0/255.0, green: 160.0/255.0, blue: 210.0/255.0, alpha: 1.0)
    @objc public let icon:                  UIColor = UIColor(red: 104.0/255.0, green: 104.0/255.0, blue: 104.0/255.0, alpha: 1.0)
    @objc public let optionItem:            UIColor = UIColor(red: 178.0/255.0, green: 178.0/255.0, blue: 178.0/255.0, alpha: 1.0)
    @objc public let graySoft:              UIColor = UIColor(red: 162.0/255.0, green: 162.0/255.0, blue: 162.0/255.0, alpha: 0.5)
    @objc public let yellowFavorite:        UIColor = UIColor(red: 248.0/255.0, green: 205.0/255.0, blue: 70.0/255.0, alpha: 1.0)
    @objc public let textInfo:              UIColor = UIColor(red: 153.0/255.0, green: 153.0/255.0, blue: 153.0/255.0, alpha: 1.0)
    @objc public var select:                UIColor = .white
    @objc public var avatarBorder:          UIColor = UIColor(red: 104.0/255.0, green: 104.0/255.0, blue: 104.0/255.0, alpha: 1.0)

    override init() {
        self.brand = self.customer
        self.brandElement = self.customer
        self.brandText = self.customerText        
    }
    
    @objc public func setDarkMode() {
        let darkMode = CCUtility.getDarkMode()
        if darkMode {
            tabBar = UIColor(red: 25.0/255.0, green: 25.0/255.0, blue: 25.0/255.0, alpha: 1.0)
            backgroundView = .black
            backgroundCell = UIColor(red: 25.0/255.0, green: 25.0/255.0, blue: 25.0/255.0, alpha: 1.0)
            backgroundForm = .black
            textView = .white
            separator = UIColor(red: 60.0/255.0, green: 60.0/255.0, blue: 60.0/255.0, alpha: 1.0)
            select = UIColor.white.withAlphaComponent(0.2)
        } else {
            tabBar = .white
            backgroundView = .white
            backgroundCell = .white
            backgroundForm = UIColor(red: 247.0/255.0, green: 247.0/255.0, blue: 247.0/255.0, alpha: 1.0)
            textView = .black
            separator = UIColor(red: 235.0/255.0, green: 235.0/255.0, blue: 235.0/255.0, alpha: 1.0)
            select = self.brandElement.withAlphaComponent(0.1)
        }
    }
    
#if !EXTENSION
    @objc public func settingThemingColor(account: String) {
        
        let darker: CGFloat = 30    // %
        let lighter: CGFloat = 30   // %

        if NCBrandOptions.shared.use_themingColor {
            
            let themingColor = NCManageDatabase.shared.getCapabilitiesServerString(account: account, elements: NCElementsJSON.shared.capabilitiesThemingColor)
            
            let themingColorElement = NCManageDatabase.shared.getCapabilitiesServerString(account: account, elements: NCElementsJSON.shared.capabilitiesThemingColorElement)
            
            let themingColorText = NCManageDatabase.shared.getCapabilitiesServerString(account: account, elements: NCElementsJSON.shared.capabilitiesThemingColorText)
            
            settingBrandColor(themingColor, themingColorElement: themingColorElement, themingColorText: themingColorText)
                        
            if NCBrandColor.shared.brandElement.isTooLight() {
                if let color = NCBrandColor.shared.brandElement.darker(by: darker) {
                    NCBrandColor.shared.brandElement = color
                }
            } else if NCBrandColor.shared.brandElement.isTooDark() {
                if let color = NCBrandColor.shared.brandElement.lighter(by: lighter) {
                    NCBrandColor.shared.brandElement = color
                }
            }           
            
        } else {
            
            if NCBrandColor.shared.customer.isTooLight() {
                if let color = NCBrandColor.shared.customer.darker(by: darker) {
                    NCBrandColor.shared.brandElement = color
                }
            } else if NCBrandColor.shared.customer.isTooDark() {
                if let color = NCBrandColor.shared.customer.lighter(by: lighter) {
                    NCBrandColor.shared.brandElement = color
                }
            } else {
                NCBrandColor.shared.brandElement = NCBrandColor.shared.customer
            }
            
            NCBrandColor.shared.brand = NCBrandColor.shared.customer
            NCBrandColor.shared.brandText = NCBrandColor.shared.customerText
        }
        
        setDarkMode()
        
        DispatchQueue.main.async {
            NCCollectionCommon.shared.createImagesThemingColor()
            NotificationCenter.default.postOnMainThread(name: NCBrandGlobal.shared.notificationCenterChangeTheming)
        }
    }
#endif
    
    @objc func settingBrandColor(_ themingColor: String?, themingColorElement: String?, themingColorText: String?) {
                
        // COLOR
        if themingColor?.first == "#" {
            if let color = UIColor(hex: themingColor!) {
                NCBrandColor.shared.brand = color
            } else {
                NCBrandColor.shared.brand = NCBrandColor.shared.customer
            }
        } else {
            NCBrandColor.shared.brand = NCBrandColor.shared.customer
        }
        
        // COLOR TEXT
        if themingColorText?.first == "#" {
            if let color = UIColor(hex: themingColorText!) {
                NCBrandColor.shared.brandText = color
            } else {
                NCBrandColor.shared.brandText = NCBrandColor.shared.customerText
            }
        } else {
            NCBrandColor.shared.brandText = NCBrandColor.shared.customerText
        }
        
        // COLOR ELEMENT
        if themingColorElement?.first == "#" {
            if let color = UIColor(hex: themingColorElement!) {
                NCBrandColor.shared.brandElement = color
            } else {
                NCBrandColor.shared.brandElement = NCBrandColor.shared.brand
            }
        } else {
            NCBrandColor.shared.brandElement = NCBrandColor.shared.brand
        }
    }
}

//MARK: - Global

@objc class NCBrandGlobal: NSObject {
    @objc static let shared: NCBrandGlobal = {
        let instance = NCBrandGlobal()
        return instance
    }()

    // Directory on Group
    @objc let appDatabaseNextcloud                  = "Library/Application Support/Nextcloud"
    @objc let appApplicationSupport                 = "Library/Application Support"
    @objc let appUserData                           = "Library/Application Support/UserData"
    @objc let appCertificates                       = "Library/Application Support/Certificates"
    @objc let appScan                               = "Library/Application Support/Scan"
    @objc let directoryProviderStorage              = "File Provider Storage"

    // Service Key Share
    @objc let serviceShareKeyChain                  = "Crypto Cloud"
    @objc let metadataKeyedUnarchiver               = "it.twsweb.nextcloud.metadata"

    // Nextcloud version
    @objc let nextcloudVersion12: Int               =  12
    let nextcloudVersion15: Int                     =  15
    let nextcloudVersion17: Int                     =  17
    let nextcloudVersion18: Int                     =  18
    let nextcloudVersion20: Int                     =  20

    // Database Realm
    let databaseDefault                             = "nextcloud.realm"
    let databaseSchemaVersion: UInt64               = 160
    
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
    @objc let notificationCenterMenuSaveLivePhoto               = "menuSaveLivePhoto"                // userInfo: ocId, ocIdMov
    @objc let notificationCenterMenuDetailClose                 = "menuDetailClose"
}

//DispatchQueue.main.async
//DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)
//DispatchQueue.global().async

//#if targetEnvironment(simulator)
//#endif


//dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//dispatch_async(dispatch_get_main_queue(), ^{
//dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {

//#if TARGET_OS_SIMULATOR
//#endif
