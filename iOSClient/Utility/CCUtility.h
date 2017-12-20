//
//  CCUtility.h
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 02/02/16.
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

// ADMIN

+ (void)adminRemoveIntro;
+ (void)adminRemovePasscode;
+ (void)adminRemoveVersion;

// GET/SET

+ (void)deleteAllChainStore;
+ (void)storeAllChainInService;

+ (NSString *)getUUID;

+ (NSString *)getKeyChainPasscodeForUUID:(NSString *)uuid;
+ (void)setKeyChainPasscodeForUUID:(NSString *)uuid conPasscode:(NSString *)passcode;

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

+ (BOOL)getOptimizedPhoto;
+ (void)setOptimizedPhoto:(BOOL)resize;

+ (BOOL)getUploadAndRemovePhoto;
+ (void)setUploadAndRemovePhoto:(BOOL)remove;

+ (NSString *)getOrderSettings;
+ (void)setOrderSettings:(NSString *)order;

+ (BOOL)getAscendingSettings;
+ (void)setAscendingSettings:(BOOL)ascendente;

+ (NSString *)getGroupBySettings;
+ (void)setGroupBySettings:(NSString *)groupby;

+ (BOOL)getIntroMessage:(NSString *)type;
+ (void)setIntroMessage:(NSString *)type set:(BOOL)set;

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

// ===== Varius =====

+ (NSString *)getUserAgent;

+ (NSString *)dateDiff:(NSDate *) convertedDate;
+ (NSDate *)dateEnUsPosixFromCloud:(NSString *)dateString;
+ (NSString *)transformedSize:(double)value;

+ (NSString *)removeForbiddenCharactersServer:(NSString *)fileName;
+ (NSString *)removeForbiddenCharactersFileSystem:(NSString *)fileName;

+ (NSString *)stringAppendServerUrl:(NSString *)serverUrl addFileName:(NSString *)addFileName;

+ (NSString *)createRandomString:(int)numChars;
+ (NSString *)createFileName:fileName fileDate:(NSDate *)fileDate fileType:(PHAssetMediaType)fileType keyFileName:(NSString *)keyFileName keyFileNameType:(NSString *)keyFileNameType;

+ (NSString *)getHomeServerUrlActiveUrl:(NSString *)activeUrl;
+ (NSString *)getDirectoryActiveUser:(NSString *)activeUser activeUrl:(NSString *)activeUrl;
+ (NSString *)getOLDDirectoryActiveUser:(NSString *)activeUser activeUrl:(NSString *)activeUrl;
+ (NSString *)getDirectoryLocal;
+ (NSString *)getDirectoryAudio;
+ (NSString *)getDirectoryCerificates;
+ (NSString *)getTitleSectionDate:(NSDate *)date;

+ (void)moveFileAtPath:(NSString *)atPath toPath:(NSString *)toPath;
+ (void)copyFileAtPath:(NSString *)atPath toPath:(NSString *)toPath;
+ (void)removeAllFileID_UPLOAD_ActiveUser:(NSString *)activeUser activeUrl:(NSString *)activeUrl;

+ (NSString *)deletingLastPathComponentFromServerUrl:(NSString *)serverUrl;
+ (NSString *)returnFileNamePathFromFileName:(NSString *)metadataFileName serverUrl:(NSString *)serverUrl activeUrl:(NSString *)activeUrl;

+ (NSArray *)createNameSubFolder:(PHFetchResult *)assets;

// ===== E2E Encrypted =====

+ (NSString *)generateRandomIdentifier;
+ (BOOL)isFolderEncrypted:(NSString *)serverUrl account:(NSString *)account;

// ===== CCMetadata =====

+ (tableMetadata *)createMetadataWithAccount:(NSString *)account date:(NSDate *)date directory:(BOOL)directory fileID:(NSString *)fileID directoryID:(NSString *)directoryID fileName:(NSString *)fileName etag:(NSString *)etag size:(double)size status:(double)status;

+ (tableMetadata *)trasformedOCFileToCCMetadata:(OCFileDto *)itemDto fileName:(NSString *)fileName serverUrl:(NSString *)serverUrl directoryID:(NSString *)directoryID autoUploadFileName:(NSString *)autoUploadFileName autoUploadDirectory:(NSString *)autoUploadDirectory activeAccount:(NSString *)activeAccount directoryUser:(NSString *)directoryUser isFolderEncrypted:(BOOL)isFolderEncrypted;

+ (tableMetadata *)insertFileSystemInMetadata:(NSString *)fileName fileNameView:(NSString *)fileNameView directory:(NSString *)directory activeAccount:(NSString *)activeAccount;

+ (void)insertTypeFileIconName:(NSString *)fileNameView metadata:(tableMetadata *)metadata;

// ===== Third parts =====

+ (NSString *)stringValueForKey:(id)key conDictionary:(NSDictionary *)dictionary;
+ (NSString *)currentDevice;
+ (NSString *)getExtension:(NSString*)fileName;
+ (NSDate*)parseDateString:(NSString*)dateString;
+ (NSDate *)datetimeWithOutTime:(NSDate *)datDate;
+ (NSDate *)datetimeWithOutDate:(NSDate *)datDate;
+ (BOOL)isValidEmail:(NSString *)checkString;
+ (NSString *)URLEncodeStringFromString:(NSString *)string;

@end
