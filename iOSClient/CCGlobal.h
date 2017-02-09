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
#define versionProtocolPlist @"1.3"

// UUID
#define UUID_SIM @"4BACFE4A-61A6-44B1-9A85-13FD167565AB"

// Capabilities Group & Service Key Share
#define capabilitiesGroups @"group.it.twsweb.Crypto-Cloud"
#define serviceShareKeyChain @"Crypto Cloud"

// BRAND
#ifdef CC

#define _brand_     @"Crypto Cloud"
#define _mail_me_   @"cryptocloud@twsweb.it"
#endif

#ifdef NC

#define _brand_     @"Nextcloud"
#define _mail_me_   @"ios@nextcloud.com"

#endif

// COLOR

#ifdef CC // CRYPTOCLOUD ORANGE

#define COLOR_BRAND               [UIColor colorWithRed:241.0/255.0 green:90.0/255.0 blue:34.0/255.0 alpha:1.0]         // #F15A22 - A 1.0
#define COLOR_BRAND_MESSAGE       [UIColor colorWithRed:241.0/255.0 green:90.0/255.0 blue:34.0/255.0 alpha:0.90]        // #F15A22 - A 1.0
#define COLOR_SELECT_BACKGROUND   [UIColor colorWithRed:241.0/255.0 green:90.0/255.0 blue:34.0/255.0 alpha:0.1]         // #F15A22 - A 0.1
#define COLOR_TRANSFER_BACKGROUND [UIColor colorWithRed:252.0/255.0 green:242.0/255.0 blue:238.0/255.0 alpha:0.5]       // Arancio chiarissimo
#define COLOR_GROUPBY_BAR         [UIColor colorWithRed:241.0/255.0 green:90.0/255.0 blue:34.0/255.0 alpha:0.2]         // #F15A22 - A 0.2
#define COLOR_GROUPBY_BAR_NO_BLUR [UIColor colorWithRed:255.0/255.0 green:153.0/255.0 blue:102.0/255.0 alpha:0.3]       // #FF9966

#endif

#ifdef NC // NEXTCLOUD BLUE

#define COLOR_BRAND               [UIColor colorWithRed:0.0/255.0 green:130.0/255.0 blue:201.0/255.0 alpha:1.0]
#define COLOR_BRAND_MESSAGE       [UIColor colorWithRed:0.0/255.0 green:130.0/255.0 blue:201.0/255.0 alpha:0.90]
#define COLOR_SELECT_BACKGROUND   [UIColor colorWithRed:0.0/255.0 green:130.0/255.0 blue:201.0/255.0 alpha:0.1]
#define COLOR_TRANSFER_BACKGROUND [UIColor colorWithRed:178.0/255.0 green:244.0/255.0 blue:258.0/255.0 alpha:0.1]       // Blu chiarissimo
#define COLOR_GROUPBY_BAR         [UIColor colorWithRed:0.0/255.0 green:130.0/255.0 blue:201.0/255.0 alpha:0.2]
#define COLOR_GROUPBY_BAR_NO_BLUR [UIColor colorWithRed:0.0/255.0 green:130.0/255.0 blue:201.0/255.0 alpha:0.3]

#endif

#define COLOR_CRYPTOCLOUD         [UIColor colorWithRed:241.0/255.0 green:90.0/255.0 blue:34.0/255.0 alpha:1.0]         // Arancio
#define COLOR_NEXTCLOUD           [UIColor colorWithRed:0.0/255.0 green:130.0/255.0 blue:201.0/255.0 alpha:1.0]         // Blue #0082c9

#define COLOR_ENCRYPTED [UIColor colorWithRed:241.0/255.0 green:90.0/255.0 blue:34.0/255.0 alpha:1.0]                   // #F15A22 - A 1.0
#define COLOR_GRAY [UIColor colorWithRed:65.0/255.0 green:64.0/255.0 blue:66.0/255.0 alpha:1.0]                         // #414042 - A 1.0
#define COLOR_CLEAR [UIColor colorWithRed:65.0/255.0 green:64.0/255.0 blue:66.0/255.0 alpha:1.0]
#define COLOR_BAR [UIColor colorWithRed:(248.0f/255.0f) green:(248.0f/255.0f) blue:(248.0f/255.0f) alpha:1.0]
#define COLOR_SEPARATOR_TABLE [UIColor colorWithRed:246.0/255.0 green:246.0/255.0 blue:246.0/255.0 alpha:1]           // Grigio chiaro
#define COLOR_NO_CONNECTION [UIColor colorWithRed:204.0/255.0 green:204.0/255.0 blue:204.0/255.0 alpha:1.0]
#define COLOR_NAVBAR_IOS7 [UIColor colorWithRed:247.0/255.0 green:247.0/255.0 blue:247.0/255.0 alpha:1.0]

#define dismissAfterSecond 4

#define MaxDimensionUpload 524288000       // 500 MB

#define dayForceReadFolder 3

#define MaxGroupBySessionUploadDatasource 50
#define MaxGroupBySessionDownloadDatasource 50

#define returnCreateFolderPlain 0
#define returnCreateFotoVideoPlain 1
#define returnCreateFilePlain 2
#define returnCreateFolderEncrypted 3
#define returnCreateFotoVideoEncrypted 4
#define returnCreateFileEncrypted 5
#define returnCartaDiCredito 6
#define returnBancomat 7
#define returnContoCorrente 8
#define returnAccountWeb 9
#define returnNote 10
#define returnPatenteGuida 11
#define returnCartaIdentita 12
#define returnPassaporto 13

#define RalewayBold(s) [UIFont fontWithName:@"Raleway-Bold" size:s]
#define RalewayExtraBold(s) [UIFont fontWithName:@"Raleway-ExtraBold" size:s]
#define RalewayExtraLight(s) [UIFont fontWithName:@"Raleway-ExtraLight" size:s]
#define RalewayHeavy(s) [UIFont fontWithName:@"Raleway-Heavy" size:s]
#define RalewayLight(s) [UIFont fontWithName:@"Raleway-Light" size:s]
#define RalewayMedium(s) [UIFont fontWithName:@"Raleway-Medium" size:s]
#define RalewayRegular(s) [UIFont fontWithName:@"Raleway-Regular" size:s]
#define RalewaySemiBold(s) [UIFont fontWithName:@"Raleway-SemiBold" size:s]
#define RalewayThin(s) [UIFont fontWithName:@"Raleway-Thin" size:s]

// File Name Const
#define folderDefaultCameraUpload   @"Photos"

// Picker select image
#define pickerControllerMax  500.0

// define ownCloud IOS
#define server_version_with_new_shared_schema 8
#define k_share_link_middle_part_url_before_version_8   @"public.php?service=files&t="
#define k_share_link_middle_part_url_after_version_8    @"index.php/s/"

// Constants to identify the different permissions of a file
#define k_permission_shared @"S"
#define k_permission_can_share @"R"
#define k_permission_mounted @"M"
#define k_permission_file_can_write @"W"
#define k_permission_can_create_file @"C"
#define k_permission_can_create_folder @"K"
#define k_permission_can_delete @"D"
#define k_permission_can_rename @"N"
#define k_permission_can_move @"V"

// Session
#define download_session                @"it.twsweb.download.session"
#define download_session_foreground     @"it.twsweb.download.sessionforeground"
#define download_session_wwan           @"it.twsweb.download.sessionwwan"

#define upload_session                  @"it.twsweb.upload.session"
#define upload_session_foreground       @"it.twsweb.upload.sessionforeground"
#define upload_session_wwan             @"it.twsweb.upload.sessionwwan"

#define networkingSessionNotification   @"networkingSessionNotification"

// TaskIdentifier
#define taskIdentifierDone -1
#define taskIdentifierStop -2
#define taskIdentifierError -9999
#define taskIdentifierNULL 9999

// TaskStatus
#define taskStatusNone 0
#define taskStatusCancel -1
#define taskStatusResume -2
#define taskStatusSuspend -3

#define timerVerifySession 15.0

// OperationQueue
#define netQueueName                    @"it.twsweb.cryptocloud.queue"
#define netQueueDownloadName            @"it.twsweb.cryptocloud.queueDownload"
#define netQueueDownloadWWanName        @"it.twsweb.cryptocloud.queueDownloadWWan"
#define netQueueUploadName              @"it.twsweb.cryptocloud.queueUpload"
#define netQueueUploadWWanName          @"it.twsweb.cryptocloud.queueUploadWWan"

#define maxConcurrentOperation 10
#define maxConcurrentOperationDownloadUpload 10

// Error
#define CCErrorTaskNil -9999
#define CCErrorTaskDownloadNotFound -9998
#define CCErrorFileUploadNotFound -9997
#define CCErrorInternalError -9996

// Metadata ed ID
#define uploadSessionID @"ID_UPLOAD_"

// Metadata.Net SELECTOR
#define selectorAddOffline              @"addOffline"
#define selectorAddLocal                @"addLocal"
#define selectorCreateFolder            @"createFolder"
#define selectorDecryptFile             @"decryptFile"
#define selectorDelete                  @"delete"
#define selectorDeleteCrypto            @"deleteCrypto"
#define selectorDeletePlist             @"deletePlist"
#define selectorDownloadThumbnail       @"downloadThumbnail"
#define selectorDownloadOffline         @"downloadOffline"
#define selectorEncryptFile             @"encryptFile"
#define selectorGetUserAndGroup         @"getUserAndGroup"
#define selectorLoadFileView            @"loadFileView"
#define selectorLoadModelView           @"loadModelView"
#define selectorLoadPlist               @"loadPlist"
#define selectorLoadViewImage           @"loadViewImage"
#define selectorLoadCopy                @"loadCopy"
#define selectorMove                    @"move"
#define selectorMoveCrypto              @"moveCrypto"
#define selectorMovePlist               @"movePlist"
#define selectorOpenIn                  @"openIn"
#define selectorOpenWindowShare         @"openWindowShare"
#define selectorReadFile                @"readFile"
#define selectorReadFileOffline         @"readFileOffline"
#define selectorReadFileFolder          @"readFileFolder"
#define selectorReadFileUploadFile      @"readFileUploadFile"
#define selectorReadFileVerifyUpload    @"readFileVerifyUpload"
#define selectorReadFileQuota           @"readFileQuota"
#define selectorReadFolder              @"readFolder"
#define selectorReadFolderForced        @"readFolderForced"
#define selectorReadShare               @"readShare"
#define selectorReload                  @"reload"
#define selectorRename                  @"rename"
#define selectorSave                    @"save"
#define selectorShare                   @"share"
#define selectorOfflineFolder           @"offlineFolder"
#define selectorUnshare                 @"unshare"
#define selectorUpdateShare             @"updateShare"
#define selectorUploadAutomatic         @"uploadAutomatic"
#define selectorUploadAutomaticAll      @"uploadAutomaticAll"
#define selectorUploadFile              @"uploadFile"
#define selectorUploadFileCrypto        @"uploadFileCrypto"
#define selectorUploadFilePlist         @"uploadFilePlist"
#define selectorUploadRemovePhoto       @"uploadRemovePhoto"

// Metadata.Net ACTION
#define actionCreateFolder              @"createFolder"
#define actionDeleteFileDirectory       @"deleteFileOrFolder"
#define actionDownloadFile              @"downloadFile"
#define actionDownloadThumbnail         @"downloadThumbnail"
#define actionGetCapabilities           @"getCapabilitiesOfServer"
#define actionGetFeaturesSuppServer     @"getFeaturesSupportedByServer"
#define actionGetUserAndGroup           @"getUserAndGroup"
#define actionGetNotificationsOfServer  @"getNotificationsOfServer"
#define actionSetNotificationServer     @"setNotificationServer"
#define actionMoveFileOrFolder          @"moveFileOrFolder"
#define actionReadFile                  @"readFile"
#define actionReadFolder                @"readFolder"
#define actionReadShareServer           @"readShareServer"
#define actionShare                     @"share"
#define actionShareWith                 @"shareWith"
#define actionUnShare                   @"unShare"
#define actionUpdateShare               @"updateShare"
#define actionUploadFile                @"uploadFile"
#define actionUploadAsset               @"uploadAsset"
#define actionUploadTemplate            @"uploadTemplate"
#define actionUploadOnlyPlist           @"uploadOnlyPlist"

// Metadata : FileType
#define metadataTypeFile_audio          @"audio"
#define metadataTypeFile_compress       @"compress"
#define metadataTypeFile_directory      @"directory"
#define metadataTypeFile_document       @"document"
#define metadataTypeFile_image          @"image"
#define metadataTypeFile_template       @"template"
#define metadataTypeFile_unknown        @"unknow"
#define metadataTypeFile_video          @"video"

// Metadata : Type
#define metadataType_file               @"file"
#define metadataType_model              @"model"
#define metadataType_local              @"local"

// Metadata : Filename Type
#define metadataTypeFilenamePlain       0
#define metadataTypeFilenamePlist       1
#define metadataTypeFilenameCrypto      2

#define TabBarApplicationIndexFile      0
#define TabBarApplicationIndexOffline   1
#define TabBarApplicationIndexHide      2
#define TabBarApplicationIndexPhotos    3
#define TabBarApplicationIndexSettings  4

#define keyFileNameMask                 @"fileNameMask"
#define keyFileNameMaskAutomaticPhotos  @"fileNameMaskAutomaticPhotos"

// Type of page Offline
#define pageOfflineOffline              @"Offline"
#define pageOfflineLocal                @"Local"

@interface CCAspect : NSObject

+ (void)aspectNavigationControllerBar:(UINavigationBar *)nav hidden:(BOOL)hidden;
+ (void)aspectTabBar:(UITabBar *)tab hidden:(BOOL)hidden;

@end
