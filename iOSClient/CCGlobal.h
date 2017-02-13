//
//  CCGlobal.h
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 13/10/14.
//  Copyright (c) 2014 TWS. All rights reserved.
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

#import "CCImages.h"

extern NSString *const appApplicationSupport;
extern NSString *const appDatabase;
extern NSString *const appCertificates;

extern NSString *const webDAV;
extern NSString *const typeCloudNextcloud;
extern NSString *const typeCloudOwnCloud;

extern NSString *const appKeyCryptoCloud;
extern NSString *const appSecretCryptoCloud;
extern NSString *const urlBaseDownloadDB;
extern NSString *const urlBaseUploadDB;

extern NSString *const BKPasscodeKeychainServiceName;

#ifndef EXTENSION

//AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
#define app ((AppDelegate *)[[UIApplication sharedApplication] delegate])
#define CALL_ORIGIN NSLog(@"Origin: [%@]", [[[[NSThread callStackSymbols] objectAtIndex:1] componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"[]"]] objectAtIndex:1])

#endif

// Version Protocol plist
#define k_versionProtocolPlist                          @"1.3"

// UUID
#define k_UUID_SIM                                      @"4BACFE4A-61A6-44B1-9A85-13FD167565AB"

// Capabilities Group & Service Key Share
#define k_capabilitiesGroups                            @"group.it.twsweb.Crypto-Cloud"
#define k_serviceShareKeyChain                          @"Crypto Cloud"

// BRAND
#ifdef NC
#define _brand_                                         @"Nextcloud"
#define _mail_me_                                       @"ios@nextcloud.com"
#endif

#define k_dismissAfterSecond                            4

#define k_MaxDimensionUpload                            524288000       // 500 MB

#define k_dayForceReadFolder                            3

#define k_MaxGroupBySessionUploadDatasource             50
#define k_MaxGroupBySessionDownloadDatasource           50

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

// File Name Const
#define k_folderDefaultCameraUpload                     @"Photos"

// Picker select image
#define k_pickerControllerMax                           100.0

// define ownCloud IOS
#define server_version_with_new_shared_schema 8
#define k_share_link_middle_part_url_before_version_8   @"public.php?service=files&t="
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

// Session
#define k_download_session                              @"it.twsweb.download.session"
#define k_download_session_foreground                   @"it.twsweb.download.sessionforeground"
#define k_download_session_wwan                         @"it.twsweb.download.sessionwwan"

#define k_upload_session                                @"it.twsweb.upload.session"
#define k_upload_session_foreground                     @"it.twsweb.upload.sessionforeground"
#define k_upload_session_wwan                           @"it.twsweb.upload.sessionwwan"

#define k_networkingSessionNotification                 @"networkingSessionNotification"

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

#define k_timerVerifySession                            15.0

// OperationQueue
#define k_netQueueName                                  @"it.twsweb.cryptocloud.queue"
#define k_netQueueDownloadName                          @"it.twsweb.cryptocloud.queueDownload"
#define k_netQueueDownloadWWanName                      @"it.twsweb.cryptocloud.queueDownloadWWan"
#define k_netQueueUploadName                            @"it.twsweb.cryptocloud.queueUpload"
#define k_netQueueUploadWWanName                        @"it.twsweb.cryptocloud.queueUploadWWan"

#define k_maxConcurrentOperation                        10
#define k_maxConcurrentOperationDownloadUpload          10

// Error
#define k_CCErrorTaskNil                                -9999
#define k_CCErrorTaskDownloadNotFound                   -9998
#define k_CCErrorFileUploadNotFound                     -9997
#define k_CCErrorInternalError                          -9996

// Metadata ed ID
#define k_uploadSessionID                               @"ID_UPLOAD_"

// Metadata.Net SELECTOR
#define selectorAddOffline                              @"addOffline"
#define selectorAddLocal                                @"addLocal"
#define selectorCreateFolder                            @"createFolder"
#define selectorDecryptFile                             @"decryptFile"
#define selectorDelete                                  @"delete"
#define selectorDeleteCrypto                            @"deleteCrypto"
#define selectorDeletePlist                             @"deletePlist"
#define selectorDownloadThumbnail                       @"downloadThumbnail"
#define selectorDownloadOffline                         @"downloadOffline"
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
#define selectorReadFileOffline                         @"readFileOffline"
#define selectorReadFileFolder                          @"readFileFolder"
#define selectorReadFileUploadFile                      @"readFileUploadFile"
#define selectorReadFileVerifyUpload                    @"readFileVerifyUpload"
#define selectorReadFileQuota                           @"readFileQuota"
#define selectorReadFolder                              @"readFolder"
#define selectorReadFolderForced                        @"readFolderForced"
#define selectorReadShare                               @"readShare"
#define selectorReload                                  @"reload"
#define selectorRename                                  @"rename"
#define selectorSave                                    @"save"
#define selectorShare                                   @"share"
#define selectorSearch                                  @"search"
#define selectorUnshare                                 @"unshare"
#define selectorUpdateShare                             @"updateShare"
#define selectorUploadAutomatic                         @"uploadAutomatic"
#define selectorUploadAutomaticAll                      @"uploadAutomaticAll"
#define selectorUploadFile                              @"uploadFile"
#define selectorUploadFileCrypto                        @"uploadFileCrypto"
#define selectorUploadFilePlist                         @"uploadFilePlist"
#define selectorUploadRemovePhoto                       @"uploadRemovePhoto"

// Metadata.Net ACTION
#define actionCreateFolder                              @"createFolder"
#define actionDeleteFileDirectory                       @"deleteFileOrFolder"
#define actionDownloadFile                              @"downloadFile"
#define actionDownloadThumbnail                         @"downloadThumbnail"
#define actionGetCapabilities                           @"getCapabilitiesOfServer"
#define actionGetFeaturesSuppServer                     @"getFeaturesSupportedByServer"
#define actionGetUserAndGroup                           @"getUserAndGroup"
#define actionGetNotificationsOfServer                  @"getNotificationsOfServer"
#define actionSetNotificationServer                     @"setNotificationServer"
#define actionMoveFileOrFolder                          @"moveFileOrFolder"
#define actionReadFile                                  @"readFile"
#define actionReadFolder                                @"readFolder"
#define actionReadShareServer                           @"readShareServer"
#define actionSearch                                    @"search"
#define actionShare                                     @"share"
#define actionShareWith                                 @"shareWith"
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

#define k_tabBarApplicationIndexFile                    0
#define k_tabBarApplicationIndexOffline                 1
#define k_tabBarApplicationIndexHide                    2
#define k_tabBarApplicationIndexPhotos                  3
#define k_tabBarApplicationIndexSettings                4

#define k_keyFileNameMask                               @"fileNameMask"
#define k_keyFileNameMaskAutomaticPhotos                @"fileNameMaskAutomaticPhotos"

// Type of page Offline
#define k_pageOfflineOffline                            @"Offline"
#define k_pageOfflineLocal                              @"Local"

// Search
#define k_minCharsSearch                                2

// -----------------------------------------------------------------------------------------------------------
// COLOR
// -----------------------------------------------------------------------------------------------------------

// NEXTCLOUD COLOR
#ifdef NC
#define COLOR_BRAND               [UIColor colorWithRed:0.0/255.0 green:130.0/255.0 blue:201.0/255.0 alpha:1.0]
#define COLOR_BRAND_MESSAGE       [UIColor colorWithRed:0.0/255.0 green:130.0/255.0 blue:201.0/255.0 alpha:0.90]
#define COLOR_SELECT_BACKGROUND   [UIColor colorWithRed:0.0/255.0 green:130.0/255.0 blue:201.0/255.0 alpha:0.1]
#define COLOR_TRANSFER_BACKGROUND [UIColor colorWithRed:178.0/255.0 green:244.0/255.0 blue:258.0/255.0 alpha:0.1]       // Blu chiarissimo
#define COLOR_GROUPBY_BAR         [UIColor colorWithRed:0.0/255.0 green:130.0/255.0 blue:201.0/255.0 alpha:0.2]
#define COLOR_GROUPBY_BAR_NO_BLUR [UIColor colorWithRed:0.0/255.0 green:130.0/255.0 blue:201.0/255.0 alpha:0.3]
#endif

// GENERAL COLOR
#define COLOR_CRYPTOCLOUD         [UIColor colorWithRed:241.0/255.0 green:90.0/255.0 blue:34.0/255.0 alpha:1.0]         // Arancio
#define COLOR_NEXTCLOUD           [UIColor colorWithRed:0.0/255.0 green:130.0/255.0 blue:201.0/255.0 alpha:1.0]         // Blue #0082c9

#define COLOR_ENCRYPTED [UIColor colorWithRed:241.0/255.0 green:90.0/255.0 blue:34.0/255.0 alpha:1.0]                   // #F15A22 - A 1.0
#define COLOR_GRAY [UIColor colorWithRed:65.0/255.0 green:64.0/255.0 blue:66.0/255.0 alpha:1.0]                         // #414042 - A 1.0
#define COLOR_CLEAR [UIColor colorWithRed:65.0/255.0 green:64.0/255.0 blue:66.0/255.0 alpha:1.0]
#define COLOR_BAR [UIColor colorWithRed:(248.0f/255.0f) green:(248.0f/255.0f) blue:(248.0f/255.0f) alpha:1.0]
#define COLOR_SEPARATOR_TABLE [UIColor colorWithRed:246.0/255.0 green:246.0/255.0 blue:246.0/255.0 alpha:1]             // Grigio chiaro
#define COLOR_NO_CONNECTION [UIColor colorWithRed:204.0/255.0 green:204.0/255.0 blue:204.0/255.0 alpha:1.0]
#define COLOR_NAVBAR_IOS7 [UIColor colorWithRed:247.0/255.0 green:247.0/255.0 blue:247.0/255.0 alpha:1.0]

// -----------------------------------------------------------------------------------------------------------
// -----------------------------------------------------------------------------------------------------------


@interface CCAspect : NSObject

+ (void)aspectNavigationControllerBar:(UINavigationBar *)nav hidden:(BOOL)hidden;
+ (void)aspectTabBar:(UITabBar *)tab hidden:(BOOL)hidden;

@end
