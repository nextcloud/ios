//
//  CCSynchronize.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 19/10/16.
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

#import "CCSynchronize.h"
#import "AppDelegate.h"
#import "CCCoreData.h"
#import "CCMain.h"
#import "NCBridgeSwift.h"

@interface CCSynchronize () <CCActionsListingFavoritesDelegate>
{
    // local
}
@end

@implementation CCSynchronize

+ (CCSynchronize *)sharedSynchronize {
    
    static CCSynchronize *sharedSynchronize;
    
    @synchronized(self)
    {
        if (!sharedSynchronize) {
            
            sharedSynchronize = [CCSynchronize new];
            
            sharedSynchronize.foldersInSynchronized = [NSMutableOrderedSet new];
        }
        return sharedSynchronize;
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Read Listing Favorites =====
#pragma --------------------------------------------------------------------------------------------

- (void)readListingFavorites
{
    // test
    if (app.activeAccount.length == 0)
        return;
    
    // verify is offline procedure is in progress selectorDownloadSynchronize
    if ([[app verifyExistsInQueuesDownloadSelector:selectorDownloadSynchronize] count] > 0)
        return;
    
    [[CCActions sharedInstance] listingFavorites:@"" delegate:self];
}

- (void)addFavoriteFolder:(NSString *)serverUrl
{
    NSString *directoryID = [CCCoreData getDirectoryIDFromServerUrl:serverUrl activeAccount:app.activeAccount];
    NSString *selector;
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    
    metadataNet.action = actionReadFolder;
    metadataNet.directoryID = directoryID;
    metadataNet.priority = NSOperationQueuePriorityNormal;
    
    if ([CCUtility getFavoriteOffline])
        selector = selectorReadFolderWithDownload;
    else
        selector = selectorReadFolder;
    
    metadataNet.selector = selector;
    metadataNet.serverUrl = serverUrl;
    
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
}

- (void)listingFavoritesSuccess:(CCMetadataNet *)metadataNet metadatas:(NSArray *)metadatas
{
    // verify active user
    TableAccount *record = [CCCoreData getActiveAccount];
    
    if (![record.account isEqualToString:metadataNet.account])
        return;
    
    NSString *father = @"";
    NSMutableArray *filesID = [NSMutableArray new];
    
    for (CCMetadata *metadata in metadatas) {
        
        // type of file
        NSInteger typeFilename = [CCUtility getTypeFileName:metadata.fileName];
        
        // do not insert cryptated favorite file
        if (typeFilename == k_metadataTypeFilenameCrypto || typeFilename == k_metadataTypeFilenamePlist)
            continue;

        // Delete Record NOT in session
        [CCCoreData deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@) AND (fileID = %@) AND ((session == NULL) OR (session == ''))", app.activeAccount, metadata.directoryID, metadata.fileID]];
        
        // end test, insert in CoreData
        [CCCoreData addMetadata:metadata activeAccount:app.activeAccount activeUrl:app.activeUrl context:nil];
        
        // insert for test NOT favorite
        [filesID addObject:metadata.fileID];
        
        // ---- Synchronized ----
        
        // Get ServerUrl
        NSString* serverUrl = [CCCoreData getServerUrlFromDirectoryID:metadata.directoryID activeAccount:app.activeAccount];
        serverUrl = [CCUtility stringAppendServerUrl:serverUrl addFileName:metadata.fileNameData];
        
        if (![serverUrl containsString:father]) {
            
            if (metadata.directory) {
                
                NSString *directoryID = [CCCoreData getDirectoryIDFromServerUrl:serverUrl activeAccount:app.activeAccount];
                NSString *selector;
                
                if ([CCUtility getFavoriteOffline])
                    selector = selectorReadFolderWithDownload;
                else
                    selector = selectorReadFolder;
                
                [self readFolderServerUrl:serverUrl directoryID:directoryID selector:selector];
                
            } else {
                
                if ([CCUtility getFavoriteOffline])
                    [self readFile:metadata withDownload:YES];
                else
                    [self readFile:metadata withDownload:NO];
            }
            
            father = serverUrl;
        }
    }
    
    // Verify remove favorite
    NSArray *allRecordFavorite = [CCCoreData getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (favorite == 1)", app.activeAccount] context:nil];
    
    for (TableMetadata *tableMetadata in allRecordFavorite)
        if (![filesID containsObject:tableMetadata.fileID])
            [CCCoreData setMetadataFavoriteFileID:tableMetadata.fileID favorite:NO activeAccount:app.activeAccount context:nil];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"clearDateReadDataSource" object:nil];
}

- (void)listingFavoritesFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Read Offline =====
#pragma --------------------------------------------------------------------------------------------

- (void)readOffline
{
    // test
    if (app.activeAccount.length == 0)
        return;
    
    // verify is offline procedure is in progress selectorDownloadSynchronize
    if ([[app verifyExistsInQueuesDownloadSelector:selectorDownloadSynchronize] count] > 0)
        return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        NSString *father = @"";
        NSArray *directories = [CCCoreData getOfflineDirectoryActiveAccount:app.activeAccount];

        for (TableDirectory *directory in directories) {
        
            if (![directory.serverUrl containsString:father]) {
             
                father = directory.serverUrl;
                [self readFolderServerUrl:directory.serverUrl directoryID:directory.directoryID selector:selectorReadFolder];
            }
        }
        
        NSArray *metadatas = [CCCoreData getOfflineLocalFileActiveAccount:app.activeAccount directoryUser:app.directoryUser];
        
        for (CCMetadata *metadata in metadatas) {
            
            [self readFile:metadata withDownload:YES];
        }
    });
}

//
// Add Folder offline
//
- (void)addOfflineFolder:(NSString *)serverUrl
{
    NSString *directoryID = [CCCoreData getDirectoryIDFromServerUrl:serverUrl activeAccount:app.activeAccount];
    
    // Set offline directory
    [CCCoreData setOfflineDirectoryServerUrl:serverUrl offline:YES activeAccount:app.activeAccount];
    
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    
    metadataNet.action = actionReadFolder;
    metadataNet.directoryID = directoryID;
    metadataNet.priority = NSOperationQueuePriorityNormal;
    metadataNet.selector = selectorReadFolder;
    metadataNet.serverUrl = serverUrl;
    
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];    
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Read Folder =====
#pragma --------------------------------------------------------------------------------------------

// MULTI THREAD
- (void)readFolderServerUrl:(NSString *)serverUrl directoryID:(NSString *)directoryID selector:(NSString *)selector
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    
    metadataNet.action = actionReadFolder;
    metadataNet.directoryID = directoryID;
    metadataNet.priority = NSOperationQueuePriorityNormal;
    metadataNet.selector = selector;
    metadataNet.serverUrl = serverUrl;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    });
    
    NSLog(@"[LOG] %@ directory : %@", selector, serverUrl);
}

- (void)readFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    // verify active user
    TableAccount *recordAccount = [CCCoreData getActiveAccount];
    
    // Folder not present, remove it
    if (errorCode == 404 && [recordAccount.account isEqualToString:metadataNet.account])
        [CCCoreData deleteDirectoryAndSubDirectory:metadataNet.serverUrl activeAccount:app.activeAccount];
}

// MULTI THREAD
- (void)readFolderSuccess:(CCMetadataNet *)metadataNet permissions:(NSString *)permissions etag:(NSString *)etag metadatas:(NSArray *)metadatas
{
    TableAccount *recordAccount = [CCCoreData getActiveAccount];
    
    __block NSMutableArray *metadatasForVerifyChange = [NSMutableArray new];
    
    if ([recordAccount.account isEqualToString:metadataNet.account] == NO)
        return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        NSArray *recordsInSessions = [CCCoreData getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@) AND (session != NULL) AND (session != '')", app.activeAccount, metadataNet.directoryID] context:nil];
        
        // ----- Test : (DELETE) -----
        
        NSMutableArray *metadatasNotPresents = [[NSMutableArray alloc] init];
        NSArray *tableMetadatas = [CCCoreData getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@) AND ((session == NULL) OR (session == ''))", app.activeAccount, metadataNet.directoryID] context:nil];
        
        for (TableMetadata *tableMetadata in tableMetadatas) {
            
            // reject cryptated
            if (tableMetadata.cryptated)
                continue;
            
            BOOL fileIDFound = NO;
            
            for (CCMetadata *metadata in metadatas) {
                
                if ([tableMetadata.fileID isEqualToString:metadata.fileID]) {
                    fileIDFound = YES;
                    break;
                }
            }
            
            if (!fileIDFound)
                [metadatasNotPresents addObject:[CCCoreData insertEntityInMetadata:tableMetadata]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            // delete metadata not present
            for (CCMetadata *metadata in metadatasNotPresents) {
                
                [CCCoreData deleteFile:metadata serverUrl:metadataNet.serverUrl directoryUser:app.directoryUser activeAccount:app.activeAccount];
            }
            
            if ([metadatasNotPresents count] > 0)
                [app.activeMain reloadDatasource:metadataNet.serverUrl fileID:nil selector:nil];
        });
        
        // ----- Test : (MODIFY) -----
        
        for (CCMetadata *metadata in metadatas) {
            
            // reject cryptated
            if (metadata.cryptated)
                continue;
            
            // dir recursive
            if (metadata.directory) {
                
                NSString *serverUrl = [CCUtility stringAppendServerUrl:metadataNet.serverUrl addFileName:metadata.fileNameData];
                NSString *directoryID = [CCCoreData getDirectoryIDFromServerUrl:serverUrl activeAccount:app.activeAccount];
                    
                // Verify if do not exists this Metadata
                if (![CCCoreData getTableMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(account == %@) AND (fileID == %@)", metadataNet.account, metadata.fileID]]) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [CCCoreData addMetadata:metadata activeAccount:app.activeAccount activeUrl:app.activeUrl context:nil];
                    });
                }
              
                // Load if different etag
                
                TableDirectory *tableDirectory = [CCCoreData getTableDirectoryWithPreficate:[NSPredicate predicateWithFormat:@"(account == %@) AND (serverUrl == %@)", metadataNet.account, serverUrl]];
                
                if (![tableDirectory.rev isEqualToString:metadata.rev]) {
                    
                    [self readFolderServerUrl:serverUrl directoryID:directoryID selector:metadataNet.selector];
                    [CCCoreData updateDirectoryEtagServerUrl:serverUrl etag:metadata.rev activeAccount:metadataNet.account];
                }
                
            } else {
            
                if ([metadataNet.selector isEqualToString:selectorReadFolderWithDownload]) {
                    
                    // It's in session
                    BOOL recordInSession = NO;
                    for (TableMetadata *record in recordsInSessions) {
                        if ([record.fileID isEqualToString:metadata.fileID]) {
                            recordInSession = YES;
                            break;
                        }
                    }
                    
                    if (recordInSession)
                        continue;
            
                    // Ohhhh INSERT
                    [metadatasForVerifyChange addObject:metadata];
                }
                
                if ([metadataNet.selector isEqualToString:selectorReadFolder]) {
                    
                    // Verify if do not exists this Metadata
                    if (![CCCoreData getTableMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(account == %@) AND (fileID == %@)", metadataNet.account, metadata.fileID]]) {
                    
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [CCCoreData addMetadata:metadata activeAccount:metadataNet.account activeUrl:metadataNet.serverUrl context:nil];
                        });
                    }
                }
            }
        }
        
        if ([metadatasForVerifyChange count] > 0)
            [self verifyChangeMedatas:metadatasForVerifyChange serverUrl:metadataNet.serverUrl account:metadataNet.account withDownload:YES];
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Read File =====
#pragma --------------------------------------------------------------------------------------------

- (void)readFile:(CCMetadata *)metadata withDownload:(BOOL)withDownload
{
    NSString *serverUrl = [CCCoreData getServerUrlFromDirectoryID:metadata.directoryID activeAccount:app.activeAccount];
    if (serverUrl == nil) return;
        
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
        
    metadataNet.action = actionReadFile;
    metadataNet.fileID = metadata.fileID;
    metadataNet.fileName = metadata.fileName;
    metadataNet.fileNamePrint = metadata.fileNamePrint;
    metadataNet.options = [NSNumber numberWithBool:withDownload] ;
    metadataNet.priority = NSOperationQueuePriorityLow;
    metadataNet.selector = selectorReadFile;
    metadataNet.serverUrl = serverUrl;
    
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
}

- (void)readFileFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    // verify active user
    TableAccount *recordAccount = [CCCoreData getActiveAccount];
    
    // File not present, remove it
    if (errorCode == 404 && [recordAccount.account isEqualToString:metadataNet.account]) {
        [CCCoreData deleteLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (fileID == %@)", metadataNet.account, metadataNet.fileID]];
        [CCCoreData deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (fileID == %@)", metadataNet.account, metadataNet.fileID]];
    }
}

- (void)readFileSuccess:(CCMetadataNet *)metadataNet metadata:(CCMetadata *)metadata
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        BOOL withDownload = [metadataNet.options boolValue];
        
        [self verifyChangeMedatas:[[NSArray alloc] initWithObjects:metadata, nil] serverUrl:metadataNet.serverUrl account:app.activeAccount withDownload:withDownload];
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Verify Metadatas =====
#pragma --------------------------------------------------------------------------------------------

// MULTI THREAD
- (void)verifyChangeMedatas:(NSArray *)allRecordMetadatas serverUrl:(NSString *)serverUrl account:(NSString *)account withDownload:(BOOL)withDownload
{
    NSMutableArray *metadatas = [[NSMutableArray alloc] init];
    
    for (CCMetadata *metadata in allRecordMetadatas) {
        
        BOOL changeRev = NO;
        
        // change account
        if ([metadata.account isEqualToString:account] == NO)
            return;
        
        // no dir
        if (metadata.directory)
            continue;
        
        TableLocalFile *record = [TableLocalFile MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (fileID == %@)", app.activeAccount, metadata.fileID]];
        
        if (withDownload) {
            
            if (![record.rev isEqualToString:metadata.rev])
                changeRev = YES;
            
        } else {
            
            if (record && ![record.rev isEqualToString:metadata.rev]) // it must be in TableRecord
                changeRev = YES;
        }
        
        if (changeRev) {
            
            if ([metadata.type isEqualToString: k_metadataType_file]) {
                
                // remove file and ico
                [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID] error:nil];
                [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID] error:nil];
            }
            
            if ([metadata.type isEqualToString: k_metadataType_template]) {
                
                // remove model
                [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileName] error:nil];
            }
            
            [metadatas addObject:metadata];
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([metadatas count])
            [self SynchronizeMetadatas:metadatas serverUrl:serverUrl withDownload:withDownload];
    });
}

// MAIN THREAD
- (void)SynchronizeMetadatas:(NSArray *)metadatas serverUrl:(NSString *)serverUrl withDownload:(BOOL)withDownload
{
    // HUD
    if ([metadatas count] > 50 && withDownload) {
        if (!_hud) _hud = [[CCHud alloc] initWithView:[[[UIApplication sharedApplication] delegate] window]];
        [_hud visibleIndeterminateHud];
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
        
        NSString *oldDirectoryID, *serverUrl;

        for (CCMetadata *metadata in metadatas) {
        
            NSString *selector, *selectorPost;
            BOOL downloadData = NO, downloadPlist = NO;
        
            // it's a offline ?
            BOOL isOffline = [CCCoreData isOfflineLocalFileID:metadata.fileID activeAccount:app.activeAccount];
        
            if (isOffline)
                selectorPost = selectorAddOffline;
        
            if ([metadata.type isEqualToString: k_metadataType_file]) {
                downloadData = YES;
                selector = selectorDownloadSynchronize;
            }
        
            if ([metadata.type isEqualToString: k_metadataType_template]) {
                downloadPlist = YES;
                selector = selectorLoadPlist;
            }
            
            // Clear date for dorce refresh view
            if (![oldDirectoryID isEqualToString:metadata.directoryID]) {
                serverUrl = [CCCoreData getServerUrlFromDirectoryID:metadata.directoryID activeAccount:app.activeAccount];
                oldDirectoryID = metadata.directoryID;
                [CCCoreData clearDateReadAccount:app.activeAccount serverUrl:serverUrl directoryID:nil];
            }
            
            [CCCoreData addMetadata:metadata activeAccount:app.activeAccount activeUrl:serverUrl context:nil];
        
            CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
            
            metadataNet.action = actionDownloadFile;
            metadataNet.metadata = metadata;
            metadataNet.downloadData = downloadData;
            metadataNet.downloadPlist = downloadPlist;
            metadataNet.selector = selector;
            metadataNet.selectorPost = selectorPost;
            metadataNet.serverUrl = serverUrl;
            metadataNet.session = k_download_session;
            metadataNet.taskStatus = k_taskStatusResume;

            [app addNetworkingOperationQueue:app.netQueueDownload delegate:app.activeMain metadataNet:metadataNet];
        }
        
        [app.activeMain reloadDatasource:serverUrl fileID:nil selector:nil];
        
        [_hud hideHud];
    });
}

@end
