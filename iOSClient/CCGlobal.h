//
//  CCGlobal.h
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 13/10/14.
//  Copyright (c) 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
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

extern NSString *const appApplicationSupport;
extern NSString *const appDatabase;
extern NSString *const appDatabaseNextcloud;
extern NSString *const appCertificates;

extern NSString *const webDAV;
extern NSString *const dav;

extern NSString *const appKeyCryptoCloud;
extern NSString *const appSecretCryptoCloud;
extern NSString *const urlBaseDownloadDB;
extern NSString *const urlBaseUploadDB;

#ifndef EXTENSION

//AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
#define app ((AppDelegate *)[[UIApplication sharedApplication] delegate])
#define CALL_ORIGIN NSLog(@"Origin: [%@]", [[[[NSThread callStackSymbols] objectAtIndex:1] componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"[]"]] objectAtIndex:1])

#endif

// Version Protocol plist
#define k_versionProtocolPlist                          @"1.3"

// UUID
#define k_UUID_SIM                                      @"4BACFE4A-61A6-44B1-9A85-13FD167565AB"

#define k_dismissAfterSecond                            4

#define k_daysOfActivity                                7

#define k_returnCreateFolderPlain                       0
#define k_returnCreateFotoVideoPlain                    1
#define k_returnCreateFilePlain                         2
#define k_returnCreateFolderEncrypted                   3
#define k_returnCreateFotoVideoEncrypted                4
#define k_returnCreateFileEncrypted                     5
#define k_returnCartaDiCredito                          6
#define k_returnBancomat                                7
#define k_returnContoCorrente                           8
#define k_returnAccountWeb                              9
#define k_returnNote                                    10
#define k_returnPatenteGuida                            11
#define k_returnCartaIdentita                           12
#define k_returnPassaporto                              13

// Name Default DB
#define k_databaseDefault                               @"nextcloud.realm"

// Picker select image
#define k_pickerControllerMax                           100.0

// define Nextcloud IOS
#define k_share_link_middle_part_url_after_version_8    @"index.php/s/"

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

#define k_networkingSessionNotification                 @"networkingSessionNotification"

// Session
#define k_domain_session_queue                          @"it.twsweb.Crypto-Cloud"

#define k_download_session                              @"it.twsweb.Crypto-Cloud.download.session"
#define k_download_session_foreground                   @"it.twsweb.Crypto-Cloud.download.sessionforeground"
#define k_download_session_wwan                         @"it.twsweb.Crypto-Cloud.download.sessionwwan"
#define k_upload_session                                @"it.twsweb.Crypto-Cloud.upload.session"
#define k_upload_session_foreground                     @"it.twsweb.Crypto-Cloud.upload.sessionforeground"
#define k_upload_session_wwan                           @"it.twsweb.Crypto-Cloud.upload.sessionwwan"

// OperationQueue
#define k_queue                                         @"it.twsweb.Crypto-Cloud.queue"
#define k_download_queue                                @"it.twsweb.Crypto-Cloud.download.queue"
#define k_download_queuewwan                            @"it.twsweb.Crypto-Cloud.download.queuewwan"
#define k_upload_queue                                  @"it.twsweb.Crypto-Cloud.upload.queue"
#define k_upload_queuewwan                              @"it.twsweb.Crypto-Cloud.upload.queuewwan"

// Service Key Share
#define k_serviceShareKeyChain                          @"Crypto Cloud"
#define k_metadataKeyedUnarchiver                       @"it.twsweb.Crypto-Cloud.metadata"

// TaskIdentifier
#define k_taskIdentifierDone                            -1
#define k_taskIdentifierStop                            -2
#define k_taskIdentifierError                           -99999
#define k_taskIdentifierNULL                            99999

// TaskStatus
#define k_taskStatusNone                                0
#define k_taskStatusCancel                              -1
#define k_taskStatusResume                              -2
#define k_taskStatusSuspend                             -3

#define k_timerVerifySession                            10
#define k_timerProcessAutoUpload                        5
#define k_timerUpdateApplicationIconBadgeNumber         3

#define k_maxConcurrentOperation                         10
#define k_maxConcurrentOperationDownloadUpload           10
#define k_maxConcurrentOperationDownloadUploadBackground 2

// Error
#define k_CCErrorTaskNil                                -9999
#define k_CCErrorTaskDownloadNotFound                   -9998
#define k_CCErrorFileUploadNotFound                     -9997
#define k_CCErrorInternalError                          -9996
#define k_CCErrorNetworkNowAvailable                    -9995
#define k_CCErrorFileAlreadyInDownload                  -9994

// Search
#define k_minCharsSearch                                2

// Metadata ed ID
#define k_uploadSessionID                               @"ID_UPLOAD_"

// Metadata.Net SELECTOR
#define selectorAddFavorite                             @"addFavorite"
#define selectorAddLocal                                @"addLocal"
#define selectorCreateFolder                            @"createFolder"
#define selectorDecryptFile                             @"decryptFile"
#define selectorDelete                                  @"delete"
#define selectorDeleteCrypto                            @"deleteCrypto"
#define selectorDeletePlist                             @"deletePlist"
#define selectorDownloadFile                            @"downloadFile"
#define selectorDownloadThumbnail                       @"downloadThumbnail"
#define selectorDownloadSynchronize                     @"downloadSynchronize"
#define selectorEncryptFile                             @"encryptFile"
#define selectorGetUserAndGroup                         @"getUserAndGroup"
#define selectorLoadFileView                            @"loadFileView"
#define selectorLoadModelView                           @"loadModelView"
#define selectorLoadPlist                               @"loadPlist"
#define selectorLoadViewImage                           @"loadViewImage"
#define selectorLoadCopy                                @"loadCopy"
#define selectorMove                                    @"move"
#define selectorMoveCrypto                              @"moveCrypto"
#define selectorMovePlist                               @"movePlist"
#define selectorOpenIn                                  @"openIn"
#define selectorOpenWindowShare                         @"openWindowShare"
#define selectorReadFile                                @"readFile"
#define selectorReadFileUploadFile                      @"readFileUploadFile"
#define selectorReadFileVerifyUpload                    @"readFileVerifyUpload"
#define selectorReadFileWithDownload                    @"readFileWithDownload"
#define selectorReadFileReloadFolder                    @"readFileReloadFolder"
#define selectorReadFolder                              @"readFolder"
#define selectorReadFolderForced                        @"readFolderForced"
#define selectorReadFolderWithDownload                  @"readFolderWithDownload"
#define selectorReadShare                               @"readShare"
#define selectorRename                                  @"rename"
#define selectorSave                                    @"save"
#define selectorShare                                   @"share"
#define selectorSearch                                  @"search"
#define selectorUnshare                                 @"unshare"
#define selectorUpdateShare                             @"updateShare"
#define selectorUploadAutoUpload                        @"uploadAutoUpload"
#define selectorUploadAutoUploadAll                     @"uploadAutoUploadAll"
#define selectorUploadFile                              @"uploadFile"
#define selectorUploadFileCrypto                        @"uploadFileCrypto"
#define selectorUploadFilePlist                         @"uploadFilePlist"
#define selectorUploadRemovePhoto                       @"uploadRemovePhoto"

// Metadata.Net ACTION
#define actionCreateFolder                              @"createFolder"
#define actionDeleteFileDirectory                       @"deleteFileOrFolder"
#define actionDownloadFile                              @"downloadFile"
#define actionDownloadThumbnail                         @"downloadThumbnail"
#define actionGetActivityServer                         @"getActivityServer"
#define actionGetCapabilities                           @"getCapabilitiesOfServer"
#define actionGetUserAndGroup                           @"getUserAndGroup"
#define actionGetUserProfile                            @"getUserProfile"
#define actionGetNotificationServer                     @"getNotificationServer"
#define actionSetNotificationServer                     @"setNotificationServer"
#define actionGetExternalSitesServer                    @"getExternalSitesServer"
#define actionMiddlewarePing                            @"middlewarePing"
#define actionListingFavorites                          @"listingFavorites"
#define actionMoveFileOrFolder                          @"moveFileOrFolder"
#define actionReadFile                                  @"readFile"
#define actionReadFolder                                @"readFolder"
#define actionReadShareServer                           @"readShareServer"
#define actionSearch                                    @"search"
#define actionSettingFavorite                           @"settingFavorite"
#define actionShare                                     @"share"
#define actionShareWith                                 @"shareWith"
#define actionSubscribingNextcloudServer                @"subscribingNextcloudServer"
#define actionUnShare                                   @"unShare"
#define actionUpdateShare                               @"updateShare"
#define actionUploadFile                                @"uploadFile"
#define actionUploadAsset                               @"uploadAsset"
#define actionUploadTemplate                            @"uploadTemplate"
#define actionUploadOnlyPlist                           @"uploadOnlyPlist"

// Metadata : FileType
#define k_metadataTypeFile_audio                        @"audio"
#define k_metadataTypeFile_compress                     @"compress"
#define k_metadataTypeFile_directory                    @"directory"
#define k_metadataTypeFile_document                     @"document"
#define k_metadataTypeFile_image                        @"image"
#define k_metadataTypeFile_template                     @"template"
#define k_metadataTypeFile_unknown                      @"unknow"
#define k_metadataTypeFile_video                        @"video"

// Metadata : Type
#define k_metadataType_file                             @"file"
#define k_metadataType_template                         @"model"
#define k_metadataType_local                            @"local"

// Metadata : Filename Type
#define k_metadataTypeFilenamePlain                     0
#define k_metadataTypeFilenamePlist                     1
#define k_metadataTypeFilenameCrypto                    2

// Metadata : Status

#define k_metadataStatusNormal                          0
#define k_metadataStatusHide                            1

#define k_tabBarApplicationIndexFile                    0
#define k_tabBarApplicationIndexOffline                 1
#define k_tabBarApplicationIndexHide                    2
#define k_tabBarApplicationIndexPhotos                  3
#define k_tabBarApplicationIndexMore                    4

#define k_keyFileNameMask                               @"fileNameMask"

// Type of page Offline
#define k_pageOfflineFavorites                          @"Favorites"
#define k_pageOfflineOffline                            @"Offline"
#define k_pageOfflineLocal                              @"Local"

#define k_pageControlCenterTransfer                     @"Transfer"
#define k_pageControlCenterActivity                     @"Activity"

// Activity
#define k_activityVerboseDefault                        0
#define k_activityVerboseHigh                           1
#define k_activityTypeInfo                              @"info"
#define k_activityTypeSuccess                           @"success"
#define k_activityTypeFailure                           @"error"

#define k_activityDebugActionDownload                   @"Download"
#define k_activityDebugActionDownloadPicker             @"Download Picker"
#define k_activityDebugActionDownloadThumbnail          @"Download Thumbnail"
#define k_activityDebugActionUpload                     @"Upload"
#define k_activityDebugActionUploadPicker               @"Upload Picker"
#define k_activityDebugActionUploadShare                @"Upload Share"
#define k_activityDebugActionAutoUpload                 @"Auto Upload"
#define k_activityDebugActionReadFolder                 @"Read Folder"
#define k_activityDebugActionGetNotification            @"Get Notification Server"
#define k_activityDebugActionPushProxy                  @"Subscribing Push Proxy"
#define k_activityDebugActionServerPush                 @"Subscribing Server Push"
#define k_activityDebugActionFeatures                   @"Features Supported By Server"
#define k_activityDebugActionCapabilities               @"Capabilities Of Server"

// -----------------------------------------------------------------------------------------------------------
// -----------------------------------------------------------------------------------------------------------

