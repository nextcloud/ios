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

// SET

+ (void)deleteAllChainStore;

+ (void)storeAllChainInService;

+ (void)setKeyChainPasscodeForUUID:(NSString *)uuid conPasscode:(NSString *)passcode;

+ (NSString *)setVersion;
+ (NSString *)setBuild;

+ (void)setBlockCode:(NSString *)blockcode;
+ (void)setSimplyBlockCode:(BOOL)simply;
+ (void)setOnlyLockDir:(BOOL)lockDir;

+ (void)setOptimizedPhoto:(BOOL)resize;
+ (void)setUploadAndRemovePhoto:(BOOL)remove;

+ (void)setOrderSettings:(NSString *)order;
+ (void)setAscendingSettings:(BOOL)ascendente;
+ (void)setGroupBySettings:(NSString *)groupby;

+ (void)setIntroMessage:(NSString *)type set:(BOOL)set;

+ (void)setActiveAccountExt:(NSString *)activeAccount;
+ (void)setServerUrlExt:(NSString *)serverUrl;
+ (void)setTitleServerUrlExt:(NSString *)titleServerUrl;
+ (void)setFileNameExt:(NSString *)fileName;

+ (void)setEmail:(NSString *)email;

+ (void)setHint:(NSString *)hint;

+ (void)setDirectoryOnTop:(BOOL)directoryOnTop;

+ (void)setFileNameMask:(NSString *)mask key:(NSString *)key;
+ (void)setFileNameType:(BOOL)prefix key:(NSString *)key;

+ (void)setCreateMenuEncrypted:(BOOL)encrypted;

+ (void)setFavoriteOffline:(BOOL)offline;

+ (void)setActivityVerboseHigh:(BOOL)debug;

+ (void)setShowHiddenFiles:(BOOL)show;

+ (void)setEndToEndPublicKeySign:(NSString *)account publicKey:(NSString *)publicKey;
+ (void)setEndToEndPrivateKey:(NSString *)account privateKey:(NSString *)privateKey;
+ (void)setEndToEndPassphrase:(NSString *)account passphrase:(NSString *)passphrase;
+ (void)initEndToEnd:(NSString *)account;

// GET

+ (NSString *)getKeyChainPasscodeForUUID:(NSString *)uuid;
+ (NSString *)getUUID;

+ (NSString *)getVersion;
+ (NSString *)getBuild;

+ (NSString *)getBlockCode;
+ (BOOL)getSimplyBlockCode;
+ (BOOL)getOnlyLockDir;

+ (BOOL)getOptimizedPhoto;
+ (BOOL)getUploadAndRemovePhoto;

+ (NSString *)getOrderSettings;
+ (BOOL)getAscendingSettings;
+ (NSString *)getGroupBySettings;

+ (BOOL)getIntroMessage:(NSString *)type;

+ (NSString *)getIncrementalNumber;

+ (NSString *)getActiveAccountExt;
+ (NSString *)getServerUrlExt;
+ (NSString *)getTitleServerUrlExt;
+ (NSString *)getFileNameExt;

+ (NSString *)getEmail;

+ (NSString *)getHint;

+ (BOOL)getDirectoryOnTop;

+ (NSString *)getFileNameMask:(NSString *)key;
+ (BOOL)getFileNameType:(NSString *)key;

+ (BOOL)getCreateMenuEncrypted;

+ (BOOL)getFavoriteOffline;

+ (BOOL)getActivityVerboseHigh;

+ (BOOL)getShowHiddenFiles;

+ (NSString *)getEndToEndPublicKeySign:(NSString *)account;
+ (NSString *)getEndToEndPrivateKey:(NSString *)account;
+ (NSString *)getEndToEndPassphrase:(NSString *)account;
+ (BOOL)isEndToEndEnabled:(NSString *)account;

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

// ===== CCMetadata =====

+ (tableMetadata *)createMetadataWithAccount:(NSString *)account date:(NSDate *)date directory:(BOOL)directory fileID:(NSString *)fileID directoryID:(NSString *)directoryID fileName:(NSString *)fileName etag:(NSString *)etag size:(double)size status:(double)status;

+ (tableMetadata *)trasformedOCFileToCCMetadata:(OCFileDto *)itemDto fileName:(NSString *)fileName serverUrl:(NSString *)serverUrl directoryID:(NSString *)directoryID autoUploadFileName:(NSString *)autoUploadFileName autoUploadDirectory:(NSString *)autoUploadDirectory activeAccount:(NSString *)activeAccount directoryUser:(NSString *)directoryUser;


+ (tableMetadata *)insertFileSystemInMetadata:(NSString *)fileName directory:(NSString *)directory activeAccount:(NSString *)activeAccount autoUploadFileName:(NSString *)autoUploadFileName autoUploadDirectory:(NSString *)autoUploadDirectory;

+ (tableMetadata *)insertTypeFileIconName:(tableMetadata *)metadata serverUrl:(NSString *)serverUrl autoUploadFileName:(NSString *)autoUploadFileName autoUploadDirectory:(NSString *)autoUploadDirectory;

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
