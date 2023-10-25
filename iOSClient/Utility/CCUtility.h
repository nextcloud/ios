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
#import <Photos/Photos.h>
#import <PDFKit/PDFKit.h>

@class tableMetadata;

@interface CCUtility : NSObject

+ (BOOL)addSkipBackupAttributeToItemAtURL:(NSURL *)URL;

+ (NSString *)dateDiff:(NSDate *)convertedDate;
+ (NSString *)transformedSize:(int64_t)value;

+ (NSString *)removeForbiddenCharactersServer:(NSString *)fileName;
+ (NSString *)removeForbiddenCharactersFileSystem:(NSString *)fileName;

+ (NSString *)stringAppendServerUrl:(NSString *)serverUrl addFileName:(NSString *)addFileName;

+ (NSString *)createFileNameDate:(NSString *)fileName extension:(NSString *)extension;
+ (NSString *)createFileName:(NSString *)fileName fileDate:(NSDate *)fileDate fileType:(PHAssetMediaType)fileType keyFileName:(NSString *)keyFileName keyFileNameType:(NSString *)keyFileNameType keyFileNameOriginal:(NSString *)keyFileNameOriginal forcedNewFileName:(BOOL)forcedNewFileName;

+ (void)createDirectoryStandard;

+ (NSString *)getDirectoryProviderStorageIconOcId:(NSString *)ocId etag:(NSString *)etag;
+ (NSString *)getDirectoryProviderStoragePreviewOcId:(NSString *)ocId etag:(NSString *)etag;
+ (BOOL)fileProviderStorageExists:(tableMetadata *)metadata;
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

+ (NSString *)returnPathfromServerUrl:(NSString *)serverUrl urlBase:(NSString *)urlBase userId:(NSString *)userId account:(NSString *)account;
+ (NSString *)returnFileNamePathFromFileName:(NSString *)metadataFileName serverUrl:(NSString *)serverUrl urlBase:(NSString *)urlBase userId:(NSString *)userId account:(NSString *)account;

+ (NSString *)getDirectoryScan;

+ (NSString *)getMimeType:(NSString *)fileNameView;

// ===== Share Permissions =====

+ (NSInteger)getPermissionsValueByCanEdit:(BOOL)canEdit andCanCreate:(BOOL)canCreate andCanChange:(BOOL)canChange andCanDelete:(BOOL)canDelete andCanShare:(BOOL)canShare andIsFolder:(BOOL) isFolder;
+ (BOOL)isPermissionToCanCreate:(NSInteger) permissionValue;
+ (BOOL)isPermissionToCanChange:(NSInteger) permissionValue;
+ (BOOL)isPermissionToCanDelete:(NSInteger) permissionValue;
+ (BOOL)isPermissionToCanShare:(NSInteger) permissionValue;
+ (BOOL)isAnyPermissionToEdit:(NSInteger) permissionValue;
+ (BOOL)isPermissionToRead:(NSInteger) permissionValue;
+ (BOOL)isPermissionToReadCreateUpdate:(NSInteger) permissionValue;

// ===== Third parts =====

+ (NSString *)getExtension:(NSString*)fileName;
+ (NSDate *)datetimeWithOutTime:(NSDate *)datDate;
+ (NSString *)valueForKey:(NSString *)key fromQueryItems:(NSArray *)queryItems;
+ (NSDate *)getATime:(const char *)path;

@end
