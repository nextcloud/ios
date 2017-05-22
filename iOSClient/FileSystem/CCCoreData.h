//
//  CCCoreData.h
//  Crypto Cloud Technology Nextcloud
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
#import <CoreData/CoreData.h>

#import <Photos/Photos.h>
#import <MagicalRecord/MagicalRecord.h>

#import "OCSharedDto.h"
#import "CCUtility.h"
#import "CCGraphics.h"
#import "OCUserProfile.h"
#import "OCActivity.h"
#import "OCExternalSites.h"
#import "OCCapabilities.h"
#import "TableAccount+CoreDataClass.h"
#import "TableCertificates+CoreDataClass.h"
#import "TableDirectory+CoreDataClass.h"
#import "TableLocalFile+CoreDataClass.h"

@class tableMetadata;

@interface CCCoreData : NSObject

// ===== Account =====

+ (NSArray *)getAllAccount;

// ===== Metadata =====

/*
//+ (void)addMetadata:(tableMetadata *)metadata activeAccount:(NSString *)activeAccount activeUrl:(NSString *)activeUrl context:(NSManagedObjectContext *)context;
+ (void)deleteMetadataWithPredicate:(NSPredicate *)predicate;
+ (void)moveMetadata:(NSString *)fileName directoryID:(NSString *)directoryID directoryIDTo:(NSString *)directoryIDTo activeAccount:(NSString *)activeAccount;
+ (void)updateMetadata:(tableMetadata *)metadata predicate:(NSPredicate *)predicate activeAccount:(NSString *)activeAccount activeUrl:(NSString *)activeUrl context:(NSManagedObjectContext *)context;
+ (void)setMetadataSession:(NSString *)session sessionError:(NSString *)sessionError sessionSelector:(NSString *)sessionSelector sessionSelectorPost:(NSString *)sessionSelectorPost sessionTaskIdentifier:(NSInteger)sessionTaskIdentifier sessionTaskIdentifierPlist:(NSInteger)sessionTaskIdentifierPlist predicate:(NSPredicate *)predicate context:(NSManagedObjectContext *)context;
+ (void)setMetadataFavoriteFileID:(NSString *)fileID favorite:(BOOL)favorite activeAccount:(NSString *)activeAccount context:(NSManagedObjectContext *)context;

+ (TableMetadata *)getTableMetadataWithPreficate:(NSPredicate *)predicate;
+ (NSArray *)getTableMetadataWithPredicate:(NSPredicate *)predicate context:(NSManagedObjectContext *)context;
+ (NSArray *)getTableMetadataWithPredicate:(NSPredicate *)predicate fieldOrder:(NSString *)fieldOrder ascending:(BOOL)ascending;
+ (tableMetadata *)getMetadataWithPreficate:(NSPredicate *)predicate context:(NSManagedObjectContext *)context;
+ (tableMetadata *)getMetadataAtIndex:(NSPredicate *)predicate fieldOrder:(NSString *)fieldOrder ascending:(BOOL)ascending objectAtIndex:(NSUInteger)index;
+ (tableMetadata *)getMetadataFromFileName:(NSString *)fileName directoryID:(NSString *)directoryID activeAccount:(NSString *)activeAccount context:(NSManagedObjectContext *)context;

+ (NSArray *)getTableMetadataDownloadAccount:(NSString *)activeAccount;
+ (NSArray *)getTableMetadataDownloadWWanAccount:(NSString *)activeAccount;
+ (NSArray *)getTableMetadataUploadAccount:(NSString *)activeAccount;
+ (NSArray *)getTableMetadataUploadWWanAccount:(NSString *)activeAccount;

+ (NSArray *)getRecordsTableMetadataPhotosCameraUpload:(NSString *)serverUrl activeAccount:(NSString *)activeAccount;

+ (void)removeOfflineAllFileFromServerUrl:(NSString *)serverUrl activeAccount:(NSString *)activeAccount;
*/

// ===== Directory =====

/*
+ (NSString *)addDirectory:(NSString *)serverUrl permissions:(NSString *)permissions activeAccount:(NSString *)activeAccount;
+ (void)updateDirectoryEtagServerUrl:(NSString *)serverUrl fileID:(NSString *)fileID activeAccount:(NSString *)activeAccount;
+ (void)deleteDirectoryFromPredicate:(NSPredicate *)predicate;
+ (NSArray *)deleteDirectoryAndSubDirectory:(NSString *)serverUrl activeAccount:(NSString *)activeAccount;
+ (void)renameDirectory:(NSString *)serverUrl serverUrlTo:(NSString *)serverUrlTo activeAccount:(NSString *)activeAccount;

+ (void)setDateReadDirectoryID:(NSString *)directoryID activeAccount:(NSString *)activeAccount;
+ (NSDate *)getDateReadDirectoryID:(NSString *)directoryID activeAccount:(NSString *)activeAccount;

+ (void)setDirectoryRev:(NSString *)rev serverUrl:(NSString *)serverUrl activeAccount:(NSString *)activeAccount;
+ (NSString *)getDirectoryRevFromServerUrl:(NSString *)serverUrl activeAccount:(NSString *)activeAccount;

+ (TableDirectory *)getTableDirectoryWithPreficate:(NSPredicate *)predicate;
+ (NSArray *)getDirectoryIDsFromBeginsWithServerUrl:(NSString *)serverUrl activeAccount:(NSString *)activeAccount;
+ (NSString *)getDirectoryIDFromServerUrl:(NSString *)serverUrl activeAccount:(NSString *)activeAccount;
+ (NSString *)getServerUrlFromDirectoryID:(NSString *)directoryID activeAccount:(NSString *)activeAccount;

+ (void)clearDateReadAccount:(NSString *)activeAccount serverUrl:(NSString *)serverUrl directoryID:(NSString *)directoryID;
+ (void)clearAllDateReadDirectory;

+ (BOOL)isDirectoryOutOfDate:(int)numAddDay directoryID:(NSString *)directoryID activeAccount:(NSString *)activeAccount;

+ (void)removeOfflineDirectoryID:(NSString *)directoryID activeAccount:(NSString *)activeAccount;
+ (NSArray *)getOfflineDirectoryActiveAccount:(NSString *)activeAccount;
+ (void)setOfflineDirectoryServerUrl:(NSString *)serverUrl offline:(BOOL)offline activeAccount:(NSString *)activeAccount;
+ (BOOL)isOfflineDirectoryServerUrl:(NSString *)serverUrl activeAccount:(NSString *)activeAccount;

+ (BOOL)setDirectoryLock:(NSString *)serverUrl activeAccount:(NSString *)activeAccount;
+ (BOOL)setDirectoryUnLock:(NSString *)serverUrl activeAccount:(NSString *)activeAccount;
+ (void)setAllDirectoryUnLockForAccount:(NSString *)activeAccount;
+ (BOOL)isDirectoryLock:(NSString *)serverUrl activeAccount:(NSString *)activeAccount;
+ (BOOL)isBlockZone:(NSString *)serverUrl activeAccount:(NSString *)activeAccount;
*/

// ===== LocalFile =====
/*
+ (void)addLocalFile:(tableMetadata *)metadata activeAccount:(NSString *)activeAccount;
+ (void)deleteLocalFileWithPredicate:(NSPredicate *)predicate;

+ (void)renameLocalFileWithEtag:(NSString *)fileID fileNameTo:(NSString *)fileNameTo fileNamePrintTo:(NSString *)fileNamePrintTo activeAccount:(NSString *)activeAccount;
+ (void)updateLocalFileModel:(tableMetadata *)metadata activeAccount:(NSString *)activeAccount;

+ (TableLocalFile *)getLocalFileWithEtag:(NSString *)fileID activeAccount:(NSString *)activeAccount;
+ (NSArray *)getTableLocalFileWithPredicate:(NSPredicate *)predicate;

// ===== Offline LocalFile =====

+ (void)setOfflineLocalEtag:(NSString *)fileID offline:(BOOL)offline activeAccount:(NSString *)activeAccount;
+ (BOOL)isOfflineLocalEtag:(NSString *)fileID activeAccount:(NSString *)activeAccount;
+ (NSArray *)getOfflineLocalFileActiveAccount:(NSString *)activeAccount directoryUser:(NSString *)directoryUser;
*/

// ===== GeoInformation =====

+ (NSArray *)getGeoInformationLocalFromEtag:(NSString *)fileID activeAccount:(NSString *)activeAccount;
+ (void)setGeoInformationLocalFromEtag:(NSString *)fileID exifDate:(NSDate *)exifDate exifLatitude:(NSString *)exifLatitude exifLongitude:(NSString *)exifLongitude activeAccount:(NSString *)activeAccount;
+ (void)setGeoInformationLocalNull;

// ===== Certificates =====

+ (NSMutableArray *)getAllCertificatesLocationOldDB;


// ===== File System =====

+ (BOOL)downloadFile:(tableMetadata *)metadata directoryUser:(NSString *)directoryUser activeAccount:(NSString *)activeAccount;
+ (void)downloadFilePlist:(tableMetadata *)metadata activeAccount:(NSString *)activeAccount activeUrl:(NSString *)activeUrl directoryUser:(NSString *)directoryUser;
+ (void)deleteFile:(tableMetadata *)metadata serverUrl:(NSString *)serverUrl directoryUser:(NSString *)directoryUser activeAccount:(NSString *)activeAccount;

// ===== Utility Database =====

+ (void)moveCoreDataToGroup;
+ (void)moveAllUserToGroup;

//+ (void)flushTableAccount:(NSString *)account;
//+ (void)flushTableDirectoryAccount:(NSString *)account;
+ (void)flushTableLocalFileAccount:(NSString *)account;

+ (void)flushAllDatabase;
@end
