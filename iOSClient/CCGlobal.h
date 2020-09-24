//
//  CCGlobal.h
//  Nextcloud
//
//  Created by Marino Faggiana on 13/10/14.
//  Copyright (c) 2014 Marino Faggiana. All rights reserved.
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

#import <UIKit/UIKit.h>

#ifndef EXTENSION

//AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
//#define app ((AppDelegate *)[[UIApplication sharedApplication] delegate])
//dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//dispatch_async(dispatch_get_main_queue(), ^{
//dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {

//DispatchQueue.main.async
//DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)
//DispatchQueue.global().async

//NSString *language = [[NSLocale preferredLanguages] objectAtIndex:0];
//NSDictionary *languageDic = [NSLocale componentsFromLocaleIdentifier:language];
//NSString *languageCode = [languageDic objectForKey:@"kCFLocaleLanguageCodeKey"];

//#if targetEnvironment(simulator)
//#endif

//#if TARGET_OS_SIMULATOR
//#endif

#define CALL_ORIGIN NSLog(@"Origin: [%@]", [[[[NSThread callStackSymbols] objectAtIndex:1] componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"[]"]] objectAtIndex:1])

#endif

// Directory on Group
#define k_appApplicationSupport                         @"Library/Application Support"
#define k_appDatabaseNextcloud                          @"Library/Application Support/Nextcloud"
#define k_appUserData                                   @"Library/Application Support/UserData"
#define k_appCertificates                               @"Library/Application Support/Certificates"
#define k_appScan                                       @"Library/Application Support/Scan"
#define k_DirectoryProviderStorage                      @"File Provider Storage"

// Server Status
#define k_serverStatus                                  @"/status.php"

// Login Flow
#define k_flowEndpoint                                  @"/index.php/login/flow"

// Avatar
#define k_avatar_size                                   128

// Passphrase test EndToEnd Encryption
#define k_passphrase_test                               @"more over television factory tendency independence international intellectual impress interest sentence pony"

#define k_dismissAfterSecond                            4
#define k_dismissAfterSecondLong                        10

#define k_daysOfActivity                                7

#define k_sizePreview                                   1024
#define k_sizeIcon                                      512

// Database Realm
#define k_databaseDefault                               @"nextcloud.realm"
#define k_databaseSchemaVersion                         143

// Database JSON
#define k_databaseDefaultJSON                           @"nextcloud.json"

// Intro selector
#define k_intro_login                                   0
#define k_intro_signup                                  1

// Login
#define k_login_Add                                     0
#define k_login_Add_Forced                              1
#define k_login_Add_SignUp                              2

// define Nextcloud IOS
#define k_share_link_middle_part_url_after_version_8    @"index.php/s/"

// serverUrl root
#define k_serverUrl_root                                @".."

// Constants to identify the different permissions of a file
#define k_permission_shared                             @"S"
#define k_permission_can_share                          @"R"
#define k_permission_mounted                            @"M"
#define k_permission_file_can_write                     @"W"
#define k_permission_can_create_file                    @"C"
#define k_permission_can_create_folder                  @"K"
#define k_permission_can_delete                         @"D"
#define k_permission_can_rename                         @"N"
#define k_permission_can_move                           @"V"

// Service Key Share
#define k_serviceShareKeyChain                          @"Crypto Cloud"
#define k_metadataKeyedUnarchiver                       @"it.twsweb.nextcloud.metadata"

// TaskStatus
#define k_taskStatusCancel                              -1
#define k_taskStatusResume                              -2
#define k_taskStatusSuspend                             -3

// Metadata : Status
//
// 1) wait download/upload
// 2) in download/upload
// 3) downloading/uploading
// 4) done or error
//
#define k_metadataStatusNormal                          0

#define k_metadataStatustypeDownload                    1

#define k_metadataStatusWaitDownload                    2
#define k_metadataStatusInDownload                      3
#define k_metadataStatusDownloading                     4
#define k_metadataStatusDownloadError                   5

#define k_metadataStatusTypeUpload                      6

#define k_metadataStatusWaitUpload                      7
#define k_metadataStatusInUpload                        8
#define k_metadataStatusUploading                       9
#define k_metadataStatusUploadError                     10
#define k_metadataStatusUploadForcedStart               11

// Timer
#define k_timerAutoUpload                               5
#define k_timerUpdateApplicationIconBadgeNumber         5
#define k_timerErrorNetworking                          3

// ConcurrentOperation
#define k_maxHTTPConnectionsPerHost                     5
#define k_maxConcurrentOperation                        5

// Max Size Operation
#define k_maxSizeOperationUpload                        524288000   // 500 MB

// Max Cache Proxy Video
#define k_maxHTTPCache                                  10737418240 // 10GB

// Error
#define k_CCErrorInternalError                          -99999
#define k_CCErrorFileNotSaved                           -99998
#define k_CCErrorDecodeMetadata                         -99997
#define k_CCErrorE2EENotEnabled                         -99996
#define k_CCErrorE2EENotMove                            -99995
#define k_CCErrorOffline                                -99994
#define k_CCErrorCharactersForbidden                    -99993
#define k_CCErrorCreationFile                           -99992


// Search
#define k_minCharsSearch                                2

// Selector
#define selectorDownloadFile                            @"downloadFile"
#define selectorDownloadAllFile                         @"downloadAllFile"
#define selectorReadFile                                @"readFile"
#define selectorListingFavorite                         @"listingFavorite"
#define selectorLoadFileView                            @"loadFileView"
#define selectorLoadFileQuickLook                       @"loadFileQuickLook"
#define selectorLoadCopy                                @"loadCopy"
#define selectorLoadOffline                             @"loadOffline"
#define selectorOpenIn                                  @"openIn"
#define selectorOpenInDetail                            @"openInDetail"
#define selectorSaveAlbum                               @"saveAlbum"
#define selectorUploadAutoUpload                        @"uploadAutoUpload"
#define selectorUploadAutoUploadAll                     @"uploadAutoUploadAll"
#define selectorUploadFile                              @"uploadFile"

// Metadata : FileType
#define k_metadataTypeFile_audio                        @"audio"
#define k_metadataTypeFile_compress                     @"compress"
#define k_metadataTypeFile_directory                    @"directory"
#define k_metadataTypeFile_document                     @"document"
#define k_metadataTypeFile_image                        @"image"
#define k_metadataTypeFile_unknown                      @"unknow"
#define k_metadataTypeFile_video                        @"video"
#define k_metadataTypeFile_imagemeter                   @"imagemeter"

// TabBar button
#define k_tabBarApplicationIndexFile                    0
#define k_tabBarApplicationIndexFavorite                1
#define k_tabBarApplicationIndexPlusHide                2
#define k_tabBarApplicationIndexMedia                   3
#define k_tabBarApplicationIndexMore                    4

// Filename Mask and Type
#define k_keyFileNameMask                               @"fileNameMask"
#define k_keyFileNameType                               @"fileNameType"
#define k_keyFileNameAutoUploadMask                     @"fileNameAutoUploadMask"
#define k_keyFileNameAutoUploadType                     @"fileNameAutoUploadType"
#define k_keyFileNameOriginal                           @"fileNameOriginal"
#define k_keyFileNameOriginalAutoUpload                 @"fileNameOriginalAutoUpload"

// Activity
#define k_activityVerboseDefault                        0
#define k_activityVerboseHigh                           1
#define k_activityTypeInfo                              @"info"
#define k_activityTypeSuccess                           @"success"
#define k_activityTypeFailure                           @"error"

#define k_activityDebugActionDownload                   @"Download"
#define k_activityDebugActionDownloadPicker             @"Download Picker"
#define k_activityDebugActionUpload                     @"Upload"
#define k_activityDebugActionUploadPicker               @"Upload Picker"
#define k_activityDebugActionUploadShare                @"Upload Share"
#define k_activityDebugActionAutoUpload                 @"Auto Upload"
#define k_activityDebugActionReadFolder                 @"Read Folder"
#define k_activityDebugActionListingFavorites           @"Listing Favorites"
#define k_activityDebugActionCreateFolder               @"Create Folder"
#define k_activityDebugActionDeleteFileFolder           @"Delete File-Folder"
#define k_activityDebugActionGetNotification            @"Get Notification Server"
#define k_activityDebugActionSubscribingServerPush      @"Subscribing Server Push"
#define k_activityDebugActionUnsubscribingServerPush    @"Unsubscribing Server Push"
#define k_activityDebugActionSubscribingPushProxy       @"Subscribing Push Proxy"
#define k_activityDebugActionUnsubscribingPushProxy     @"Unsubscribing Push Proxy"
#define k_activityDebugActionCapabilities               @"Capabilities Of Server"
#define k_activityDebugActionEndToEndEncryption         @"End To End Encryption "

// E2EE
#define k_max_filesize_E2EE                             524288000   // 500 MB
#define k_E2EE_API                                      @"1.1"

// Flow Version
#define k_flow_version_available                        12

// Trash Version
#define k_trash_version_available                       14
#define k_trash_version_available_more_fix              15

// Toolbar Detail
#define k_detail_Toolbar_Height                         49


//Share permission
//permissions - (int) 1 = read; 2 = update; 4 = create; 8 = delete; 16 = share; 31 = all (default: 31, for public shares: 1)
#define k_read_share_permission                         1
#define k_update_share_permission                       2
#define k_create_share_permission                       4
#define k_delete_share_permission                       8
#define k_share_share_permission                        16

#define k_min_file_share_permission                     1
#define k_max_file_share_permission                     19
#define k_min_folder_share_permission                   1
#define k_max_folder_share_permission                   31
#define k_default_file_remote_share_permission_no_support_share_option      3
#define k_default_folder_remote_share_permission_no_support_share_option    15

// Layout
#define k_layout_list                                   @"typeLayoutList"
#define k_layout_grid                                   @"typeLayoutGrid"

#define k_layout_view_move                              @"LayoutMove"
#define k_layout_view_richdocument                      @"LayoutRichdocument"
#define k_layout_view_trash                             @"LayoutTrash"
#define k_layout_view_offline                           @"LayoutOffline"
#define k_layout_view_favorite                          @"LayoutFavorite"
#define k_layout_view_main                              @"LayoutMain"
#define k_layout_view_transfers                         @"LayoutTransfers"

// Rich Workspace
#define k_fileNameRichWorkspace                         @"Readme.md"

// Text -  OnlyOffice - Collabora
#define k_editor_text                                   @"text"
#define k_editor_onlyoffice                             @"onlyoffice"
#define k_editor_collabora                              @"collabora"

#define k_onlyoffice_docx                               @"onlyoffice_docx"
#define k_onlyoffice_xlsx                               @"onlyoffice_xlsx"
#define k_onlyoffice_pptx                               @"onlyoffice_pptx"

// Template
#define k_template_document                             @"document"
#define k_template_spreadsheet                          @"spreadsheet"
#define k_template_presentation                         @"presentation"

// Nextcloud unsupported
#define k_nextcloud_unsupported                         13

// Nextcloud version
#define k_nextcloud_version_12_0                        12
#define k_nextcloud_version_13_0                        13
#define k_nextcloud_version_14_0                        14
#define k_nextcloud_version_15_0                        15
#define k_nextcloud_version_16_0                        16
#define k_nextcloud_version_17_0                        17
#define k_nextcloud_version_18_0                        18
#define k_nextcloud_version_19_0                        19

// Notification Center

#define k_notificationCenter_applicationDidEnterBackground  @"applicationDidEnterBackground"
#define k_notificationCenter_applicationWillEnterForeground @"applicationWillEnterForeground"

#define k_notificationCenter_initializeMain             @"initializeMain"
#define k_notificationCenter_setTitleMain               @"setTitleMain"
#define k_notificationCenter_changeTheming              @"changeTheming"
#define k_notificationCenter_splitViewChangeDisplayMode @"splitViewChangeDisplayMode"
#define k_notificationCenter_changeUserProfile          @"changeUserProfile"
#define k_notificationCenter_richdocumentGrabFocus      @"richdocumentGrabFocus"
#define k_notificationCenter_reloadDataNCShare          @"reloadDataNCShare"
#define k_notificationCenter_reloadDataSource           @"reloadDataSource"                 // userInfo: ocId?, serverUrl?
#define k_notificationCenter_reloadMediaDataSource      @"reloadMediaDataSource"
#define k_notificationCenter_mediaFileNotFound          @"mediaFileNotFound"                // userInfo: metadata
#define k_notificationCenter_changeStatusFolderE2EE     @"changeStatusFolderE2EE"           // userInfo: serverUrl

#define k_notificationCenter_downloadStartFile          @"downloadStartFile"                // userInfo: metadata
#define k_notificationCenter_downloadedFile             @"downloadedFile"                   // userInfo: metadata, selector, errorCode, errorDescription
#define k_notificationCenter_downloadCancelFile         @"downloadCancelFile"               // userInfo: metadata

#define k_notificationCenter_uploadStartFile            @"uploadStartFile"                  // userInfo: metadata
#define k_notificationCenter_uploadedFile               @"uploadedFile"                     // userInfo: metadata, ocIdTemp, errorCode, errorDescription
#define k_notificationCenter_uploadCancelFile           @"uploadCancelFile"                 // userInfo: metadata

#define k_notificationCenter_progressTask               @"progressTask"                     // userInfo: account, ocId, serverUrl, status, progress, totalBytes, totalBytesExpected

#define k_notificationCenter_createFolder               @"createFolder"                     // userInfo: metadata
#define k_notificationCenter_deleteFile                 @"deleteFile"                       // userInfo: metadata, onlyLocal
#define k_notificationCenter_renameFile                 @"renameFile"                       // userInfo: metadata, errorCode, errorDescription
#define k_notificationCenter_moveFile                   @"moveFile"                         // userInfo: metadata, metadataNew
#define k_notificationCenter_copyFile                   @"copyFile"                         // userInfo: metadata, serverUrlTo
#define k_notificationCenter_favoriteFile               @"favoriteFile"                     // userInfo: metadata

#define k_notificationCenter_menuSearchTextPDF          @"menuSearchTextPDF"
#define k_notificationCenter_menuDownloadImage          @"menuDownloadImage"                // userInfo: metadata
#define k_notificationCenter_menuSaveLivePhoto          @"menuSaveLivePhoto"                // userInfo: metadata, metadataMov
#define k_notificationCenter_menuDetailClose            @"menuDetailClose"


// -----------------------------------------------------------------------------------------------------------
// INTERNAL
// -----------------------------------------------------------------------------------------------------------

#define k_fileProvider_domain                           0

