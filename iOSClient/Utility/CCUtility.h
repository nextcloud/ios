//
//  CCUtility.h
//  Nextcloud
//
//  Created by Marino Faggiana on 02/02/16.
//  Copyright (c) 2016 Marino Faggiana. All rights reserved.
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

#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <MessageUI/MessageUI.h>
#import <UICKeyChainStore.h>
#import <Photos/Photos.h>
#import <PDFKit/PDFKit.h>

@class tableMetadata;

@interface CCUtility : NSObject

// ===== KeyChainStore =====

// GET/SET

+ (void)deleteAllChainStore;
+ (void)storeAllChainInService;

+ (NSString *)getPasscode;
+ (void)setPasscode:(NSString *)passcode;

+ (BOOL)getNotPasscodeAtStart;
+ (void)setNotPasscodeAtStart:(BOOL)set;

+ (BOOL)getEnableTouchFaceID;
+ (void)setEnableTouchFaceID:(BOOL)set;

+ (BOOL)isPasscodeAtStartEnabled;

+ (NSString *)getGroupBySettings;
+ (void)setGroupBySettings:(NSString *)groupby;

+ (BOOL)getIntro;
+ (void)setIntro:(BOOL)set;

+ (NSString *)getIncrementalNumber;

+ (NSString *)getAccountExt;
+ (void)setAccountExt:(NSString *)account;

+ (NSString *)getServerUrlExt;
+ (void)setServerUrlExt:(NSString *)serverUrl;

+ (NSString *)getTitleServerUrlExt;
+ (void)setTitleServerUrlExt:(NSString *)titleServerUrl;

+ (NSString *)getFileNameExt;
+ (void)setFileNameExt:(NSString *)fileName;

+ (NSString *)getEmail;
+ (void)setEmail:(NSString *)email;

+ (NSString *)getHint;
+ (void)setHint:(NSString *)hint;

+ (BOOL)getOriginalFileName:(NSString *)key;
+ (void)setOriginalFileName:(BOOL)value key:(NSString *)key;

+ (NSString *)getFileNameMask:(NSString *)key;
+ (void)setFileNameMask:(NSString *)mask key:(NSString *)key;

+ (BOOL)getFileNameType:(NSString *)key;
+ (void)setFileNameType:(BOOL)prefix key:(NSString *)key;

+ (BOOL)getActivityVerboseHigh;
+ (void)setActivityVerboseHigh:(BOOL)debug;

+ (BOOL)getShowHiddenFiles;
+ (void)setShowHiddenFiles:(BOOL)show;

+ (BOOL)getFormatCompatibility;
+ (void)setFormatCompatibility:(BOOL)set;

// E2EE -------------------------------------------

+ (NSString *)getEndToEndCertificate:(NSString *)account;
+ (void)setEndToEndCertificate:(NSString *)account certificate:(NSString *)certificate;

+ (NSString *)getEndToEndPrivateKey:(NSString *)account;
+ (void)setEndToEndPrivateKey:(NSString *)account privateKey:(NSString *)privateKey;

+ (NSString *)getEndToEndPublicKey:(NSString *)account;
+ (void)setEndToEndPublicKey:(NSString *)account publicKey:(NSString *)publicKey;

+ (NSString *)getEndToEndPassphrase:(NSString *)account;
+ (void)setEndToEndPassphrase:(NSString *)account passphrase:(NSString *)passphrase;

+ (BOOL)isEndToEndEnabled:(NSString *)account;

// E2EE -------------------------------------------

+ (void)clearAllKeysEndToEnd:(NSString *)account;

+ (BOOL)getDisableFilesApp;
+ (void)setDisableFilesApp:(BOOL)disable;

+ (void)setPushNotificationPublicKey:(NSString *)account data:(NSData *)data;
+ (NSData *)getPushNotificationPublicKey:(NSString *)account;
+ (void)setPushNotificationSubscribingPublicKey:(NSString *)account publicKey:(NSString *)publicKey;
+ (NSString *)getPushNotificationSubscribingPublicKey:(NSString *)account;
+ (void)setPushNotificationPrivateKey:(NSString *)account data:(NSData *)data;
+ (NSData *)getPushNotificationPrivateKey:(NSString *)account;
+ (void)setPushNotificationToken:(NSString *)account token:(NSString *)token;
+ (NSString *)getPushNotificationToken:(NSString *)account;
+ (void)setPushNotificationDeviceIdentifier:(NSString *)account deviceIdentifier:(NSString *)deviceIdentifier;
+ (NSString *)getPushNotificationDeviceIdentifier:(NSString *)account;
+ (void)setPushNotificationDeviceIdentifierSignature:(NSString *)account deviceIdentifierSignature:(NSString *)deviceIdentifierSignature;
+ (NSString *)getPushNotificationDeviceIdentifierSignature:(NSString *)account;
+ (void)clearAllKeysPushNotification:(NSString *)account;

+ (NSInteger)getMediaWidthImage;
+ (void)setMediaWidthImage:(NSInteger)width;

+ (BOOL)getDisableCrashservice;
+ (void)setDisableCrashservice:(BOOL)disable;

+ (void)setPassword:(NSString *)account password:(NSString *)password;
+ (NSString *)getPassword:(NSString *)account;

+ (void)setHCBusinessType:(NSString *)professions;
+ (NSString *)getHCBusinessType;

+ (NSData *)getDatabaseEncryptionKey;

+ (BOOL)getDisableLocalCacheAfterUpload;
+ (void)setDisableLocalCacheAfterUpload:(BOOL)disable;

+ (BOOL)getLivePhoto;
+ (void)setLivePhoto:(BOOL)set;

+ (NSString *)getMediaSortDate;
+ (void)setMediaSortDate:(NSString *)value;

+ (NSInteger)getTextRecognitionStatus;
+ (void)setTextRecognitionStatus:(NSInteger)value;
+ (NSString *)getDirectoryScanDocuments;
+ (void)setDirectoryScanDocuments:(NSString *)value;

+ (NSInteger)getLogLevel;
+ (void)setLogLevel:(NSInteger)value;

+ (BOOL)getAudioMute;
+ (void)setAudioMute:(BOOL)set;

+ (BOOL)getAutomaticDownloadImage;
+ (void)setAutomaticDownloadImage:(BOOL)set;

+ (BOOL)getAccountRequest;
+ (void)setAccountRequest:(BOOL)set;

+ (NSInteger)getChunkSize;
+ (void)setChunkSize:(NSInteger)size;

+ (NSInteger)getCleanUpDay;
+ (void)setCleanUpDay:(NSInteger)days;

+ (PDFDisplayDirection)getPDFDisplayDirection;
+ (void)setPDFDisplayDirection:(PDFDisplayDirection)direction;

+ (BOOL)getPrivacyScreenEnabled;
+ (void)setPrivacyScreenEnabled:(BOOL)set;

// ===== Varius =====

+ (BOOL)addSkipBackupAttributeToItemAtURL:(NSURL *)URL;

+ (NSString *)getUserAgent;

+ (NSString *)dateDiff:(NSDate *)convertedDate;
+ (NSString *)transformedSize:(int64_t)value;

+ (NSString *)removeForbiddenCharactersServer:(NSString *)fileName;
+ (NSString *)removeForbiddenCharactersFileSystem:(NSString *)fileName;

+ (NSString *)stringAppendServerUrl:(NSString *)serverUrl addFileName:(NSString *)addFileName;

+ (NSString *)createRandomString:(int)numChars;
+ (NSString *)createFileNameDate:(NSString *)fileName extension:(NSString *)extension;
+ (NSString *)createFileName:(NSString *)fileName fileDate:(NSDate *)fileDate fileType:(PHAssetMediaType)fileType keyFileName:(NSString *)keyFileName keyFileNameType:(NSString *)keyFileNameType keyFileNameOriginal:(NSString *)keyFileNameOriginal forcedNewFileName:(BOOL)forcedNewFileName;

+ (void)createDirectoryStandard;

+ (NSURL *)getDirectoryGroup;
+ (NSString *)getDirectoryDocuments;
+ (NSString *)getDirectoryReaderMetadata;
+ (NSString *)getDirectoryAudio;
+ (NSString *)getDirectoryCerificates;
+ (NSString *)getDirectoryUserData;
+ (NSString *)getDirectoryProviderStorage;
+ (NSString *)getDirectoryProviderStorageOcId:(NSString *)ocId;
+ (NSString *)getDirectoryProviderStorageOcId:(NSString *)ocId fileNameView:(NSString *)fileNameView;
+ (NSString *)getDirectoryProviderStorageIconOcId:(NSString *)ocId etag:(NSString *)etag;
+ (NSString *)getDirectoryProviderStoragePreviewOcId:(NSString *)ocId etag:(NSString *)etag;
+ (BOOL)fileProviderStorageExists:(NSString *)ocId fileNameView:(NSString *)fileNameView;
+ (int64_t)fileProviderStorageSize:(NSString *)ocId fileNameView:(NSString *)fileNameView;
+ (BOOL)fileProviderStoragePreviewIconExists:(NSString *)ocId etag:(NSString *)etag;

+ (void)removeGroupApplicationSupport;
+ (void)removeGroupLibraryDirectory;
+ (void)removeGroupDirectoryProviderStorage;
+ (void)removeDocumentsDirectory;
+ (void)removeTemporaryDirectory;
+ (void)emptyTemporaryDirectory;

+ (NSString *)getTitleSectionDate:(NSDate *)date;

+ (void)moveFileAtPath:(NSString *)atPath toPath:(NSString *)toPath;
+ (void)copyFileAtPath:(NSString *)atPath toPath:(NSString *)toPath;
+ (void)removeFileAtPath:(NSString *)atPath;
+ (void)createDirectoryAtPath:(NSString *)atPath;

+ (NSString *)returnPathfromServerUrl:(NSString *)serverUrl urlBase:(NSString *)urlBase account:(NSString *)account;
+ (NSString *)returnFileNamePathFromFileName:(NSString *)metadataFileName serverUrl:(NSString *)serverUrl urlBase:(NSString *)urlBase account:(NSString *)account;
+ (NSArray *)createNameSubFolder:(NSArray *)assets;

+ (NSString *)getDirectoryScan;

+ (NSString *)getMimeType:(NSString *)fileNameView;

+ (void)extractImageVideoFromAssetLocalIdentifierForUpload:(tableMetadata *)metadataForUpload notification:(BOOL)notification completion:(void(^)(tableMetadata *newMetadata, NSString* fileNamePath))completion;
+ (void)extractLivePhotoAsset:(PHAsset*)asset filePath:(NSString *)filePath withCompletion:(void (^)(NSURL* url))completion;

// ===== E2E Encrypted =====

+ (NSString *)generateRandomIdentifier;
+ (BOOL)isFolderEncrypted:(NSString *)serverUrl e2eEncrypted:(BOOL)e2eEncrypted account:(NSString *)account urlBase:(NSString *)urlBase;

// ===== Share Permissions =====

+ (NSInteger)getPermissionsValueByCanEdit:(BOOL)canEdit andCanCreate:(BOOL)canCreate andCanChange:(BOOL)canChange andCanDelete:(BOOL)canDelete andCanShare:(BOOL)canShare andIsFolder:(BOOL) isFolder;
+ (BOOL)isPermissionToCanCreate:(NSInteger) permissionValue;
+ (BOOL)isPermissionToCanChange:(NSInteger) permissionValue;
+ (BOOL)isPermissionToCanDelete:(NSInteger) permissionValue;
+ (BOOL)isPermissionToCanShare:(NSInteger) permissionValue;
+ (BOOL)isAnyPermissionToEdit:(NSInteger) permissionValue;
+ (BOOL)isPermissionToRead:(NSInteger) permissionValue;
+ (BOOL)isPermissionToReadCreateUpdate:(NSInteger) permissionValue;

// ===== EXIF =====

+ (void)setExif:(tableMetadata *)metadata withCompletionHandler:(void(^)(double latitude, double longitude, NSString *location, NSDate *date, NSString *lensModel))completition;

// ===== Third parts =====

+ (NSString *)getExtension:(NSString*)fileName;
+ (NSDate *)datetimeWithOutTime:(NSDate *)datDate;
+ (NSString *)valueForKey:(NSString *)key fromQueryItems:(NSArray *)queryItems;
+ (NSDate *)getATime:(const char *)path;

@end
