//
//  CCUtility.h
//  Nextcloud
//
//  Created by Marino Faggiana on 02/02/16.
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

#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <MessageUI/MessageUI.h>
#import <UICKeyChainStore/UICKeyChainStore.h>

#import "OCFileDto.h"
#import "CCGlobal.h"
#import "CCNetworking.h"

@class tableMetadata;

@interface CCUtility : NSObject

// ===== KeyChainStore =====

// GET/SET

+ (void)deleteAllChainStore;
+ (void)storeAllChainInService;

+ (NSString *)getVersion;
+ (NSString *)setVersion;

+ (NSString *)getBuild;
+ (NSString *)setBuild;

+ (NSString *)getBlockCode;
+ (void)setBlockCode:(NSString *)blockcode;

+ (BOOL)getSimplyBlockCode;
+ (void)setSimplyBlockCode:(BOOL)simply;

+ (BOOL)getOnlyLockDir;
+ (void)setOnlyLockDir:(BOOL)lockDir;

+ (NSString *)getOrderSettings;
+ (void)setOrderSettings:(NSString *)order;

+ (BOOL)getAscendingSettings;
+ (void)setAscendingSettings:(BOOL)ascendente;

+ (NSString *)getGroupBySettings;
+ (void)setGroupBySettings:(NSString *)groupby;

+ (BOOL)getIntro;
+ (void)setIntro:(BOOL)set;

+ (NSString *)getIncrementalNumber;

+ (NSString *)getActiveAccountExt;
+ (void)setActiveAccountExt:(NSString *)activeAccount;

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

+ (BOOL)getDirectoryOnTop;
+ (void)setDirectoryOnTop:(BOOL)directoryOnTop;

+ (BOOL)getOriginalFileName:(NSString *)key;
+ (void)setOriginalFileName:(BOOL)value key:(NSString *)key;

+ (NSString *)getFileNameMask:(NSString *)key;
+ (void)setFileNameMask:(NSString *)mask key:(NSString *)key;

+ (BOOL)getFileNameType:(NSString *)key;
+ (void)setFileNameType:(BOOL)prefix key:(NSString *)key;

+ (BOOL)getFavoriteOffline;
+ (void)setFavoriteOffline:(BOOL)offline;

+ (BOOL)getActivityVerboseHigh;
+ (void)setActivityVerboseHigh:(BOOL)debug;

+ (BOOL)getShowHiddenFiles;
+ (void)setShowHiddenFiles:(BOOL)show;

+ (BOOL)getFormatCompatibility;
+ (void)setFormatCompatibility:(BOOL)set;

+ (NSString *)getEndToEndPublicKey:(NSString *)account;
+ (void)setEndToEndPublicKey:(NSString *)account publicKey:(NSString *)publicKey;

+ (NSString *)getEndToEndPrivateKey:(NSString *)account;
+ (void)setEndToEndPrivateKey:(NSString *)account privateKey:(NSString *)privateKey;

+ (NSString *)getEndToEndPassphrase:(NSString *)account;
+ (void)setEndToEndPassphrase:(NSString *)account passphrase:(NSString *)passphrase;

+ (NSString *)getEndToEndPublicKeyServer:(NSString *)account;
+ (void)setEndToEndPublicKeyServer:(NSString *)account publicKey:(NSString *)publicKey;

+ (BOOL)isEndToEndEnabled:(NSString *)account;

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

+ (BOOL)getCertificateError:(NSString *)account;
+ (void)setCertificateError:(NSString *)account error:(BOOL)error;

+ (BOOL)getDisableLocalCacheAfterUpload;
+ (void)setDisableLocalCacheAfterUpload:(BOOL)disable;

+ (BOOL)getDarkMode;
+ (void)setDarkMode:(BOOL)disable;

+ (BOOL)getDarkModeDetect;
+ (void)setDarkModeDetect:(BOOL)disable;

+ (BOOL)getLivePhoto;
+ (void)setLivePhoto:(BOOL)set;

// ===== Varius =====

+ (BOOL)addSkipBackupAttributeToItemAtURL:(NSURL *)URL;

+ (NSString *)getUserAgent;

+ (NSString *)dateDiff:(NSDate *) convertedDate;
+ (NSDate *)dateEnUsPosixFromCloud:(NSString *)dateString;
+ (NSString *)transformedSize:(double)value;

+ (NSString *)removeForbiddenCharactersServer:(NSString *)fileName;
+ (NSString *)removeForbiddenCharactersFileSystem:(NSString *)fileName;

+ (NSString *)stringAppendServerUrl:(NSString *)serverUrl addFileName:(NSString *)addFileName;

+ (NSString *)createRandomString:(int)numChars;
+ (NSString *)createFileNameDate:(NSString *)fileName extension:(NSString *)extension;
+ (NSString *)createFileName:(NSString *)fileName fileDate:(NSDate *)fileDate fileType:(PHAssetMediaType)fileType keyFileName:(NSString *)keyFileName keyFileNameType:(NSString *)keyFileNameType keyFileNameOriginal:(NSString *)keyFileNameOriginal;

+ (void)createDirectoryStandard;

+ (NSURL *)getDirectoryGroup;
+ (NSString *)getHomeServerUrlActiveUrl:(NSString *)activeUrl;
+ (NSString *)getStringUser:(NSString *)activeUser activeUrl:(NSString *)activeUrl;
+ (NSString *)getDirectoryActiveUser:(NSString *)activeUser activeUrl:(NSString *)activeUrl;
+ (NSString *)getDirectoryDocuments;
+ (NSString *)getDirectoryReaderMetadata;
+ (NSString *)getDirectoryAudio;
+ (NSString *)getDirectoryCerificates;
+ (NSString *)getDirectoryUserData;
+ (NSString *)getDirectoryProviderStorage;
+ (NSString *)getDirectoryProviderStorageOcId:(NSString *)ocId;
+ (NSString *)getDirectoryProviderStorageOcId:(NSString *)ocId fileNameView:(NSString *)fileNameView;
+ (NSString *)getDirectoryProviderStorageIconOcId:(NSString *)ocId fileNameView:(NSString *)fileNameView;
+ (BOOL)fileProviderStorageExists:(NSString *)ocId fileNameView:(NSString *)fileNameView;
+ (double)fileProviderStorageSize:(NSString *)ocId fileNameView:(NSString *)fileNameView;
+ (BOOL)fileProviderStorageIconExists:(NSString *)ocId fileNameView:(NSString *)fileNameView;

+ (void)emptyGroupApplicationSupport;
+ (void)emptyGroupLibraryDirectory;
+ (void)emptyGroupDirectoryProviderStorage;
+ (void)emptyDocumentsDirectory;
+ (void)emptyTemporaryDirectory;
+ (void)clearTmpDirectory;

+ (NSString *)getTitleSectionDate:(NSDate *)date;

+ (void)moveFileAtPath:(NSString *)atPath toPath:(NSString *)toPath;
+ (void)copyFileAtPath:(NSString *)atPath toPath:(NSString *)toPath;
+ (void)removeFileAtPath:(NSString *)atPath;
+ (void)createDirectoryAtPath:(NSString *)atPath;

+ (NSString *)deletingLastPathComponentFromServerUrl:(NSString *)serverUrl;
+ (NSString *)firtsPathComponentFromServerUrl:(NSString *)serverUrl activeUrl:(NSString *)activeUrl;
+ (NSString *)getLastPathFromServerUrl:(NSString *)serverUrl activeUrl:(NSString *)activeUrl;
+ (NSString *)returnPathfromServerUrl:(NSString *)serverUrl activeUrl:(NSString *)activeUrl;
+ (NSString *)returnFileNamePathFromFileName:(NSString *)metadataFileName serverUrl:(NSString *)serverUrl activeUrl:(NSString *)activeUrl;

+ (NSArray *)createNameSubFolder:(PHFetchResult *)assets;

+ (BOOL)isDocumentModifiableExtension:(NSString *)fileExtension;

+ (NSString *)getDirectoryScan;

+ (NSString *)getMimeType:(NSString *)fileNameView;

+ (void)writeData:(NSData *)data fileNamePath:(NSString *)fileNamePath;

+ (void)selectFileNameFrom:(UITextField *)textField;

+ (NSString *)getTimeIntervalSince197;

+ (void)extractImageVideoFromAssetLocalIdentifierForUpload:(tableMetadata *)metadata completion:(void(^)(tableMetadata *metadataForUpload))completion;

// ===== E2E Encrypted =====

+ (NSString *)generateRandomIdentifier;
+ (BOOL)isFolderEncrypted:(NSString *)serverUrl e2eEncrypted:(BOOL)e2eEncrypted account:(NSString *)account;

// ===== CCMetadata =====

+ (tableMetadata *)createMetadataWithAccount:(NSString *)account date:(NSDate *)date directory:(BOOL)directory ocId:(NSString *)ocId serverUrl:(NSString *)serverUrl fileName:(NSString *)fileName etag:(NSString *)etag size:(double)size status:(double)status url:(NSString *)url contentType:(NSString *)contentType;

//+ (tableMetadata *)trasformedOCFileToCCMetadata:(OCFileDto *)itemDto fileName:(NSString *)fileName serverUrl:(NSString *)serverUrl  account:(NSString *)account isFolderEncrypted:(BOOL)isFolderEncrypted;

+ (tableMetadata *)insertFileSystemInMetadata:(tableMetadata *)metadata;
+ (NSString *)insertTypeFileIconName:(NSString *)fileNameView metadata:(tableMetadata *)metadata;

+ (NSString *)createMetadataIDFromAccount:(NSString *)account serverUrl:(NSString *)serverUrl fileNameView:(NSString *)fileNameView directory:(BOOL)directory;

+ (NSString *)convertOcIdToFileId:(NSString *)ocId;

// ===== Third parts =====

+ (NSString *)stringValueForKey:(id)key conDictionary:(NSDictionary *)dictionary;
+ (NSString *)currentDevice;
+ (NSString *)getExtension:(NSString*)fileName;
+ (NSDate*)parseDateString:(NSString*)dateString;
+ (NSDate *)datetimeWithOutTime:(NSDate *)datDate;
+ (NSDate *)datetimeWithOutDate:(NSDate *)datDate;
+ (BOOL)isValidEmail:(NSString *)checkString;
+ (NSString *)URLEncodeStringFromString:(NSString *)string;
+ (NSString *)hexRepresentation:(NSData *)data spaces:(BOOL)spaces;
+ (NSString *)valueForKey:(NSString *)key fromQueryItems:(NSArray *)queryItems;

@end
