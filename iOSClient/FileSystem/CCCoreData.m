//
//  CCCoreData.m
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

#import "CCCoreData.h"
#import "CCNetworking.h"
#import "NCBridgeSwift.h"

@implementation CCCoreData

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Account =====
#pragma --------------------------------------------------------------------------------------------

+ (NSArray *)getAllAccount
{
    NSMutableArray *accounts = [NSMutableArray new];
    NSArray *records;
    
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    
    records = [TableAccount MR_findAllInContext:context];
    
    for (TableAccount *tableAccount in records)
        [accounts addObject:tableAccount];
    
    return accounts;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Metadata =====
#pragma --------------------------------------------------------------------------------------------

/*
+ (void)addMetadata:(tableMetadata *)metadata activeAccount:(NSString *)activeAccount activeUrl:(NSString *)activeUrl context:(NSManagedObjectContext *)context
{
    if (context == nil)
        context = [NSManagedObjectContext MR_context];

    // remove all etag (BUG 2.10)
    [TableMetadata MR_deleteAllMatchingPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (etag == %@)", activeAccount, metadata.etag] inContext:context];
    [context MR_saveToPersistentStoreAndWait];
    
    // remove record if exists
    [TableMetadata MR_deleteAllMatchingPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (fileName == %@) AND (directoryID == %@)", activeAccount, metadata.fileName, metadata.directoryID] inContext:context];
    [context MR_saveToPersistentStoreAndWait];
    
    // create new record Metadata
    TableMetadata *record = [TableMetadata MR_createEntityInContext:context];

    // set default value
    metadata.sessionTaskIdentifier = k_taskIdentifierDone;
    metadata.sessionTaskIdentifierPlist = k_taskIdentifierDone;

    // Insert metdata -> entity
    [self insertMetadataInEntity:metadata recordMetadata:record activeAccount:activeAccount activeUrl:activeUrl];
    
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

+ (void)updateMetadata:(tableMetadata *)metadata predicate:(NSPredicate *)predicate activeAccount:(NSString *)activeAccount activeUrl:(NSString *)activeUrl context:(NSManagedObjectContext *)context
{
    TableMetadata *record;
    
    if (context == nil)
        context = [NSManagedObjectContext MR_defaultContext];
    
    record = [TableMetadata MR_findFirstWithPredicate:predicate inContext:context];
    
    if (record) {
        
        [self insertMetadataInEntity:metadata recordMetadata:record activeAccount:activeAccount activeUrl:activeUrl];
        
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
        if (sessionTaskIdentifier != k_taskIdentifierNULL) record.sessionTaskIdentifier = [NSNumber numberWithInteger:sessionTaskIdentifier];
        if (sessionTaskIdentifierPlist != k_taskIdentifierNULL) record.sessionTaskIdentifierPlist = [NSNumber numberWithInteger:sessionTaskIdentifierPlist];
        
        [directoryIDs addObject:record.directoryID];
        
        // Aggiorniamo la data nella directory (ottimizzazione v 2.10)
        if ([directoryID isEqualToString:record.directoryID] == NO)
            [self setDateReadDirectoryID:record.directoryID activeAccount:record.account];
        
        directoryID = record.directoryID;
    }
    
    [context MR_saveToPersistentStoreAndWait];
}

+ (void)setMetadataFavoriteFileID:(NSString *)etag favorite:(BOOL)favorite activeAccount:(NSString *)activeAccount context:(NSManagedObjectContext *)context
{
    if (context == nil)
        context = [NSManagedObjectContext MR_defaultContext];
    
    TableMetadata *tableMetadata = [TableMetadata MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (etag == %@)", activeAccount, etag] inContext:context];
    
    if (tableMetadata) {
        
        tableMetadata.favorite = [NSNumber numberWithBool:favorite];
        
        // Aggiorniamo la data nella directory (ottimizzazione v 2.10)
        [self setDateReadDirectoryID:tableMetadata.directoryID activeAccount:activeAccount];
        
        [context MR_saveToPersistentStoreAndWait];
    }
}

+ (tableMetadata *)getMetadataWithPreficate:(NSPredicate *)predicate context:(NSManagedObjectContext *)context
{
    if (context == nil)
        context = [NSManagedObjectContext MR_defaultContext];
    
    TableMetadata *record;
    
    record = [TableMetadata MR_findFirstWithPredicate:predicate inContext:context];
    
    if (record) {
        
        return [self insertEntityInMetadata:record];
        
    } else return nil;
}

+ (TableMetadata *)getTableMetadataWithPreficate:(NSPredicate *)predicate
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    
    return [TableMetadata MR_findFirstWithPredicate:predicate inContext:context];
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

+ (tableMetadata *)getMetadataAtIndex:(NSPredicate *)predicate fieldOrder:(NSString *)fieldOrder ascending:(BOOL)ascending objectAtIndex:(NSUInteger)index
{
    NSArray *records = [self getTableMetadataWithPredicate:predicate fieldOrder:fieldOrder ascending:ascending];
    
    TableMetadata *record = [records objectAtIndex:index];
    
    return [self insertEntityInMetadata:record];
}

+ (tableMetadata *)getMetadataFromFileName:(NSString *)fileName directoryID:(NSString *)directoryID activeAccount:(NSString *)activeAccount context:(NSManagedObjectContext *)context
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
    return [self getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND ((session == %@) || (session == %@)) AND ((sessionTaskIdentifier != %i) OR (sessionTaskIdentifierPlist != %i))", activeAccount, k_download_session, k_download_session_foreground, k_taskIdentifierDone, k_taskIdentifierDone] context:nil];
}

+ (NSArray *)getTableMetadataDownloadWWanAccount:(NSString *)activeAccount
{
    return [self getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (session == %@) AND ((sessionTaskIdentifier != %i) OR (sessionTaskIdentifierPlist != %i))", activeAccount, k_download_session_wwan, k_taskIdentifierDone, k_taskIdentifierDone] context:nil];
}

+ (NSArray *)getTableMetadataUploadAccount:(NSString *)activeAccount
{
    return [self getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND ((session == %@) || (session == %@)) AND ((sessionTaskIdentifier != %i) OR (sessionTaskIdentifierPlist != %i))", activeAccount, k_upload_session, k_upload_session_foreground, k_taskIdentifierDone, k_taskIdentifierDone] context:nil];
}

+ (NSArray *)getTableMetadataUploadWWanAccount:(NSString *)activeAccount
{
    return [self getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (session == %@) AND ((sessionTaskIdentifier != %i) OR (sessionTaskIdentifierPlist != %i))", activeAccount, k_upload_session_wwan, k_taskIdentifierDone, k_taskIdentifierDone] context:nil];
}

+ (NSArray *)getRecordsTableMetadataPhotosCameraUpload:(NSString *)serverUrl activeAccount:(NSString *)activeAccount
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    
    NSMutableArray *recordsPhotosCameraUpload = [[NSMutableArray alloc] init];
    NSArray *tableDirectoryes = [self getDirectoryIDsFromBeginsWithServerUrl:serverUrl activeAccount:activeAccount];
    
    for (TableDirectory *record in tableDirectoryes) {
                
        NSArray *records = [TableMetadata MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@) AND ((session == NULL) OR (session == '')) AND (type == 'file') AND ((typeFile == %@) OR (typeFile == %@))", activeAccount, record.directoryID, k_metadataTypeFile_image, k_metadataTypeFile_video] inContext:context];
        
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

+ (void)removeOfflineAllFileFromServerUrl:(NSString *)serverUrl activeAccount:(NSString *)activeAccount
{
    NSString *directoryID = [self getDirectoryIDFromServerUrl:serverUrl activeAccount:activeAccount];
    
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@)", activeAccount, directoryID];
        NSArray *records = [TableMetadata MR_findAllWithPredicate:predicate];
        
        for (TableMetadata *record in records)
            [self setOfflineLocalFileID:record.etag offline:NO activeAccount:activeAccount];
    }];
}
*/
#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Directory =====
#pragma --------------------------------------------------------------------------------------------

+ (NSString *)addDirectory:(NSString *)serverUrl permissions:(NSString *)permissions activeAccount:(NSString *)activeAccount
{
    NSString *directoryID;
    
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];

    TableDirectory *record = [TableDirectory MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"(serverUrl == %@) AND (account == %@)", serverUrl, activeAccount] inContext:context];
    
    if (record) {
     
        directoryID = record.directoryID;
        if (permissions) record.permissions = permissions;
        
    } else {
        
        TableDirectory *record = [TableDirectory MR_createEntityInContext:context];
        
        record.account = activeAccount;
        record.directoryID = [CCUtility createRandomString:16];
        directoryID = record.directoryID;
        if (permissions) record.permissions = permissions;
        record.serverUrl = serverUrl;
    }
    
    [context MR_saveToPersistentStoreAndWait];

    return directoryID;
}

+ (void)updateDirectoryEtagServerUrl:(NSString *)serverUrl etag:(NSString *)etag activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(serverUrl == %@) AND (account == %@)", serverUrl, activeAccount];
        TableDirectory *record = [TableDirectory MR_findFirstWithPredicate:predicate inContext:localContext];
        
        if (record)
            record.rev = etag;
    }];
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
            
            /*
            NSArray *tableMetadatas = [TableMetadata MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@)", activeAccount, recordDirectory.directoryID] inContext:context];
            
            for(TableMetadata *recordMetadata in tableMetadatas) {
                
                // remove if in session
                if ([recordMetadata.session length] >0) {
                    if (recordMetadata.sessionTaskIdentifier >= 0)
                        [[CCNetworking sharedNetworking] settingSession:recordMetadata.session sessionTaskIdentifier:[recordMetadata.sessionTaskIdentifier integerValue] taskStatus: k_taskStatusCancel];
                    
                    if (recordMetadata.sessionTaskIdentifierPlist >= 0)
                        [[CCNetworking sharedNetworking] settingSession:recordMetadata.session sessionTaskIdentifier:[recordMetadata.sessionTaskIdentifierPlist integerValue] taskStatus: k_taskStatusCancel];

                }
                
                // remove file local
                NSLog(@"[LOG] %@", recordMetadata.etag);
                [self deleteLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (etag == %@)", activeAccount, recordMetadata.etag]];
                [recordMetadata MR_deleteEntityInContext:context];
            }
            
            [recordDirectory MR_deleteEntityInContext:context];
            */ 
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

+ (TableDirectory *)getTableDirectoryWithPreficate:(NSPredicate *)predicate
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    
    return [TableDirectory MR_findFirstWithPredicate:predicate inContext:context];
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
    NSString *serverUrlBeginWith = serverUrl;
    
    if (![serverUrl hasSuffix:@"/"])
        serverUrlBeginWith = [serverUrl stringByAppendingString:@"/"];
        
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"((serverUrl == %@) OR (serverUrl BEGINSWITH %@)) AND (account == %@)", serverUrl, serverUrlBeginWith, activeAccount];
    
    return [TableDirectory MR_findAllWithPredicate:predicate];
}

+ (NSString *)getDirectoryIDFromServerUrl:(NSString *)serverUrl activeAccount:(NSString *)activeAccount
{
    if (serverUrl == nil) return nil;
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(serverUrl == %@) AND (account == %@)", serverUrl, activeAccount];
    
    TableDirectory *record = [TableDirectory MR_findFirstWithPredicate:predicate];
    if (record) return record.directoryID;
    else {
        return [self addDirectory:serverUrl permissions:nil activeAccount:activeAccount];
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

+ (void)clearDateReadAccount:(NSString *)activeAccount serverUrl:(NSString *)serverUrl directoryID:(NSString *)directoryID
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        NSPredicate *predicate;
        
        if ([serverUrl length] > 0)
            predicate = [NSPredicate predicateWithFormat:@"(serverUrl == %@) AND (account == %@)", serverUrl, activeAccount];
        
        if ([directoryID length] > 0)
            predicate = [NSPredicate predicateWithFormat:@"(directoryID == %@) AND (account == %@)", directoryID, activeAccount];
        
        TableDirectory *record = [TableDirectory MR_findFirstWithPredicate:predicate inContext:localContext];
        
        if (record) {
            
            record.dateReadDirectory = NULL;
            record.rev = @"";
        }
    }];
}

+ (void)clearAllDateReadDirectory
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        NSArray *records = [TableDirectory MR_findAllInContext:localContext];
        
        for (TableDirectory *record in records) {
            
            record.dateReadDirectory = NULL;
            record.rev = @"";
        }
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
#pragma mark ===== Offline Directory =====
#pragma --------------------------------------------------------------------------------------------

+ (void)removeOfflineDirectoryID:(NSString *)directoryID activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(directoryID == %@) AND (account == %@) AND (offline == 1)", directoryID, activeAccount];
        TableDirectory *record = [TableDirectory MR_findFirstWithPredicate:predicate inContext:localContext];
    
        if (record)
            record.offline = [NSNumber numberWithBool:FALSE];
    }];
}

+ (NSArray *)getOfflineDirectoryActiveAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (offline == 1)", activeAccount];
    NSArray *recordsTable = [TableDirectory MR_findAllWithPredicate:predicate];
    
    // Order by serverUrl
    NSArray *sortedRecordsTable = [recordsTable sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        
        TableDirectory *record1 = obj1, *record2 = obj2;
        
        return [record1.serverUrl compare:record2.serverUrl];
        
    }];
    
    return sortedRecordsTable;
}

+ (void)setOfflineDirectoryServerUrl:(NSString *)serverUrl offline:(BOOL)offline activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(serverUrl == %@) AND (account == %@)", serverUrl, activeAccount];
        TableDirectory *record = [TableDirectory MR_findFirstWithPredicate:predicate inContext:localContext];
    
        if (record)
            record.offline = [NSNumber numberWithBool:offline];
    }];
}

+ (BOOL)isOfflineDirectoryServerUrl:(NSString *)serverUrl activeAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(serverUrl == %@) AND (offline == 1) AND (account == %@)", serverUrl, activeAccount];
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
    /*
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
                    
                    NSString *lockServerUrl = [CCUtility stringAppendServerUrl:serverUrlEntity addFileName:fileNameEntity];
                    
                    BOOL risultato = [self isDirectoryLock:lockServerUrl activeAccount:activeAccount];
                    if (risultato) return YES;
                }
                
            }
        }
    }
    */
    
    return NO;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== LocalFile =====
#pragma --------------------------------------------------------------------------------------------

+ (void)addLocalFile:(tableMetadata *)metadata activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        BOOL offline = NO;
    
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (etag == %@)", activeAccount, metadata.etag];
        TableLocalFile *record = [TableLocalFile MR_findFirstWithPredicate:predicate inContext:localContext];
        
        if (record) {
            
            offline = [[record valueForKey:@"offline"] boolValue];
            
            [record MR_deleteEntityInContext:localContext];
        }
        
        record = [TableLocalFile MR_createEntityInContext:localContext];
        
        record.account = activeAccount;
        record.date = metadata.date;
        record.etag = metadata.etag;
    
        record.exifDate = [NSDate date];
        record.exifLatitude = @"-1";
        record.exifLongitude = @"-1";
        
        record.offline = [NSNumber numberWithBool:offline];
        record.fileName = metadata.fileName;
        record.fileNamePrint = metadata.fileNamePrint;
        record.rev = metadata.rev;
        record.size = [NSNumber numberWithLong:metadata.size];
    }];
}

+ (void)deleteLocalFileWithPredicate:(NSPredicate *)predicate
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        [TableLocalFile MR_deleteAllMatchingPredicate:predicate inContext:localContext];
    }];
}

+ (void)renameLocalFileWithEtag:(NSString *)etag fileNameTo:(NSString *)fileNameTo fileNamePrintTo:(NSString *)fileNamePrintTo activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(etag == %@) AND (account == %@)", etag, activeAccount];
        TableLocalFile *record = [TableLocalFile MR_findFirstWithPredicate:predicate inContext:localContext];
    
        if (record) {
            
            if (fileNameTo)record.fileName = fileNameTo;
            if (fileNamePrintTo)record.fileNamePrint = fileNamePrintTo;
        }
    }];
}

+ (void)updateLocalFileModel:(tableMetadata *)metadata activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (fileName == %@)", activeAccount, metadata.fileName];
        TableLocalFile *record = [TableLocalFile MR_findFirstWithPredicate:predicate inContext:localContext];
    
        if (record) {
            
            record.etag = metadata.etag;
            record.date = metadata.date;
            record.fileNamePrint = metadata.fileNamePrint;
        
        } else {
        
            [self addLocalFile:metadata activeAccount:activeAccount];
        }
    }];
}

+ (TableLocalFile *)getLocalFileWithEtag:(NSString *)etag activeAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(etag == %@) AND (account == %@)", etag, activeAccount];
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
                
                NSString *etag = record.etag;
                NSString *FilePathEtag = [NSString stringWithFormat:@"%@/%@", directoryUser, etag];
                NSString *FilePathFileName = [NSString stringWithFormat:@"%@/%@", directoryUser, record.fileName];
                if (![[NSFileManager defaultManager] fileExistsAtPath:FilePathEtag] && ![[NSFileManager defaultManager] fileExistsAtPath:FilePathFileName] && controlZombie) {
                    
                    // non esiste nè il file etag e nemmeno il plist, eliminiamolo.
                    [self deleteLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"(etag == %@) AND (account == %@)", etag, activeAccount]];
                    
                    
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

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Offline LocalFile =====
#pragma --------------------------------------------------------------------------------------------

+ (void)setOfflineLocalEtag:(NSString *)etag offline:(BOOL)offline activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(etag == %@) AND (account == %@)", etag, activeAccount];
        TableLocalFile *record = [TableLocalFile MR_findFirstWithPredicate:predicate inContext:localContext];
        
        if (record)
            record.offline = [NSNumber numberWithBool:offline];
    }];
}

+ (BOOL)isOfflineLocalEtag:(NSString *)etag activeAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(etag == %@) AND (offline == 1) AND (account == %@)", etag, activeAccount];
    TableLocalFile *record = [TableLocalFile MR_findFirstWithPredicate:predicate];
    
    if (record) return YES;
    else return NO;
}

+ (NSArray *)getOfflineLocalFileActiveAccount:(NSString *)activeAccount directoryUser:(NSString *)directoryUser
{
    NSMutableArray *metadatas = [NSMutableArray new];
    NSArray *files = [self getTableLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (offline == 1)", activeAccount] controlZombie:YES activeAccount:activeAccount directoryUser:directoryUser];
    
    for (TableLocalFile *file in files) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(etag == %@) AND (account == %@)", file.etag, activeAccount];
        //tableMetadata *metadata = [self getMetadataWithPreficate:predicate context:nil];
        
        tableMetadata *metadata =  [[NCManageDatabase sharedInstance] getMetadataWithPreficate:predicate];
        
        if (metadata) {
            
            // verify if is not on directory offline
            
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(directoryID == %@) AND (offline == 1) AND (account == %@)", metadata.directoryID, activeAccount];
            
            TableDirectory *directory = [TableDirectory MR_findFirstWithPredicate:predicate];
            
            if (!directory)
                [metadatas addObject:metadata];
        }
    }

    return metadatas;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== GeoInformation =====
#pragma --------------------------------------------------------------------------------------------

+ (NSArray *)getGeoInformationLocalFromEtag:(NSString *)etag activeAccount:(NSString *)activeAccount
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(etag == %@) AND (account == %@)", etag, activeAccount];
    TableLocalFile *record = [TableLocalFile MR_findFirstWithPredicate:predicate];
    
    if (record) return [[NSArray alloc] initWithObjects:record.exifDate, record.exifLatitude, record.exifLongitude, nil];
    else return nil;
}

+ (void)setGeoInformationLocalFromEtag:(NSString *)etag exifDate:(NSDate *)exifDate exifLatitude:(NSString *)exifLatitude exifLongitude:(NSString *)exifLongitude activeAccount:(NSString *)activeAccount
{
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (etag == %@)", activeAccount, etag];
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
#pragma mark ===== Certificates =====
#pragma --------------------------------------------------------------------------------------------

+ (NSMutableArray *)getAllCertificatesLocationOldDB
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    NSMutableArray *output = [NSMutableArray new];
    
    NSArray *records = [TableCertificates MR_findAllInContext:context];
    
    for (TableCertificates *record in records) {
        
        if (record.certificateLocation && record.certificateLocation.length > 0)
            [output addObject:record.certificateLocation];
        
    }
    
    return output;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Share =====
#pragma --------------------------------------------------------------------------------------------
/*
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

+ (void)updateShare:(NSDictionary *)items sharesLink:(NSMutableDictionary *)sharesLink sharesUserAndGroup:(NSMutableDictionary *)sharesUserAndGroup activeAccount:(NSString *)activeAccount activeUrl:(NSString *)activeUrl
{
    // rimuovi tutte le condivisioni
    [self removeAllShareActiveAccount:activeAccount sharesLink:sharesLink sharesUserAndGroup:sharesUserAndGroup];
    
    NSMutableArray *itemsLink = [[NSMutableArray alloc] init];
    NSMutableArray *itemsUsersAndGroups = [[NSMutableArray alloc] init];
        
    for (NSString *idRemoteShared in items) {
            
        OCSharedDto *item = [items objectForKey:idRemoteShared];
            
        if (item.shareType == shareTypeLink) [itemsLink addObject:item];
        
        if ([[item shareWith] length] > 0 && (item.shareType == shareTypeUser || item.shareType == shareTypeGroup || item.shareType == shareTypeRemote)) [itemsUsersAndGroups addObject:item];
    }
        
    // Link
    for (OCSharedDto *item in itemsLink) {
            
        NSString *fullPath = [[CCUtility getHomeServerUrlActiveUrl:activeUrl] stringByAppendingString:item.path];
            
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
            
        NSString *fullPath = [[CCUtility getHomeServerUrlActiveUrl:activeUrl] stringByAppendingString:path];
            
        NSString *fileName = [fullPath lastPathComponent];
        NSString *serverUrl = [fullPath substringToIndex:([fullPath length]-[fileName length]-1)];
        if ([serverUrl hasSuffix:@"/"]) serverUrl = [serverUrl substringToIndex:[serverUrl length] - 1];
            
        if (share)
            [self setShareUserAndGroup:share fileName:fileName serverUrl:serverUrl sharesUserAndGroup:sharesUserAndGroup activeAccount:activeAccount];
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
*/
#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Offline =====
#pragma --------------------------------------------------------------------------------------------

+ (NSArray *)getHomeOfflineActiveAccount:(NSString *)activeAccount directoryUser:(NSString *)directoryUser fieldOrder:(NSString *)fieldOrder ascending:(BOOL)ascending
{
    NSMutableArray *tableMetadatas = [NSMutableArray new];
    NSArray *directoriesOffline = [self getOfflineDirectoryActiveAccount:activeAccount];
    NSString *father = @"";
    NSSortDescriptor *descriptor;

    // Add directory
    
    for (TableDirectory *directory in directoriesOffline) {
        
        if (![directory.serverUrl containsString:father]) {
            
            father = directory.serverUrl;
            
            NSString *upDir = [CCUtility deletingLastPathComponentFromServerUrl:father];
            NSString *directoryID = [self getDirectoryIDFromServerUrl:upDir activeAccount:activeAccount];
            NSString *fileName = [father lastPathComponent];
            
            if (upDir && directoryID && fileName) {
            
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(directoryID == %@) AND (account == %@) AND (directory == 1) AND (fileNameData == %@)", directoryID, activeAccount, fileName];
                //TableMetadata *tableMetadata = [self getTableMetadataWithPreficate:predicate];
                tableMetadata *metadata =  [[NCManageDatabase sharedInstance] getMetadataWithPreficate:predicate];
                
                if (metadata)
                    [tableMetadatas addObject:metadata];
            }
        }
    }
    
    // Add files
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (offline == 1)", activeAccount];
    NSArray *localFiles = [CCCoreData getTableLocalFileWithPredicate:predicate];
    
    for (TableLocalFile *localFile in localFiles) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (etag == %@)", activeAccount, localFile.etag];
        //TableMetadata *tableMetadata = [self getTableMetadataWithPreficate:predicate];
        tableMetadata *metadata =  [[NCManageDatabase sharedInstance] getMetadataWithPreficate:predicate];
        
        if (metadata)
            [tableMetadatas addObject:metadata];
    }
    
    // Order
    
    if ([fieldOrder isEqualToString:@"fileName"]) descriptor = [[NSSortDescriptor alloc] initWithKey:@"fileNamePrint" ascending:ascending selector:@selector(localizedCaseInsensitiveCompare:)];
    
    else if ([fieldOrder isEqualToString:@"fileDate"]) descriptor = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:ascending selector:nil];
    
    else if ([fieldOrder isEqualToString:@"sessionTaskIdentifier"]) descriptor = [[NSSortDescriptor alloc] initWithKey:@"sessionTaskIdentifier" ascending:ascending selector:nil];
    
    else descriptor = [[NSSortDescriptor alloc] initWithKey:fieldOrder ascending:ascending selector:@selector(localizedCaseInsensitiveCompare:)];

    return [tableMetadatas sortedArrayUsingDescriptors:[NSArray arrayWithObjects:descriptor, nil]];//[NSArray arrayWithArray:tableMetadatas];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== File System =====
#pragma --------------------------------------------------------------------------------------------

+ (BOOL)downloadFile:(tableMetadata *)metadata directoryUser:(NSString *)directoryUser activeAccount:(NSString *)activeAccount
{
    // ----------------------------------------- FILESYSTEM ------------------------------------------
    
    // if encrypted, rewrite
    if (metadata.cryptated == YES)
        if ([[CCCrypto sharedManager] decrypt:metadata.etag fileNameDecrypted:metadata.etag fileNamePrint:metadata.fileNamePrint password:[[CCCrypto sharedManager] getKeyPasscode:metadata.uuid] directoryUser:directoryUser] == 0) return NO;
    
    // ------------------------------------------ COREDATA -------------------------------------------
    
    // add/update Table Local File
    [self addLocalFile:metadata activeAccount:activeAccount];
    
    // EXIF
    if ([metadata.typeFile isEqualToString: k_metadataTypeFile_image])
        [CCExifGeo setExifLocalTableEtag:metadata directoryUser:directoryUser activeAccount:activeAccount];
    
    // Icon
    [CCGraphics createNewImageFrom:metadata.etag directoryUser:directoryUser fileNameTo:metadata.etag fileNamePrint:metadata.fileNamePrint size:@"m" imageForUpload:NO typeFile:metadata.typeFile writePreview:YES optimizedFileName:[CCUtility getOptimizedPhoto]];
    
    return YES;
}

+ (void)downloadFilePlist:(tableMetadata *)metadata activeAccount:(NSString *)activeAccount activeUrl:(NSString *)activeUrl directoryUser:(NSString *)directoryUser
{
    metadata = [[NCManageDatabase sharedInstance] copyTableMetadata:metadata];
    
    [CCUtility insertInformationPlist:metadata directoryUser:directoryUser];    
    [[NCManageDatabase sharedInstance] updateMetadata:metadata activeUrl:activeUrl];
    
    // se è un template aggiorniamo anche nel FileSystem
    if ([metadata.type isEqualToString: k_metadataType_template]){
        [self updateLocalFileModel:metadata activeAccount:activeAccount];
    }
}

+ (void)deleteFile:(tableMetadata *)metadata serverUrl:(NSString *)serverUrl directoryUser:(NSString *)directoryUser activeAccount:(NSString *)activeAccount
{
    if (!metadata) return;
    
    // ----------------------------------------- FILESYSTEM ------------------------------------------
    
    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", directoryUser, metadata.etag] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@.ico", directoryUser, metadata.etag] error:nil];
    
    // ------------------------------------------ DATABASE -------------------------------------------

    // se è una directory cancelliamo tutto quello che è della directory
    if (metadata.directory && serverUrl) {
        
        NSString *dirForDelete = [CCUtility stringAppendServerUrl:serverUrl addFileName:metadata.fileNameData];
        [self deleteDirectoryAndSubDirectory:dirForDelete activeAccount:activeAccount];
    }
    
    [self deleteLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"(etag == %@) AND (account == %@)", metadata.etag, activeAccount]];
    [[NCManageDatabase sharedInstance] deleteMetadata:[NSPredicate predicateWithFormat:@"(etag == %@) AND (account == %@)", metadata.etag, activeAccount]];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Utility Database =====
#pragma --------------------------------------------------------------------------------------------

+ (void)moveCoreDataToGroup
{
    NSString *applicationName = [[[NSBundle mainBundle] infoDictionary] valueForKey:(NSString *)kCFBundleNameKey];
    NSURL *dirGroup = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[NCBrandOptions sharedInstance].capabilitiesGroups];
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

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Flush Database =====
#pragma --------------------------------------------------------------------------------------------

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



+ (void)flushAllDatabase
{
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    
    [TableAccount MR_truncateAllInContext:context];
    [TableDirectory MR_truncateAllInContext:context];
    [TableLocalFile MR_truncateAllInContext:context];
    
    [context MR_saveToPersistentStoreAndWait];
}

@end
