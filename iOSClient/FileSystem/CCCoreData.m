//
//  CCCoreData.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 02/02/16.
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

#import "CCCoreData.h"

#import "CCNetworking.h"

@implementation CCCoreData

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Account =====
#pragma --------------------------------------------------------------------------------------------

+ (void)addAccount:(NSString *)account url:(NSString *)url user:(NSString *)user password:(NSString *)password uid:(NSString*)uid typeCloud:(NSString *)typeCloud
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    
    TableAccount *record = [TableAccount MR_createEntityInContext:context];
        
    record.account = account;
    record.active = [NSNumber numberWithBool:NO];
        
    record.cameraUpload = [NSNumber numberWithBool:NO];
    record.cameraUploadPhoto = [NSNumber numberWithBool:NO];
    record.cameraUploadVideo = [NSNumber numberWithBool:NO];
        
    record.cameraUploadCryptatedPhoto = [NSNumber numberWithBool:NO];
    record.cameraUploadCryptatedVideo = [NSNumber numberWithBool:NO];
        
    record.cameraUploadWWAnPhoto = [NSNumber numberWithBool:NO];
    record.cameraUploadWWAnVideo = [NSNumber numberWithBool:NO];
        
    record.dateRecord = [NSDate date];
    record.optimization = [NSDate date];
    record.password = password;
    record.typeCloud = typeCloud;
    record.uid = uid;
    record.url = url;
    record.user = user;
    
    [context MR_saveToPersistentStoreAndWait];
}

+ (void)updateAccount:(NSString *)account withPassword:(NSString *)password
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    
    TableAccount *record = [TableAccount MR_findFirstByAttribute:@"account" withValue:account inContext:context];
    
    record.password = password;
    
    [context MR_saveToPersistentStoreAndWait];
}

+ (void)deleteAccount:(NSString *)account
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];

    TableAccount *record = [TableAccount MR_findFirstByAttribute:@"account" withValue:account inContext:context];
    [record MR_deleteEntityInContext:context];
    
    [context MR_saveToPersistentStoreAndWait];
}

+ (TableAccount *)setActiveAccount:(NSString *)account
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];

    TableAccount *recordAccount = nil;
    
    NSArray *records = [TableAccount MR_findAllInContext:context];
    
    for (TableAccount *record in records) {
        
        if ([record.account isEqualToString:account]) {
            
            record.active = [NSNumber numberWithBool:YES];
            recordAccount = record;
            
        } else {
            
            record.active = [NSNumber numberWithBool:NO];
        }
    }
    
    [context MR_saveToPersistentStoreAndWait];
        
    return [self getActiveAccount];
}

+ (TableAccount *)setActiveFirstAccountNextcloudOwncloud
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    
    /*** NEXTCLOUD OWNCLOUD ***/
    
    TableAccount *record = [TableAccount MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"(typeCloud == %@) OR (typeCloud == %@)", typeCloudNextcloud, typeCloudOwnCloud] inContext:context];
    
    if (record)
        return [self setActiveAccount:record.account];
    
    return nil;
}

+ (NSArray *)getAllAccount
{
    NSMutableArray *accounts = [[NSMutableArray alloc] init];
    NSArray *records;
    
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    
#ifdef CC
    records = [TableAccount MR_findAllInContext:context];
#endif
    
#ifdef NC
    
    /*** NEXTCLOUD OWNCLOUD ***/
    
    records = [TableAccount MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"(typeCloud == %@) OR (typeCloud == %@)", typeCloudNextcloud, typeCloudOwnCloud] inContext:context];
#endif
    
    for (TableAccount *tableAccount in records)
        [accounts addObject:tableAccount.account];
    
    return accounts;
}

+ (TableAccount *)getTableAccountFromAccount:(NSString *)account
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];

    return [TableAccount MR_findFirstByAttribute:@"account" withValue:account inContext:context];
}

+ (NSArray *)getAllTableAccount
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];

    NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"account" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
    NSArray *records;
    
#ifdef CC
    records = [TableAccount MR_findAllInContext:context];
#endif
    
#ifdef NC
    
    /*** NEXTCLOUD OWNCLOUD ***/
    
    records = [TableAccount MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"(typeCloud == %@) OR (typeCloud == %@)", typeCloudNextcloud, typeCloudOwnCloud] inContext:context];
#endif
    
    records = [NSMutableArray arrayWithArray:[records sortedArrayUsingDescriptors:[[NSArray alloc] initWithObjects:descriptor, nil]]];
    
    return records;
}

+ (TableAccount *)getActiveAccount
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];

    TableAccount *record = [TableAccount MR_findFirstByAttribute:@"active" withValue:[NSNumber numberWithBool:YES] inContext:context];
    
#ifdef NC
    
    /*** NEXTCLOUD OWNCLOUD ***/
    
    if ([record.typeCloud isEqualToString:typeCloudNextcloud] == NO && [record.typeCloud isEqualToString:typeCloudOwnCloud] == NO)
        return [self setActiveFirstAccountNextcloudOwncloud];
#endif
    
    if (record) return record;
    else return nil;
}

+ (NSString *)getTokenActiveAccount:(NSString *)activeAccount
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];

    TableAccount *record = [TableAccount MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@)", activeAccount] inContext:context];
    
    if (record) return record.token;
    else return nil;
}

+ (void)setTokenAccount:(NSString *)token activeAccount:(NSString *)activeAccount
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
    TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate inContext:context];
    
    if (record) {
        
        record.token = token;
        
        [context MR_saveToPersistentStoreAndWait];
    }
}

+ (NSString *)getCameraUploadFolderNameActiveAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
    TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate];
    
    if (record) {
        
        if ([record.cameraUploadFolderName length] > 0 ) return record.cameraUploadFolderName;
        else return folderDefaultCameraUpload;
        
    } else return @"";
}

+ (NSString *)getCameraUploadFolderPathActiveAccount:(NSString *)activeAccount activeUrl:(NSString *)activeUrl typeCloud:(NSString *)typeCloud
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
    TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate];
    
    if (record) {
        
        if ([record.cameraUploadFolderPath length] > 0 ) return record.cameraUploadFolderPath;
        else return [CCUtility getHomeServerUrlActiveUrl:activeUrl typeCloud:typeCloud];
        
    } else return @"";
}

+ (NSString *)getCameraUploadFolderNamePathActiveAccount:(NSString *)activeAccount activeUrl:(NSString *)activeUrl typeCloud:(NSString *)typeCloud
{
    NSString *cameraFolderName = [self getCameraUploadFolderNameActiveAccount:activeAccount];
    NSString *cameraFolderPath = [self getCameraUploadFolderPathActiveAccount:activeAccount activeUrl:activeUrl typeCloud:typeCloud];
    
    NSString *result = [CCUtility stringAppendServerUrl:cameraFolderPath addServerUrl:cameraFolderName];
    return result;
}

+ (BOOL)getCameraUploadActiveAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
    TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate];
    
    if (record) return [record.cameraUpload boolValue];
    else return NO;
}

+ (BOOL)getCameraUploadBackgroundActiveAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
    TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate];
    
    if (record) return [record.cameraUploadBackground boolValue];
    else return NO;
}

+ (BOOL)getCameraUploadCreateSubfolderActiveAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
    TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate];
    
    if (record) return [record.cameraUploadCreateSubfolder boolValue];
    else return NO;
}

+ (BOOL)getCameraUploadFullPhotosActiveAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
    TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate];
    
    if (record) return [record.cameraUploadFull boolValue];
    else return NO;
}

+ (BOOL)getCameraUploadPhotoActiveAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
    TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate];
    
    if (record) return [record.cameraUploadPhoto boolValue];
    else return NO;
}

+ (BOOL)getCameraUploadVideoActiveAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
    TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate];
    
    if (record) return [record.cameraUploadVideo boolValue];
    else return NO;
}

+ (NSDate *)getCameraUploadDatePhotoActiveAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
    TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate];
    
    if (record) return record.cameraUploadDatePhoto;
    else return nil;
}

+ (NSDate *)getCameraUploadDateVideoActiveAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
    TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate];
    
    if (record) return record.cameraUploadDateVideo;
    else return nil;
}

+ (BOOL)getCameraUploadCryptatedPhotoActiveAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
    TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate];
    
    if (record) return [record.cameraUploadCryptatedPhoto boolValue];
    else return NO;
}

+ (BOOL)getCameraUploadCryptatedVideoActiveAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
    TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate];
    
    if (record) return [record.cameraUploadCryptatedVideo boolValue];
    else return NO;
}

+ (BOOL)getCameraUploadWWanPhotoActiveAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
    TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate];
    
    if (record) return [record.cameraUploadWWAnPhoto boolValue];
    else return NO;
}

+ (BOOL)getCameraUploadWWanVideoActiveAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
    TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate];
    
    if (record) return [record.cameraUploadWWAnVideo boolValue];
    else return NO;
}

+ (BOOL)getCameraUploadSaveAlbumActiveAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
    TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate];
    
    if (record) return [record.cameraUploadSaveAlbum boolValue];
    else return NO;
}

+ (void)setCameraUpload:(BOOL)state activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
        TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate inContext:localContext];
    
        if (record)
            record.cameraUpload = [NSNumber numberWithBool:state];
    }];
}

+ (void)setCameraUploadBackground:(BOOL)state activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
        TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate inContext:localContext];
    
        if (record)
            record.cameraUploadBackground = [NSNumber numberWithBool:state];
    }];
}

+ (void)setCameraUploadCreateSubfolderActiveAccount:(BOOL)state activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
        TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate inContext:localContext];
        
        if (record)
            record.cameraUploadCreateSubfolder = [NSNumber numberWithBool:state];
    }];
}

+ (void)setCameraUploadFullPhotosActiveAccount:(BOOL)state activeAccount:(NSString *)activeAccount
{
     [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
     
         NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
         TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate inContext:localContext];
     
         if (record)
             record.cameraUploadFull = [NSNumber numberWithBool:state];
     }];
}

+ (void)setCameraUploadPhoto:(BOOL)state activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
        TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate inContext:localContext];
    
        if (record)
            record.cameraUploadPhoto = [NSNumber numberWithBool:state];
    }];
}

+ (void)setCameraUploadVideo:(BOOL)video activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
        TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate inContext:localContext];
    
        if (record)
            record.cameraUploadVideo = [NSNumber numberWithBool:video];
    }];
}

+ (void)setCameraUploadDatePhoto:(NSDate *)date
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];

    NSArray *records = [TableAccount MR_findAllInContext:context];
    
    for (TableAccount *record in records)
        record.cameraUploadDatePhoto = date;
    
    [context MR_saveToPersistentStoreAndWait];
}

+ (void)setCameraUploadDateVideo:(NSDate *)date
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];

    NSArray *records = [TableAccount MR_findAllInContext:context];
    
    for (TableAccount *record in records)
        record.cameraUploadDateVideo = date;
    
    [context MR_saveToPersistentStoreAndWait];
}

+ (void)setCameraUploadDateAssetType:(PHAssetMediaType)assetMediaType assetDate:(NSDate *)assetDate activeAccount:(NSString *)activeAccount
{
    if (assetMediaType == PHAssetMediaTypeImage && [assetDate compare:[self getCameraUploadDatePhotoActiveAccount:activeAccount]] ==  NSOrderedDescending && assetDate) {
        [self setCameraUploadDatePhoto:assetDate];
    }
    
    if (assetMediaType == PHAssetMediaTypeVideo && [assetDate compare:[self getCameraUploadDateVideoActiveAccount:activeAccount]] ==  NSOrderedDescending && assetDate) {
        [self setCameraUploadDateVideo:assetDate];
    }
}

+ (void)setCameraUploadCryptatedPhoto:(BOOL)cryptated activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
        TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate inContext:localContext];
    
        if (record)
            record.cameraUploadCryptatedPhoto = [NSNumber numberWithBool:cryptated];
    }];
}

+ (void)setCameraUploadCryptatedVideo:(BOOL)cryptated activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
        TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate inContext:localContext];
    
        if (record)
            record.cameraUploadCryptatedVideo = [NSNumber numberWithBool:cryptated];
    }];
}

+ (void)setCameraUploadWWanPhoto:(BOOL)wWan activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
        TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate inContext:localContext];
    
        if (record)
            record.cameraUploadWWAnPhoto = [NSNumber numberWithBool:wWan];
    }];
}

+ (void)setCameraUploadWWanVideo:(BOOL)wWan activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
        TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate inContext:localContext];
    
        if (record)
            record.cameraUploadWWAnVideo = [NSNumber numberWithBool:wWan];
    }];
}

+ (void)setCameraUploadFolderName:(NSString *)fileName activeAccount:(NSString *)activeAccount
{
    if (fileName == nil)
        fileName = [self getCameraUploadFolderNameActiveAccount:activeAccount];
    
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
        TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate inContext:localContext];
    
        if (record)
            record.cameraUploadFolderName = fileName;
    }];
}

+ (void)setCameraUploadFolderPath:(NSString *)pathName activeUrl:(NSString *)activeUrl typeCloud:(NSString *)typeCloud activeAccount:(NSString *)activeAccount
{
    if (pathName == nil)
        pathName = [self getCameraUploadFolderPathActiveAccount:activeAccount activeUrl:activeUrl typeCloud:typeCloud];
    
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
        TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate inContext:localContext];
    
        if (record)
            record.cameraUploadFolderPath = pathName;
    }];
}

+ (void)setCameraUploadSaveAlbum:(BOOL)saveAlbum activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
        TableAccount *record = [TableAccount MR_findFirstWithPredicate:predicate inContext:localContext];
    
        if (record)
            record.cameraUploadSaveAlbum = [NSNumber numberWithBool:saveAlbum];
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Certificates =====
#pragma --------------------------------------------------------------------------------------------

+ (void)addCertificate:(NSString *)certificateLocation
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    
    TableCertificates *record = [TableCertificates MR_createEntityInContext:context];
    
    record.dateRecord = [NSDate date];
    record.certificateLocation = certificateLocation;
    
    [context MR_saveToPersistentStoreAndWait];
}

+ (NSMutableArray *)getAllCertificatesLocation
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    NSString *localCertificatesFolder = [CCUtility getDirectoryCerificates];
    NSMutableArray *output = [NSMutableArray new];
    
    NSArray *records = [TableCertificates MR_findAllInContext:context];
    
    for (TableCertificates *record in records) {
        
        NSString *certificatePath = [NSString stringWithFormat:@"%@%@", localCertificatesFolder, record.certificateLocation];
        [output addObject:certificatePath];
    }
    
    return output;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Metadata =====
#pragma --------------------------------------------------------------------------------------------

+ (void)addMetadata:(CCMetadata *)metadata activeAccount:(NSString *)activeAccount activeUrl:(NSString *)activeUrl typeCloud:(NSString *)typeCloud context:(NSManagedObjectContext *)context
{
    if (context == nil)
        context = [NSManagedObjectContext MR_context];

    // remove all fileID (BUG 2.10)
    [TableMetadata MR_deleteAllMatchingPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (fileID == %@)", activeAccount, metadata.fileID] inContext:context];
    [context MR_saveToPersistentStoreAndWait];
    
    // create new record Metadata
    TableMetadata *record = [TableMetadata MR_createEntityInContext:context];

    // set default value
    metadata.sessionTaskIdentifier = taskIdentifierDone;
    metadata.sessionTaskIdentifierPlist = taskIdentifierDone;
    [record setValue:[NSDate date] forKey:@"dateRecord"];

    // Insert metdata -> entity
    [self insertMetadataInEntity:metadata recordMetadata:record activeAccount:activeAccount activeUrl:activeUrl typeCloud:typeCloud];
    
    // Aggiorniamo la data nella directory (ottimizzazione v 2.10)
    [self setDateReadDirectoryID:metadata.directoryID activeAccount:activeAccount];
    
    [context MR_saveToPersistentStoreAndWait];
}

+ (void)deleteMetadataWithPredicate:(NSPredicate *)predicate
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
            
        NSString *directoryID;
        NSArray *records = [TableMetadata MR_findAllWithPredicate:predicate inContext:localContext];
            
        for(TableMetadata *record in records) {
            
            // Aggiorniamo la data nella directory (ottimizzazione v 2.10)
            if ([directoryID isEqualToString:record.directoryID] == NO)
                [self setDateReadDirectoryID:record.directoryID activeAccount:record.account];
                
            directoryID = record.directoryID;
            
            [record MR_deleteEntityInContext:localContext];
        }
    }];
}

+ (void)moveMetadata:(NSString *)fileName directoryID:(NSString *)directoryID directoryIDTo:(NSString *)directoryIDTo activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (fileName == %@) AND (directoryID == %@)", activeAccount, fileName, directoryID];
        TableMetadata *record = [TableMetadata MR_findFirstWithPredicate:predicate inContext:localContext];
        
        if (record) {
            
            record.directoryID = directoryIDTo;
            
            // Aggiorniamo la data nella directory (ottimizzazione v 2.10)
            [self setDateReadDirectoryID:directoryID activeAccount:activeAccount];
            [self setDateReadDirectoryID:directoryIDTo activeAccount:activeAccount];
        }
    }];
}

+ (void)updateMetadata:(CCMetadata *)metadata predicate:(NSPredicate *)predicate activeAccount:(NSString *)activeAccount activeUrl:(NSString *)activeUrl typeCloud:(NSString *)typeCloud context:(NSManagedObjectContext *)context
{
    TableMetadata *record;
    
    if (context == nil)
        context = [NSManagedObjectContext MR_defaultContext];
    
    record = [TableMetadata MR_findFirstWithPredicate:predicate inContext:context];
    
    if (record) {
        
        [self insertMetadataInEntity:metadata recordMetadata:record activeAccount:activeAccount activeUrl:activeUrl typeCloud:typeCloud];
        
        // Aggiorniamo la data nella directory (ottimizzazione v 2.10)
        [self setDateReadDirectoryID:metadata.directoryID activeAccount:activeAccount];
        
        [context MR_saveToPersistentStoreAndWait];
    }
}

+ (void)setMetadataSession:(NSString *)session sessionError:(NSString *)sessionError sessionSelector:(NSString *)sessionSelector sessionSelectorPost:(NSString *)sessionSelectorPost sessionTaskIdentifier:(NSInteger)sessionTaskIdentifier sessionTaskIdentifierPlist:(NSInteger)sessionTaskIdentifierPlist predicate:(NSPredicate *)predicate context:(NSManagedObjectContext *)context
{
    if (context == nil)
        context = [NSManagedObjectContext MR_defaultContext];
    
    NSArray *records = [TableMetadata MR_findAllWithPredicate:predicate inContext:context];
    NSMutableSet *directoryIDs = [[NSMutableSet alloc] init];
    NSString *directoryID;
    
    for(TableMetadata *record in records) {
                
        if (session) record.session = session;
        if (sessionError) record.sessionError = sessionError;
        if (sessionSelector) record.sessionSelector = sessionSelector;
        if (sessionSelectorPost) record.sessionSelectorPost = sessionSelectorPost;
        if (sessionTaskIdentifier != taskIdentifierNULL) record.sessionTaskIdentifier = [NSNumber numberWithInteger:sessionTaskIdentifier];
        if (sessionTaskIdentifierPlist != taskIdentifierNULL) record.sessionTaskIdentifierPlist = [NSNumber numberWithInteger:sessionTaskIdentifierPlist];
        
        [directoryIDs addObject:record.directoryID];
        
        // Aggiorniamo la data nella directory (ottimizzazione v 2.10)
        if ([directoryID isEqualToString:record.directoryID] == NO)
            [self setDateReadDirectoryID:record.directoryID activeAccount:record.account];
        
        directoryID = record.directoryID;
    }
    
    [context MR_saveToPersistentStoreAndWait];
}

+ (CCMetadata *)getMetadataWithPreficate:(NSPredicate *)predicate context:(NSManagedObjectContext *)context
{
    if (context == nil)
        context = [NSManagedObjectContext MR_defaultContext];
    
    TableMetadata *record;
    
    record = [TableMetadata MR_findFirstWithPredicate:predicate inContext:context];
    
    if (record) {
        
        return [self insertEntityInMetadata:record];
        
    } else return nil;
}

+ (NSArray *)getTableMetadataWithPredicate:(NSPredicate *)predicate context:(NSManagedObjectContext *)context
{
    if (context == nil)
        context = [NSManagedObjectContext MR_defaultContext];
    
    return [TableMetadata MR_findAllWithPredicate:predicate inContext:context];
}

+ (NSArray *)getTableMetadataWithPredicate:(NSPredicate *)predicate fieldOrder:(NSString *)fieldOrder ascending:(BOOL)ascending
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    NSArray *records = [[NSArray alloc] init];
    NSSortDescriptor *descriptor;
    
    records = [TableMetadata MR_findAllWithPredicate:predicate inContext:context];
        
    if ([records count] == 0) return nil;
    
    if ([fieldOrder isEqualToString:@"fileName"]) descriptor = [[NSSortDescriptor alloc] initWithKey:@"fileNamePrint" ascending:ascending selector:@selector(localizedCaseInsensitiveCompare:)];
    
    else if ([fieldOrder isEqualToString:@"fileDate"]) descriptor = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:ascending selector:nil];
    
    else if ([fieldOrder isEqualToString:@"sessionTaskIdentifier"]) descriptor = [[NSSortDescriptor alloc] initWithKey:@"sessionTaskIdentifier" ascending:ascending selector:nil];
        
    else descriptor = [[NSSortDescriptor alloc] initWithKey:fieldOrder ascending:ascending selector:@selector(localizedCaseInsensitiveCompare:)];
    
    return [records sortedArrayUsingDescriptors:[NSArray arrayWithObjects:descriptor, nil]];
}

+ (CCMetadata *)getMetadataAtIndex:(NSPredicate *)predicate fieldOrder:(NSString *)fieldOrder ascending:(BOOL)ascending objectAtIndex:(NSUInteger)index
{
    NSArray *records = [self getTableMetadataWithPredicate:predicate fieldOrder:fieldOrder ascending:ascending];
    
    TableMetadata *record = [records objectAtIndex:index];
    
    return [self insertEntityInMetadata:record];
}

+ (CCMetadata *)getMetadataFromFileName:(NSString *)fileName directoryID:(NSString *)directoryID activeAccount:(NSString *)activeAccount context:(NSManagedObjectContext *)context
{
    if (fileName == nil || directoryID == nil || activeAccount == nil)
        return nil;
    
    if (context == nil)
        context = [NSManagedObjectContext MR_defaultContext];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@) AND ((fileName == %@) OR (fileNameData == %@))", activeAccount, directoryID, fileName, fileName];

    TableMetadata *record = [TableMetadata MR_findFirstWithPredicate:predicate inContext:context];
    
    if (record) return [self insertEntityInMetadata:record];
    else return nil;
}

+ (NSArray *)getTableMetadataDownloadAccount:(NSString *)activeAccount
{
    return [self getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND ((session == %@) || (session == %@)) AND ((sessionTaskIdentifier != %i) OR (sessionTaskIdentifierPlist != %i))", activeAccount, download_session, download_session_foreground, taskIdentifierDone, taskIdentifierDone] context:nil];
}

+ (NSArray *)getTableMetadataDownloadWWanAccount:(NSString *)activeAccount
{
    return [self getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (session == %@) AND ((sessionTaskIdentifier != %i) OR (sessionTaskIdentifierPlist != %i))", activeAccount, download_session_wwan, taskIdentifierDone, taskIdentifierDone] context:nil];
}

+ (NSArray *)getTableMetadataUploadAccount:(NSString *)activeAccount
{
    return [self getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND ((session == %@) || (session == %@)) AND ((sessionTaskIdentifier != %i) OR (sessionTaskIdentifierPlist != %i))", activeAccount, upload_session, upload_session_foreground, taskIdentifierDone, taskIdentifierDone] context:nil];
}

+ (NSArray *)getTableMetadataUploadWWanAccount:(NSString *)activeAccount
{
    return [self getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (session == %@) AND ((sessionTaskIdentifier != %i) OR (sessionTaskIdentifierPlist != %i))", activeAccount, upload_session_wwan, taskIdentifierDone, taskIdentifierDone] context:nil];
}

+ (void)changeRevFileIDDB:(NSString *)revFileID revTo:(NSString *)revTo activeAccount:(NSString *)activeAccount
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    NSPredicate *predicate;
    
    // Metadata
    predicate = [NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", revFileID, activeAccount];
    TableMetadata *recordMetadata = [TableMetadata MR_findFirstWithPredicate:predicate inContext:context];
    
    if (recordMetadata) {
        
        TableMetadata *localRecord = [recordMetadata MR_inContext:context];
            
        localRecord.fileID = revTo;
        localRecord.rev = revTo;
        
        // Aggiorniamo la data nella directory (ottimizzazione v 2.10)
        [self setDateReadDirectoryID:recordMetadata.directoryID activeAccount:activeAccount];
        
        [context MR_saveToPersistentStoreAndWait];
    }
    
    // File
    predicate = [NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", revFileID, activeAccount];
    TableLocalFile *recordLocalFile = [TableLocalFile MR_findFirstWithPredicate:predicate inContext:context];
    
    if (recordLocalFile) {
        
        TableLocalFile *localRecord = [recordLocalFile MR_inContext:context];
            
        localRecord.fileID = revTo;
        localRecord.rev = revTo;
        
        [context MR_saveToPersistentStoreAndWait];
    }
}

+ (NSArray *)getRecordsTableMetadataPhotosCameraUpload:(NSString *)serverUrl activeAccount:(NSString *)activeAccount
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    
    NSMutableArray *recordsPhotosCameraUpload = [[NSMutableArray alloc] init];
    NSArray *tableDirectoryes = [self getDirectoryIDsFromBeginsWithServerUrl:serverUrl activeAccount:activeAccount];
    
    for (TableDirectory *record in tableDirectoryes) {
        
        NSArray *records = [TableMetadata MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@) AND ((session == NULL) OR (session == '')) AND (type == 'file') AND ((typeFile == %@) OR (typeFile == %@))", activeAccount, record.directoryID, metadataTypeFile_image, metadataTypeFile_video] inContext:context];
        
        if ([records count] > 0)
            [recordsPhotosCameraUpload addObjectsFromArray:records];
    }
    
    // test
    if ([recordsPhotosCameraUpload count] == 0) return nil;
    
    // Order
    NSString *fieldOrder = [CCUtility getOrderSettings];
    BOOL ascending = [CCUtility getAscendingSettings];
    NSSortDescriptor *descriptor;
    
    if ([fieldOrder isEqualToString:@"fileName"]) descriptor = [[NSSortDescriptor alloc] initWithKey:@"fileNamePrint" ascending:ascending selector:@selector(localizedCaseInsensitiveCompare:)];
    else if ([fieldOrder isEqualToString:@"fileDate"]) descriptor = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:ascending selector:nil];
    else if ([fieldOrder isEqualToString:@"sessionTaskIdentifier"]) descriptor = [[NSSortDescriptor alloc] initWithKey:@"sessionTaskIdentifier" ascending:ascending selector:nil];
    else descriptor = [[NSSortDescriptor alloc] initWithKey:fieldOrder ascending:ascending selector:@selector(localizedCaseInsensitiveCompare:)];
    
    return [recordsPhotosCameraUpload sortedArrayUsingDescriptors:[NSArray arrayWithObjects:descriptor, nil]];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Directory =====
#pragma --------------------------------------------------------------------------------------------

+ (NSString *)addDirectory:(NSString *)serverUrl date:(NSDate *)date permissions:(NSString *)permissions activeAccount:(NSString *)activeAccount
{
    NSString *directoryID;
    
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];

    TableDirectory *record = [TableDirectory MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"(serverUrl == %@) AND (account == %@)", serverUrl, activeAccount] inContext:context];
    
    if (record) {
     
        directoryID = record.directoryID;
        
        record.date = date;
        record.permissions = permissions;
        
    } else {
        
        TableDirectory *record = [TableDirectory MR_createEntityInContext:context];
        
        record.account = activeAccount;
        record.date = date;        
        record.dateRecord = [NSDate date];
        record.directoryID = [CCUtility createID];
        directoryID = record.directoryID;
        record.permissions = permissions;
        record.serverUrl = serverUrl;
    }
    
    [context MR_saveToPersistentStoreAndWait];

    return directoryID;
}

+ (void)deleteDirectoryFromPredicate:(NSPredicate *)predicate
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {

        [TableDirectory MR_deleteAllMatchingPredicate:predicate inContext:localContext];
    }];
}

+ (NSArray *)deleteDirectoryAndSubDirectory:(NSString *)serverUrl activeAccount:(NSString *)activeAccount
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];

    NSMutableArray *directoryIDs = [[NSMutableArray alloc] init];
    
    NSArray *tableDirectorys = [TableDirectory MR_findAllWithPredicate:predicate inContext:context];
    
    for(TableDirectory *recordDirectory in tableDirectorys) {
        
        NSLog(@"[LOG] %@", recordDirectory.serverUrl);
        
        if ([recordDirectory.serverUrl hasPrefix:serverUrl]) {
            
            // List directoryIDs removed
            [directoryIDs addObject:recordDirectory.directoryID];
            
            // remove all TableMetadata
            NSLog(@"[LOG] %@", recordDirectory.directoryID);
            
            // remove directory in Metadata come cazzo si fa a saperlo
            //[TableMetadata MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@)", activeAccount, recordDirectory.directoryID] inContext:context];
            
            NSArray *tableMetadatas = [TableMetadata MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@)", activeAccount, recordDirectory.directoryID] inContext:context];
            for(TableMetadata *recordMetadata in tableMetadatas) {
                
                // remove if in session
                if ([recordMetadata.session length] >0) {
                    if (recordMetadata.sessionTaskIdentifier >= 0)
                        [[CCNetworking sharedNetworking] settingSession:recordMetadata.session sessionTaskIdentifier:[recordMetadata.sessionTaskIdentifier integerValue] taskStatus:taskStatusCancel];
                    
                    if (recordMetadata.sessionTaskIdentifierPlist >= 0)
                        [[CCNetworking sharedNetworking] settingSession:recordMetadata.session sessionTaskIdentifier:[recordMetadata.sessionTaskIdentifierPlist integerValue] taskStatus:taskStatusCancel];

                }
                
                // remove file local
                NSLog(@"[LOG] %@", recordMetadata.fileID);
                [self deleteLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (fileID == %@)", activeAccount, recordMetadata.fileID]];
                [recordMetadata MR_deleteEntityInContext:context];
            }
            
            [recordDirectory MR_deleteEntityInContext:context];
        }
    }

    [context MR_saveToPersistentStoreAndWait];
    
    return directoryIDs;
}

+ (void)renameDirectory:(NSString *)serverUrl serverUrlTo:(NSString *)serverUrlTo activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(serverUrl == %@) AND (account == %@)", serverUrl, activeAccount];
        TableDirectory *record = [TableDirectory MR_findFirstWithPredicate:predicate inContext:localContext];
        
        if (record)
            record.serverUrl = serverUrlTo;
    }];
}

+ (void)setDateReadDirectoryID:(NSString *)directoryID activeAccount:(NSString *)activeAccount
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(directoryID == %@) AND (account == %@)", directoryID, activeAccount];
    TableDirectory *record = [TableDirectory MR_findFirstWithPredicate:predicate inContext:context];
    
    if (record) {
        
        record.dateReadDirectory = [NSDate date];
    
        [context MR_saveToPersistentStoreAndWait];        
    }
}

+ (NSDate *)getDateReadDirectoryID:(NSString *)directoryID activeAccount:(NSString *)activeAccount
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(directoryID == %@) AND (account == %@)", directoryID, activeAccount];
    TableDirectory *record = [TableDirectory MR_findFirstWithPredicate:predicate inContext:context];
    
    if (record) return record.dateReadDirectory;
    else return nil;
}

+ (void)setDirectoryRev:(NSString *)rev serverUrl:(NSString *)serverUrl activeAccount:(NSString *)activeAccount
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(serverUrl == %@) AND (account == %@)", serverUrl, activeAccount];
    TableDirectory *record = [TableDirectory MR_findFirstWithPredicate:predicate inContext:context];
    
    if (record) {
        
        record.rev = rev;
        
        [context MR_saveToPersistentStoreAndWait];
    }
}

+ (NSString *)getDirectoryRevFromServerUrl:(NSString *)serverUrl activeAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(serverUrl == %@) AND (account == %@)", serverUrl, activeAccount];
    
    TableDirectory *record = [TableDirectory MR_findFirstWithPredicate:predicate];
    
    if (record) return record.rev;
    else return nil;
}

+ (NSArray *)getDirectoryIDsFromBeginsWithServerUrl:(NSString *)serverUrl activeAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(serverUrl BEGINSWITH %@) AND (account == %@)", serverUrl, activeAccount];
    
    return [TableDirectory MR_findAllWithPredicate:predicate];
}

+ (NSString *)getDirectoryIDFromServerUrl:(NSString *)serverUrl activeAccount:(NSString *)activeAccount
{
    if (serverUrl == nil) return nil;
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(serverUrl == %@) AND (account == %@)", serverUrl, activeAccount];
    
    TableDirectory *record = [TableDirectory MR_findFirstWithPredicate:predicate];
    if (record) return record.directoryID;
    else {
        return [self addDirectory:serverUrl date:NULL permissions:nil activeAccount:activeAccount];
    }
    return nil;
}

+ (NSString *)getServerUrlFromDirectoryID:(NSString *)directoryID activeAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(directoryID == %@) AND (account == %@)", directoryID, activeAccount];
    TableDirectory *record = [TableDirectory MR_findFirstWithPredicate:predicate];
    
    if (record) return record.serverUrl;
    else return nil;
}

+ (void)clearDateReadDirectory:(NSString *)serverUrl activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(serverUrl == %@) AND (account == %@)", serverUrl, activeAccount];
        TableDirectory *record = [TableDirectory MR_findFirstWithPredicate:predicate inContext:localContext];
        
        if (record)
            record.dateReadDirectory = NULL;
    }];
}

+ (void)clearAllDateReadDirectory
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        NSArray *records = [TableDirectory MR_findAllInContext:localContext];
        
        for (TableDirectory *record in records)
            record.dateReadDirectory = NULL;
    }];
}

+ (BOOL)isDirectoryOutOfDate:(int)numAddDay directoryID:(NSString *)directoryID activeAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@)", activeAccount, directoryID];
    TableDirectory *record = [TableDirectory MR_findFirstWithPredicate:predicate];
    
    if (record == nil || record.dateReadDirectory == nil) {
        return YES;
    }
    
    NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
    [dateComponents setWeekday:numAddDay];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    NSDate *datePlus = [calendar dateByAddingComponents:dateComponents toDate:record.dateReadDirectory options:0];
    NSDate *now = [NSDate date];
    
    // usa la Cache se richiesto e se la data è entro X giorni dall'ultima volta che l'hai letta.
    if ([now compare:datePlus] == NSOrderedDescending) {
        return YES;
    }
    
    return NO;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Synchronized Directory =====
#pragma --------------------------------------------------------------------------------------------

+ (void)removeSynchronizedDirectoryID:(NSString *)directoryID activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(directoryID == %@) AND (account == %@) AND (synchronized == 1)", directoryID, activeAccount];
        TableDirectory *record = [TableDirectory MR_findFirstWithPredicate:predicate inContext:localContext];
    
        if (record)
            record.synchronized = [NSNumber numberWithBool:FALSE];
    }];
}

+ (NSArray *)getSynchronizedDirectoryActiveAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (synchronized == 1)", activeAccount];
    return [TableDirectory MR_findAllWithPredicate:predicate];
}

+ (void)setSynchronizedDirectory:(NSString *)serverUrl synchronized:(BOOL)synchronized activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(serverUrl == %@) AND (account == %@)", serverUrl, activeAccount];
        TableDirectory *record = [TableDirectory MR_findFirstWithPredicate:predicate inContext:localContext];
    
        if (record)
            record.synchronized = [NSNumber numberWithBool:synchronized];
    }];
}

+ (BOOL)isSynchronizedDirectory:(NSString *)serverUrl activeAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(directoryID == %@) AND (synchronized == 1) AND (account == %@)", [self getDirectoryIDFromServerUrl:serverUrl activeAccount:activeAccount], activeAccount];
    TableDirectory *record = [TableDirectory MR_findFirstWithPredicate:predicate];
    
    if (record) return YES;
    else return NO;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Directory Lock =====
#pragma --------------------------------------------------------------------------------------------

+ (BOOL)setDirectoryLock:(NSString *)serverUrl activeAccount:(NSString *)activeAccount
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(directoryID == %@) AND (account == %@)", [self getDirectoryIDFromServerUrl:serverUrl activeAccount:activeAccount], activeAccount];
    TableDirectory *record = [TableDirectory MR_findFirstWithPredicate:predicate inContext:context];
    
    if (record) {
        
        record.lock = [NSNumber numberWithBool:YES];
        
        [context MR_saveToPersistentStoreAndWait];

        return YES;
    }
    else return NO;
}

+ (BOOL)setDirectoryUnLock:(NSString *)serverUrl activeAccount:(NSString *)activeAccount
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(directoryID == %@) AND (account == %@)", [self getDirectoryIDFromServerUrl:serverUrl activeAccount:activeAccount], activeAccount];
    TableDirectory *record = [TableDirectory MR_findFirstWithPredicate:predicate inContext:context];
    
    if (record) {
        
        record.lock = [NSNumber numberWithBool:NO];
        
        [context MR_saveToPersistentStoreAndWait];
        
        return YES;
    }
    else return NO;
}

+ (void)setAllDirectoryUnLockForAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", activeAccount];
        NSArray *records = [TableDirectory MR_findAllWithPredicate:predicate inContext:localContext];
        
        for(TableDirectory *record in records)
            record.lock = [NSNumber numberWithBool:NO];
    }];
}

+ (BOOL)isDirectoryLock:(NSString *)serverUrl activeAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(directoryID == %@) AND (lock == 1) AND (account == %@)", [self getDirectoryIDFromServerUrl:serverUrl activeAccount:activeAccount], activeAccount];
    TableDirectory *record = [TableDirectory MR_findFirstWithPredicate:predicate];
    
    if (record) return YES;
    else return NO;
}

+ (BOOL)isBlockZone:(NSString *)serverUrl activeAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (directory == 1)", activeAccount];
    NSArray *records = [TableMetadata MR_findAllWithPredicate:predicate];
    
    if ([records count] > 0) {
        
        NSArray *pathComponents = [serverUrl pathComponents];
        
        for (NSString *fileName in pathComponents) {
            
            for(TableMetadata *record in records){
                
                NSString *fileNameEntity = [CCUtility trasformedFileNamePlistInCrypto:record.fileName];
                NSString *directoryID = record.directoryID;
                NSString *serverUrlEntity = [self getServerUrlFromDirectoryID:directoryID activeAccount:activeAccount];
                
                if([fileName isEqualToString:fileNameEntity]) {
                    
                    NSString *lockServerUrl = [CCUtility stringAppendServerUrl:serverUrlEntity addServerUrl:fileNameEntity];
                    
                    BOOL risultato = [self isDirectoryLock:lockServerUrl activeAccount:activeAccount];
                    if (risultato) return YES;
                }
                
            }
        }
    }
    
    return NO;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== LocalFile =====
#pragma --------------------------------------------------------------------------------------------

+ (void)addLocalFile:(CCMetadata *)metadata activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        BOOL favorite = NO;
    
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (fileID == %@)", activeAccount, metadata.fileID];
        TableLocalFile *record = [TableLocalFile MR_findFirstWithPredicate:predicate inContext:localContext];
        
        if (record) {
            
            favorite = [[record valueForKey:@"favorite"] boolValue];
            
            [record MR_deleteEntityInContext:localContext];
        }
        
        record = [TableLocalFile MR_createEntityInContext:localContext];
        
        record.account = activeAccount;
        record.date = metadata.date;
        record.dateRecord = [NSDate date];
        record.fileID = metadata.fileID;
    
        record.exifDate = [NSDate date];
        record.exifLatitude = @"-1";
        record.exifLongitude = @"-1";
        
        record.favorite = [NSNumber numberWithBool:favorite];
        record.fileName = metadata.fileName;
        record.fileNamePrint = metadata.fileNamePrint;
        record.rev = metadata.rev;
        record.size = [NSNumber numberWithLong:metadata.size];
    }];
}

+ (void)addFavorite:(NSString *)fileID activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", fileID, activeAccount];
        TableLocalFile *record = [TableLocalFile MR_findFirstWithPredicate:predicate inContext:localContext];
    
        if (record)
            record.favorite = [NSNumber numberWithBool:YES];
    }];
}

+ (void)deleteLocalFileWithPredicate:(NSPredicate *)predicate
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        [TableLocalFile MR_deleteAllMatchingPredicate:predicate inContext:localContext];
    }];
}

+ (void)removeFavoriteFromFileID:(NSString *)fileID activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", fileID, activeAccount];
        TableLocalFile *record = [TableLocalFile MR_findFirstWithPredicate:predicate inContext:localContext];
    
        if (record)
            record.favorite = [NSNumber numberWithBool:NO];
    }];
}


+ (void)renameLocalFileWithFileID:(NSString *)fileID fileNameTo:(NSString *)fileNameTo fileNamePrintTo:(NSString *)fileNamePrintTo activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", fileID, activeAccount];
        TableLocalFile *record = [TableLocalFile MR_findFirstWithPredicate:predicate inContext:localContext];
    
        if (record) {
            
            if (fileNameTo)record.fileName = fileNameTo;
            if (fileNamePrintTo)record.fileNamePrint = fileNamePrintTo;
        }
    }];
}

+ (void)updateLocalFileModel:(CCMetadata *)metadata activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (fileName == %@)", activeAccount, metadata.fileName];
        TableLocalFile *record = [TableLocalFile MR_findFirstWithPredicate:predicate inContext:localContext];
    
        if (record) {
            
            record.fileID = metadata.fileID;
            record.date = metadata.date;
            record.fileNamePrint = metadata.fileNamePrint;
        
        } else {
        
            [self addLocalFile:metadata activeAccount:activeAccount];
        }
    }];
}

+ (BOOL)isFavorite:(NSString *)fileID activeAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(fileID == %@) AND (favorite == 1) AND (account == %@)", fileID, activeAccount];
    TableLocalFile *record = [TableLocalFile MR_findFirstWithPredicate:predicate];
    
    if (record) return YES;
    else return NO;
}

+ (TableLocalFile *)getLocalFileWithFileID:(NSString *)fileID activeAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", fileID, activeAccount];
    TableLocalFile *record = [TableLocalFile MR_findFirstWithPredicate:predicate];
    
    if (record) {
        
        return record;
    } else return nil;
}

+ (NSMutableArray *)getTableLocalFileWithPredicate:(NSPredicate *)predicate controlZombie:(BOOL)controlZombie activeAccount:(NSString *)activeAccount directoryUser:(NSString *)directoryUser
{
    NSMutableArray *ritorno = [[NSMutableArray alloc] init];
    
    NSArray *records = [TableLocalFile MR_findAllWithPredicate:predicate];
    
    if ([records count] > 0) {
        
        // verifichiamo esistano tutti i file altrimenti rimuoviamo il record
        for(TableLocalFile *record in records){
            
            if (controlZombie) {
                
                NSString *fileID = record.fileID;
                NSString *FilePathFileID = [NSString stringWithFormat:@"%@/%@", directoryUser, fileID];
                NSString *FilePathFileName = [NSString stringWithFormat:@"%@/%@", directoryUser, record.fileName];
                if (![[NSFileManager defaultManager] fileExistsAtPath:FilePathFileID] && ![[NSFileManager defaultManager] fileExistsAtPath:FilePathFileName] && controlZombie) {
                    
                    // non esiste nè il file fileID e nemmeno il plist, eliminiamolo.
                    [self deleteLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", fileID, activeAccount]];
                    
                    
                } else [ritorno addObject:record];
            } else [ritorno addObject:record];
        }
        
    } else return nil;
    
    if ([ritorno count] == 0) return nil;
    else return ritorno;
}

+ (NSArray *)getTableLocalFileWithPredicate:(NSPredicate *)predicate
{
    return [TableLocalFile MR_findAllWithPredicate:predicate];
}

+ (NSArray *)getFavoriteWithControlZombie:(BOOL)controlZombie activeAccount:(NSString *)activeAccount directoryUser:(NSString *)directoryUser
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    NSMutableArray *favorites = [self getTableLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (favorite == 1)", activeAccount] controlZombie:controlZombie activeAccount:activeAccount directoryUser:directoryUser];
    
    for (NSManagedObject *entity in favorites) {
        NSString *fileID = [entity valueForKey:@"fileID"];
        CCMetadata *metadata = [self getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", fileID, activeAccount] context:nil];
        if (metadata) [result addObject:[metadata copy]];
    }
    
    return result;
}

+ (NSArray *)getGeoInformationLocalFromFileID:(NSString *)fileID activeAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", fileID, activeAccount];
    TableLocalFile *record = [TableLocalFile MR_findFirstWithPredicate:predicate];
    
    if (record) return [[NSArray alloc] initWithObjects:record.exifDate, record.exifLatitude, record.exifLongitude, nil];
    else return nil;
}

+ (void)setGeoInformationLocalFromFileID:(NSString *)fileID exifDate:(NSDate *)exifDate exifLatitude:(NSString *)exifLatitude exifLongitude:(NSString *)exifLongitude activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (fileID == %@)", activeAccount, fileID];
        TableLocalFile *record = [TableLocalFile MR_findFirstWithPredicate:predicate inContext:localContext];
    
        if (record) {
            
            record.exifDate = exifDate;
            record.exifLatitude = exifLatitude;
            record.exifLongitude = exifLongitude;
        }
    }];
}

+ (void)setGeoInformationLocalNull
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        NSArray *records = [TableLocalFile MR_findAllInContext:localContext];
        
        for (TableLocalFile *record in records) {
            
            if ([record.exifLatitude doubleValue] != 0 || [record.exifLongitude doubleValue] != 0) {
                record.exifLatitude = @"9999";
                record.exifLongitude = @"9999";
            }
        }
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Automatic Upload =====
#pragma --------------------------------------------------------------------------------------------

+ (void)addTableAutomaticUpload:(CCMetadataNet *)metadataNet activeAccount:(NSString *)activeAccount context:(NSManagedObjectContext *)context
{
    TableAutomaticUpload *record;
    
    if (context == nil)
        context = [NSManagedObjectContext MR_context];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (fileName == %@) AND (serverUrl == %@)", activeAccount, metadataNet.fileName, metadataNet.serverUrl];
    record = [TableAutomaticUpload MR_findFirstWithPredicate:predicate inContext:context];
    
    if (!record) {
    
        record = [TableAutomaticUpload MR_createEntityInContext:context];
        
        record.account = activeAccount;
        record.assetLocalItentifier = metadataNet.assetLocalItentifier;
        record.date = [NSDate date];
        record.fileName = metadataNet.fileName;
        record.isExecuting = [NSNumber numberWithBool:NO];
        record.selector = metadataNet.selector;
        record.selectorPost = metadataNet.selectorPost;
        record.serverUrl = metadataNet.serverUrl;
        record.session = metadataNet.session;
        record.priority = [NSNumber numberWithLong:metadataNet.priority];
        
        [context MR_saveToPersistentStoreAndWait];
    }
}

+ (NSArray *)getTableAutomaticUploadForAccount:(NSString *)activeAccount selector:(NSString *)selector numRecords:(NSUInteger)numRecords context:(NSManagedObjectContext *)context
{
    if (numRecords == 0)
        return nil;
    
    NSMutableArray *metadatasNet = [[NSMutableArray alloc] init];
    NSUInteger counter = 0;
    
    if (context == nil)
        context = [NSManagedObjectContext MR_context];
    
    NSArray *records = [TableAutomaticUpload MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (selector == %@) AND (isExecuting == 0)", activeAccount, selector]];
    
    for (TableAutomaticUpload *record in records) {
        
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] init];
        
        metadataNet.action = actionUploadAsset;                             // Default
        metadataNet.assetLocalItentifier = record.assetLocalItentifier;
        metadataNet.fileName = record.fileName;
        metadataNet.priority = [record.priority longValue];
        metadataNet.selector = record.selector;
        metadataNet.selectorPost = record.selectorPost;
        metadataNet.serverUrl = record.serverUrl;
        metadataNet.session = record.session;
        metadataNet.taskStatus = taskStatusResume;                          // Default
        
        [metadatasNet addObject:metadataNet];
        
        if (++counter == numRecords)
            break;
    }
    
    return metadatasNet;
}

+ (NSUInteger)countTableAutomaticUploadForAccount:(NSString *)activeAccount
{
    NSUInteger count = [TableAutomaticUpload MR_countOfEntitiesWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (isExecuting == 0)", activeAccount]];
    
    return count;
}

+ (void)setTableAutomaticUploadIfExecutingForAccount:(NSString *)activeAccount fileName:(NSString *)fileName serverUrl:(NSString *)serverUrl selector:(NSString*)selector context:(NSManagedObjectContext *)context
{
    if (context == nil)
        context = [NSManagedObjectContext MR_context];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (fileName == %@) AND (serverUrl == %@) AND (selector == %@)", activeAccount, fileName, serverUrl, selector];
    TableAutomaticUpload *record = [TableAutomaticUpload MR_findFirstWithPredicate:predicate inContext:context];
    
    if (record) {
        
        record.isExecuting = [NSNumber numberWithBool:YES];
        
        [context MR_saveToPersistentStoreAndWait];
    }
}

+ (void)deleteTableAutomaticUploadForAccount:(NSString *)activeAccount fileName:(NSString *)fileName serverUrl:(NSString *)serverUrl selector:(NSString*)selector context:(NSManagedObjectContext *)context
{
    if (context == nil)
        context = [NSManagedObjectContext MR_context];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (fileName == %@) AND (serverUrl == %@) AND (selector == %@)", activeAccount, fileName, serverUrl, selector];
    [TableAutomaticUpload MR_deleteAllMatchingPredicate:predicate inContext:context];
    
    [context MR_saveToPersistentStoreAndWait];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== GPS =====
#pragma --------------------------------------------------------------------------------------------

+ (void)setGeocoderLocation:(NSString *)location placemarkAdministrativeArea:(NSString *)placemarkAdministrativeArea placemarkCountry:(NSString *)placemarkCountry placemarkLocality:(NSString *)placemarkLocality placemarkPostalCode:(NSString *)placemarkPostalCode placemarkThoroughfare:(NSString *)placemarkThoroughfare latitude:(NSString *)latitude longitude:(NSString *)longitude
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
        
    TableGPS *record = [TableGPS MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"(latitude == %@) AND (longitude == %@)", latitude, longitude] inContext:context];
        
    if (!record) {
        record = [TableGPS MR_createEntityInContext:context];
        record.dateRecord = [NSDate date];
    }
        
    record.latitude = latitude;
    record.longitude = longitude;
    if (location) record.location = location;
    if (placemarkAdministrativeArea) record.placemarkAdministrativeArea = placemarkAdministrativeArea;
    if (placemarkCountry) record.placemarkCountry = placemarkCountry;
    if (placemarkLocality) record.placemarkLocality = placemarkLocality;
    if (placemarkPostalCode) record.placemarkPostalCode = placemarkPostalCode;
    if (placemarkThoroughfare) record.placemarkThoroughfare = placemarkThoroughfare;
    
    [context MR_saveToPersistentStoreAndWait];
}

+ (NSString *)getLocationFromGeoLatitude:(NSString *)latitude longitude:(NSString *)longitude
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];

    TableGPS *record = [TableGPS MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"(latitude == %@) AND (longitude == %@)", latitude, longitude] inContext:context];
    
    if (record) return record.location;
    else return nil;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Share =====
#pragma --------------------------------------------------------------------------------------------

+ (void)setShareLink:(NSString *)share fileName:(NSString *)fileName serverUrl:(NSString *)serverUrl sharesLink:(NSMutableDictionary *)sharesLink activeAccount:(NSString *)activeAccount
{    
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (fileName == %@) AND (serverUrl == %@)", activeAccount, fileName, serverUrl];
    TableShare *record = [TableShare MR_findFirstWithPredicate:predicate inContext:context];
    
    if (record) {
        
        record.shareLink = share;
        
    } else {
        
        TableShare *record = [TableShare MR_createEntityInContext:context];
        
        record.account = activeAccount;
        record.dateRecord = [NSDate date];
        record.fileName = fileName;
        record.serverUrl = serverUrl;
        record.shareLink = share;
    }
    
    [context MR_saveToPersistentStoreAndWait];
    
    if (share && serverUrl && fileName)
        [sharesLink setObject:share forKey:[serverUrl stringByAppendingString:fileName]];
}

+ (void)setShareUserAndGroup:(NSString *)share fileName:(NSString *)fileName serverUrl:(NSString *)serverUrl sharesUserAndGroup:(NSMutableDictionary *)sharesUserAndGroup activeAccount:(NSString *)activeAccount
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (fileName == %@) AND (serverUrl == %@)", activeAccount, fileName, serverUrl];
    TableShare *record = [TableShare MR_findFirstWithPredicate:predicate inContext:context];
    
    if (record) {
        
        record.shareUserAndGroup = share;
        
    } else {
        
        TableShare *record = [TableShare MR_createEntityInContext:context];
        
        record.account = activeAccount;
        record.dateRecord = [NSDate date];
        record.fileName = fileName;
        record.serverUrl = serverUrl;
        record.shareUserAndGroup = share;
        
    }
    
    [context MR_saveToPersistentStoreAndWait];

    [sharesUserAndGroup setObject:share forKey:[serverUrl stringByAppendingString:fileName]];
}

+ (void)unShare:(NSString *)share fileName:(NSString *)fileName serverUrl:(NSString *)serverUrl sharesLink:(NSMutableDictionary *)sharesLink sharesUserAndGroup:(NSMutableDictionary *)sharesUserAndGroup activeAccount:(NSString *)activeAccount
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND ((shareLink CONTAINS %@) OR (shareUserAndGroup CONTAINS %@))", activeAccount, share, share];
    
    TableShare *record = [TableShare MR_findFirstWithPredicate:predicate inContext:context];
    
    if (record) {
        
        if ([record.shareLink containsString:share]) record.shareLink = @"";
        if ([record.shareUserAndGroup containsString:share]) {
            
            NSMutableArray *shares = [[NSMutableArray alloc] initWithArray:[record.shareUserAndGroup componentsSeparatedByString:@","]];
            [shares removeObject:share];
            record.shareUserAndGroup = [shares componentsJoinedByString:@","];
        }
        
        if ([record.shareLink length] == 0 && [record.shareUserAndGroup length] == 0)
            [record MR_deleteEntityInContext:context];
        
        [context MR_saveToPersistentStoreAndWait];
        
        if ([record.shareLink length] > 0) [sharesLink setObject:record.shareLink forKey:[serverUrl stringByAppendingString:fileName]];
        else [sharesLink removeObjectForKey:[serverUrl stringByAppendingString:fileName]];
        
        if ([record.shareUserAndGroup length] > 0) [sharesUserAndGroup setObject:record.shareUserAndGroup forKey:[serverUrl stringByAppendingString:fileName]];
        else [sharesUserAndGroup removeObjectForKey:[serverUrl stringByAppendingString:fileName]];
    }
}

+ (void)removeAllShareActiveAccount:(NSString *)activeAccount sharesLink:(NSMutableDictionary *)sharesLink sharesUserAndGroup:(NSMutableDictionary *)sharesUserAndGroup
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    
    [TableShare MR_deleteAllMatchingPredicate:[NSPredicate predicateWithFormat:@"account == %@", activeAccount] inContext:context];
    [context MR_saveToPersistentStoreAndWait];

    [sharesLink removeAllObjects];
    [sharesUserAndGroup removeAllObjects];
}

+ (void)updateShare:(NSDictionary *)items sharesLink:(NSMutableDictionary *)sharesLink sharesUserAndGroup:(NSMutableDictionary *)sharesUserAndGroup activeAccount:(NSString *)activeAccount activeUrl:(NSString *)activeUrl typeCloud:(NSString *)typeCloud
{
    // rimuovi tutte le condivisioni
    [self removeAllShareActiveAccount:activeAccount sharesLink:sharesLink sharesUserAndGroup:sharesUserAndGroup];
    
    /*** DROPBOX ***/
    
    if ([typeCloud isEqualToString:typeCloudDropbox]) {
        
        // Link
        for (NSString *url in items) {
            
            NSDictionary *item = [items objectForKey:url];
            
            NSString *path = [item objectForKey:@"path"];
            NSString *fileName = [path lastPathComponent];
            NSString *serverUrl = [path stringByDeletingLastPathComponent];
            
            if ([item objectForKey:@"url"])
                [self setShareLink:[item objectForKey:@"url"] fileName:fileName serverUrl:serverUrl sharesLink:sharesLink activeAccount:activeAccount];
        }
    }
    
    /*** NEXTCLOUD OWNCLOUD ***/
    
    if ([typeCloud isEqualToString:typeCloudOwnCloud] || [typeCloud isEqualToString:typeCloudNextcloud]) {
        
        NSMutableArray *itemsLink = [[NSMutableArray alloc] init];
        NSMutableArray *itemsUsersAndGroups = [[NSMutableArray alloc] init];
        
        for (NSString *idRemoteShared in items) {
            
            OCSharedDto *item = [items objectForKey:idRemoteShared];
            
            if (item.shareType == shareTypeLink) [itemsLink addObject:item];
            if ([[item shareWith] length] > 0 && (item.shareType == shareTypeUser || item.shareType == shareTypeGroup || item.shareType == shareTypeRemote)) [itemsUsersAndGroups addObject:item];
        }
        
        // Link
        for (OCSharedDto *item in itemsLink) {
            
            NSString *fullPath = [[CCUtility getHomeServerUrlActiveUrl:activeUrl typeCloud:typeCloud] stringByAppendingString:item.path];
            
            NSString *fileName = [fullPath lastPathComponent];
            NSString *serverUrl = [fullPath substringToIndex:([fullPath length]-[fileName length]-1)];
            if ([serverUrl hasSuffix:@"/"]) serverUrl = [serverUrl substringToIndex:[serverUrl length] - 1];
            
            if ([@(item.idRemoteShared) stringValue])
                [self setShareLink:[@(item.idRemoteShared) stringValue] fileName:fileName serverUrl:serverUrl sharesLink:sharesLink activeAccount:activeAccount];
        }
        
        // Condivisioni
        NSMutableDictionary *paths = [[NSMutableDictionary alloc] init];
        
        // Creazione dizionario
        for (OCSharedDto *item in itemsUsersAndGroups) {
            
            if ([paths objectForKey:item.path]) {
                
                NSMutableArray *share = [paths objectForKey:item.path];
                [share addObject:[@(item.idRemoteShared) stringValue]];
                [paths setObject:share forKey:item.path];
                
            } else {
                
                NSMutableArray *share = [[NSMutableArray alloc] initWithObjects:[@(item.idRemoteShared) stringValue], nil];
                [paths setObject:share forKey:item.path];
            }
        }
        
        // Scrittura su DB
        for (NSString *path in paths) {
            
            NSArray *items = [paths objectForKey:path];
            NSString *share = [items componentsJoinedByString:@","];
            
            NSLog(@"[LOG] share %@", share);
            
            NSString *fullPath = [[CCUtility getHomeServerUrlActiveUrl:activeUrl typeCloud:typeCloud] stringByAppendingString:path];
            
            NSString *fileName = [fullPath lastPathComponent];
            NSString *serverUrl = [fullPath substringToIndex:([fullPath length]-[fileName length]-1)];
            if ([serverUrl hasSuffix:@"/"]) serverUrl = [serverUrl substringToIndex:[serverUrl length] - 1];
            
            if (share)
                [self setShareUserAndGroup:share fileName:fileName serverUrl:serverUrl sharesUserAndGroup:sharesUserAndGroup activeAccount:activeAccount];
        }
    }
}

+ (void)populateSharesVariableFromDBActiveAccount:(NSString *)activeAccount sharesLink:(NSMutableDictionary *)sharesLink sharesUserAndGroup:(NSMutableDictionary *)sharesUserAndGroup
{
    [sharesLink removeAllObjects];
    [sharesUserAndGroup removeAllObjects];
    
    NSArray *records = [TableShare MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@)", activeAccount]];
    
    for (TableShare *record in records) {
        
        if ([record.shareLink length] > 0 && record.serverUrl && record.fileName)
            [sharesLink setObject:record.shareLink forKey:[record.serverUrl stringByAppendingString:record.fileName]];
        
        if ([record.shareUserAndGroup length] > 0 && record.serverUrl && record.fileName)
            [sharesUserAndGroup setObject:record.shareUserAndGroup forKey:[record.serverUrl stringByAppendingString:record.fileName]];
    }
    
    return;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== File System =====
#pragma --------------------------------------------------------------------------------------------

+ (BOOL)downloadFile:(CCMetadata *)metadata directoryUser:(NSString *)directoryUser activeAccount:(NSString *)activeAccount
{
    CCCrypto *crypto = [[CCCrypto alloc] init];
    
    // ----------------------------------------- FILESYSTEM ------------------------------------------
    
    // if encrypted, rewrite
    if (metadata.cryptated == YES)
        if ([crypto decrypt:metadata.fileID fileNameDecrypted:metadata.fileID fileNamePrint:metadata.fileNamePrint password:[crypto getKeyPasscode:metadata.uuid] directoryUser:directoryUser] == 0) return NO;
    
    // ------------------------------------------ COREDATA -------------------------------------------
    
    // add/update Table Local File
    [self addLocalFile:metadata activeAccount:activeAccount];
    
    // EXIF
    if ([metadata.typeFile isEqualToString:metadataTypeFile_image])
        [CCExifGeo setExifLocalTableFileID:metadata directoryUser:directoryUser activeAccount:activeAccount];
    
    // Icon
    [CCGraphics createNewImageFrom:metadata.fileID directoryUser:directoryUser fileNameTo:metadata.fileID fileNamePrint:metadata.fileNamePrint size:@"m" imageForUpload:NO typeFile:metadata.typeFile writePreview:YES optimizedFileName:[CCUtility getOptimizedPhoto]];
    
    return YES;
}

+ (void)downloadFilePlist:(CCMetadata *)metadata activeAccount:(NSString *)activeAccount activeUrl:(NSString *)activeUrl typeCloud:(NSString *)typeCloud directoryUser:(NSString *)directoryUser
{
    // inseriamo le info nel plist
    [CCUtility insertInformationPlist:metadata directoryUser:directoryUser];
    
    // aggiorniamo il CCMetadata
    [self updateMetadata:metadata predicate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", metadata.fileID, activeAccount] activeAccount:activeAccount activeUrl:activeUrl typeCloud:typeCloud context:nil];
    
    // se è un modello aggiorniamo anche nel FileSystem
    if ([metadata.type isEqualToString:metadataType_model]){
        [self updateLocalFileModel:metadata activeAccount:activeAccount];
    }
}

+ (void)deleteFile:(CCMetadata *)metadata serverUrl:(NSString *)serverUrl directoryUser:(NSString *)directoryUser typeCloud:(NSString *)typeCloud activeAccount:(NSString *)activeAccount
{
    // ----------------------------------------- FILESYSTEM ------------------------------------------
    
    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", directoryUser, metadata.fileID] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@.ico", directoryUser, metadata.fileID] error:nil];
    
    // ------------------------------------------ COREDATA -------------------------------------------
    
    [self deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", metadata.fileID, activeAccount]];
    [self deleteLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", metadata.fileID, activeAccount]];
    
    // se è una directory cancelliamo tutto quello che è della directory
    if (metadata.directory && serverUrl) {
        
        NSString *dirForDelete = [CCUtility stringAppendServerUrl:serverUrl addServerUrl:metadata.fileNameData];
        [self deleteDirectoryAndSubDirectory:dirForDelete activeAccount:activeAccount];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Metadata <> Entity =====
#pragma --------------------------------------------------------------------------------------------

+ (void)insertMetadataInEntity:(CCMetadata *)metadata recordMetadata:(TableMetadata *)recordMetadata activeAccount:(NSString *)activeAccount activeUrl:(NSString *)activeUrl typeCloud:(NSString *)typeCloud
{
    if ([activeAccount length]) recordMetadata.account = activeAccount;
    recordMetadata.cryptated = [NSNumber numberWithBool:metadata.cryptated];
    if (metadata.date) recordMetadata.date = metadata.date;
    recordMetadata.directory = [NSNumber numberWithBool:metadata.directory];
    recordMetadata.errorPasscode = [NSNumber numberWithBool:metadata.errorPasscode];
    if ([metadata.fileID length]) recordMetadata.fileID = metadata.fileID;
    if ([metadata.directoryID length]) recordMetadata.directoryID = metadata.directoryID;
    if ([metadata.fileName length]) recordMetadata.fileName = metadata.fileName;
    if ([metadata.fileName length]) recordMetadata.fileNameData = [CCUtility trasformedFileNamePlistInCrypto:metadata.fileName];
    if ([metadata.fileNamePrint length]) recordMetadata.fileNamePrint = metadata.fileNamePrint;
    if ([metadata.localIdentifier length]) recordMetadata.localIdentifier = metadata.localIdentifier;
    if ([metadata.model length]) recordMetadata.model = metadata.model;
    if ([metadata.nameCurrentDevice length]) recordMetadata.nameCurrentDevice = metadata.nameCurrentDevice;
    if ([metadata.permissions length]) recordMetadata.permissions = metadata.permissions;
    if ([metadata.protocol length]) recordMetadata.protocol = metadata.protocol;
    
    if ([metadata.rev length]) recordMetadata.rev = metadata.rev;
    
    if (metadata.session) recordMetadata.session = metadata.session;
    else metadata.session = @"";
    
    recordMetadata.sessionError = metadata.sessionError;
    recordMetadata.sessionID = metadata.sessionID;
    recordMetadata.sessionSelector = metadata.sessionSelector;
    recordMetadata.sessionSelectorPost = metadata.sessionSelectorPost;

    recordMetadata.sessionTaskIdentifier = [NSNumber numberWithInt:metadata.sessionTaskIdentifier];
    recordMetadata.sessionTaskIdentifierPlist = [NSNumber numberWithInt:metadata.sessionTaskIdentifierPlist];
    
    if (metadata.size) recordMetadata.size = [NSNumber numberWithLong:metadata.size];
    if ([metadata.title length]) recordMetadata.title = metadata.title;
    recordMetadata.thumbnailExists = [NSNumber numberWithBool:metadata.thumbnailExists];

    if ([metadata.type length]) recordMetadata.type = metadata.type;
    if ([metadata.typeCloud length]) recordMetadata.typeCloud = metadata.typeCloud;
    if ([metadata.uuid length]) recordMetadata.uuid = metadata.uuid;

    // inseriamo il typeFile e icona di default.
    [CCUtility insertTypeFileIconName:metadata directory:[self getServerUrlFromDirectoryID:metadata.directoryID activeAccount:activeAccount] cameraFolderName:[self getCameraUploadFolderNameActiveAccount:activeAccount] cameraFolderPath:[self getCameraUploadFolderPathActiveAccount:activeAccount activeUrl:activeUrl typeCloud:typeCloud]];
    
    recordMetadata.typeFile = metadata.typeFile;
    recordMetadata.iconName = metadata.iconName;
}

+ (CCMetadata *)insertEntityInMetadata:(TableMetadata *)recordMetadata
{
    CCMetadata *metadata = [[CCMetadata alloc] init];
    
    metadata.account = recordMetadata.account;
    metadata.cryptated = [recordMetadata.cryptated boolValue];
    metadata.date = recordMetadata.date;
    metadata.dateRecord = recordMetadata.dateRecord;
    metadata.directory = [recordMetadata.directory boolValue];
    metadata.errorPasscode = [recordMetadata.errorPasscode boolValue];
    metadata.fileID = recordMetadata.fileID;
    metadata.directoryID = recordMetadata.directoryID;
    metadata.fileName = recordMetadata.fileName;
    metadata.fileNameData = recordMetadata.fileNameData;
    metadata.fileNamePrint = recordMetadata.fileNamePrint;
    metadata.iconName = recordMetadata.iconName;
    metadata.localIdentifier = recordMetadata.localIdentifier;
    metadata.model = recordMetadata.model;
    metadata.nameCurrentDevice = recordMetadata.nameCurrentDevice;
    metadata.permissions = recordMetadata.permissions;
    metadata.protocol = recordMetadata.protocol;
    metadata.rev = recordMetadata.rev;
    
    metadata.session = recordMetadata.session;
    metadata.sessionError = recordMetadata.sessionError;
    metadata.sessionID = recordMetadata.sessionID;
    metadata.sessionSelector = recordMetadata.sessionSelector;
    metadata.sessionSelectorPost = recordMetadata.sessionSelectorPost;
    metadata.sessionTaskIdentifier = [recordMetadata.sessionTaskIdentifier intValue];
    metadata.sessionTaskIdentifierPlist = [recordMetadata.sessionTaskIdentifierPlist intValue];
    
    metadata.size = [recordMetadata.size longValue];
    metadata.thumbnailExists = [recordMetadata.thumbnailExists boolValue];
    metadata.title = recordMetadata.title;
    metadata.type = recordMetadata.type;
    metadata.typeCloud = recordMetadata.typeCloud;
    metadata.typeFile = recordMetadata.typeFile;
    metadata.uuid = recordMetadata.uuid;
    
    return metadata;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Utility Database =====
#pragma --------------------------------------------------------------------------------------------

+ (void)moveCoreDataToGroup
{
    NSString *applicationName = [[[NSBundle mainBundle] infoDictionary] valueForKey:(NSString *)kCFBundleNameKey];
    NSURL *dirGroup = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:capabilitiesGroups];
    NSString *dirToPath = [[dirGroup URLByAppendingPathComponent:appDatabase] path];

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *dirFromPath = [[paths lastObject] stringByAppendingPathComponent:applicationName];
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dirFromPath error:nil];
    NSError *error;
    
    for(NSString *filename in files)
        [[NSFileManager defaultManager] moveItemAtPath:[dirFromPath stringByAppendingPathComponent:filename] toPath:[dirToPath stringByAppendingPathComponent:filename] error:&error];
}

+ (void)moveAllUserToGroup
{    
    NSArray *records = [TableAccount MR_findAll];

    for (TableAccount *record in records) {
                
        NSString *dirFromPath = [CCUtility getOLDDirectoryActiveUser:record.user activeUrl:record.url];
        NSString *dirToPath = [CCUtility getDirectoryActiveUser:record.user activeUrl:record.url];
        
        NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dirFromPath error:nil];
        NSError *error;

        for(NSString *filename in files)
            [[NSFileManager defaultManager] moveItemAtPath:[dirFromPath stringByAppendingPathComponent:filename] toPath:[dirToPath stringByAppendingPathComponent:filename] error:&error];        
    }
}

+ (void)verifyVersionCoreData:(UIViewController *)vc
{
    NSString *applicationName = [[[NSBundle mainBundle] infoDictionary] valueForKey:(NSString *)kCFBundleNameKey];
    
    // Get the path for our model (in this case it's named 'cache')
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"cryptocloud" withExtension:@"momd"];
    NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[[NSManagedObjectModel alloc] initWithContentsOfURL:url]]; /* get a coordinator */
    NSString *sourceStoreType = nil;/* type for the source store, or nil if not known */ ;
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
    // Figure out the full path where our store is located
    path = [path stringByAppendingFormat:@"/%@/cryptocloud", applicationName];
    NSURL *sourceStoreURL = [NSURL fileURLWithPath:path]; /* URL for the source store */ ;
    NSError *error = nil;
    
    NSDictionary *sourceMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:sourceStoreType URL:sourceStoreURL error:&error];
    
    if (sourceMetadata == nil) {
        
        NSLog(@"[LOG] Error checking migration validity");
        
    } else {
        
        if (![[psc managedObjectModel] isConfiguration:nil compatibleWithStoreMetadata:sourceMetadata]) {
            
            UIAlertController * alert= [UIAlertController alertControllerWithTitle:nil message:NSLocalizedString(@"_required_new_database_", nil) preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * action) {
                                                           [alert dismissViewControllerAnimated:YES completion:nil];
                                                       }];
            [alert addAction:ok];
            [vc presentViewController:alert animated:YES completion:nil];
            
            // Delete CoreData store
            NSFileManager *manager = [NSFileManager defaultManager];
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
            NSString *directory = [[paths lastObject] stringByAppendingPathComponent:applicationName];
            NSArray *files = [manager contentsOfDirectoryAtPath:directory error:nil];
            NSError *error;
            
            for(NSString *filename in files) {
                [manager removeItemAtPath:[directory stringByAppendingPathComponent:filename] error:&error];
            }
        }
    }
}

+ (void)flushTableAutomaticUploadAccount:(NSString *)account selector:(NSString *)selector
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    
    if (account && selector)
        [TableAutomaticUpload MR_deleteAllMatchingPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (selector == %@)", account, selector] inContext:context];
    else if (account && !selector )
        [TableAutomaticUpload MR_deleteAllMatchingPredicate:[NSPredicate predicateWithFormat:@"(account == %@)", account] inContext:context];
    else
        [TableAutomaticUpload MR_truncateAllInContext:context];
    
    [context MR_saveToPersistentStoreAndWait];
}

+ (void)flushTableDirectoryAccount:(NSString *)account
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    
    if (account) {
        
        [TableDirectory MR_deleteAllMatchingPredicate:[NSPredicate predicateWithFormat:@"(account == %@)", account] inContext:context];
        
    } else {
        
        [TableDirectory MR_truncateAllInContext:context];
    }
    
    [context MR_saveToPersistentStoreAndWait];
}

+ (void)flushTableLocalFileAccount:(NSString *)account
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    
    if (account) {
        
        [TableLocalFile MR_deleteAllMatchingPredicate:[NSPredicate predicateWithFormat:@"(account == %@)", account] inContext:context];
        
    } else {
        
        [TableLocalFile MR_truncateAllInContext:context];
    }
    
    [context MR_saveToPersistentStoreAndWait];
}

+ (void)flushTableMetadataAccount:(NSString *)account
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    
    if (account) {
        
        [TableMetadata MR_deleteAllMatchingPredicate:[NSPredicate predicateWithFormat:@"(account == %@)", account] inContext:context];
        
    } else {
        
        [TableMetadata MR_truncateAllInContext:context];
    }
    
    [context MR_saveToPersistentStoreAndWait];
}

+ (void)flushTableGPS
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];

    [TableGPS MR_truncateAllInContext:context];
    
    [context MR_saveToPersistentStoreAndWait];
}

+ (void)flushAllDatabase
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    
    [TableAccount MR_truncateAllInContext:context];
    [TableAutomaticUpload MR_truncateAllInContext:context];
    [TableCertificates MR_truncateAllInContext:context];
    [TableDirectory MR_truncateAllInContext:context];
    [TableGPS MR_truncateAllInContext:context];
    [TableLocalFile MR_truncateAllInContext:context];
    [TableMetadata MR_truncateAllInContext:context];
    [TableShare MR_truncateAllInContext:context];
    
    [context MR_saveToPersistentStoreAndWait];
}

@end
