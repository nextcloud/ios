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
    tableAccount *record = [[NCManageDatabase sharedInstance] getAccountActive];
    
    if (![record.account isEqualToString:metadataNet.account])
        return;
    
    NSString *father = @"";
    NSMutableArray *filesEtag = [NSMutableArray new];
    
    for (tableMetadata *metadata in metadatas) {
        
        // type of file
        NSInteger typeFilename = [CCUtility getTypeFileName:metadata.fileName];
        
        // do not insert cryptated favorite file
        if (typeFilename == k_metadataTypeFilenameCrypto || typeFilename == k_metadataTypeFilenamePlist)
            continue;

        // Reinsert
        [[NCManageDatabase sharedInstance] deleteMetadata:[NSPredicate predicateWithFormat:@"fileID = %@ AND session = ''", metadata.fileID]];
        [[NCManageDatabase sharedInstance] addMetadata:metadata activeUrl:app.activeUrl];
        
        // insert for test NOT favorite
        [filesEtag addObject:metadata.fileID];
        
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
    NSArray *allRecordFavorite = [[NCManageDatabase sharedInstance] getMetadatasWithPreficate:[NSPredicate predicateWithFormat:@"account = %@ AND favorite == 1", app.activeAccount] sorted:nil ascending:NO];
    
    for (tableMetadata *metadata in allRecordFavorite)
        if (![filesEtag containsObject:metadata.fileID])
            [[NCManageDatabase sharedInstance] setMetadataFavorite:metadata.fileID favorite:NO];
    
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
        
        for (tableMetadata *metadata in metadatas) {
            
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

- (void)readFolderServerUrl:(NSString *)serverUrl directoryID:(NSString *)directoryID selector:(NSString *)selector
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    
    metadataNet.action = actionReadFolder;
    metadataNet.directoryID = directoryID;
    metadataNet.priority = NSOperationQueuePriorityNormal;
    metadataNet.selector = selector;
    metadataNet.serverUrl = serverUrl;
    
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    
    NSLog(@"[LOG] %@ directory : %@", selector, serverUrl);
}

- (void)readFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    // verify active user
    tableAccount *recordAccount = [[NCManageDatabase sharedInstance] getAccountActive];
    
    // Folder not present, remove it
    if (errorCode == 404 && [recordAccount.account isEqualToString:metadataNet.account]) {
        [CCCoreData deleteDirectoryAndSubDirectory:metadataNet.serverUrl activeAccount:app.activeAccount];
        [app.activeMain reloadDatasource:metadataNet.serverUrl fileID:nil selector:nil];
    }
}

// MULTI THREAD
- (void)readFolderSuccess:(CCMetadataNet *)metadataNet permissions:(NSString *)permissions fileID:(NSString *)fileID metadatas:(NSArray *)metadatas
{
    tableAccount *recordAccount = [[NCManageDatabase sharedInstance] getAccountActive];
    
    __block NSMutableArray *metadatasForVerifyChange = [NSMutableArray new];
    
    if ([recordAccount.account isEqualToString:metadataNet.account] == NO)
        return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        NSArray *recordsInSessions = [[NCManageDatabase sharedInstance] getMetadatasWithPreficate:[NSPredicate predicateWithFormat:@"account = %@ AND directoryID = %@ AND session != ''", app.activeAccount, metadataNet.directoryID] sorted:nil ascending:NO];
        
        // ----- Test : (DELETE) -----
        
        NSMutableArray *metadatasNotPresents = [[NSMutableArray alloc] init];
        
        NSArray *tableMetadatas = [[NCManageDatabase sharedInstance] getMetadatasWithPreficate:[NSPredicate predicateWithFormat:@"account = %@ AND directoryID = %@ AND session = ''", app.activeAccount, metadataNet.directoryID] sorted:nil ascending:NO];
        
        for (tableMetadata *record in tableMetadatas) {
            
            // reject cryptated
            if (record.cryptated)
                continue;
            
            BOOL fileIDFound = NO;
            
            for (tableMetadata *metadata in metadatas) {
                
                if ([record.fileID isEqualToString:metadata.fileID]) {
                    fileIDFound = YES;
                    break;
                }
            }
            
            if (!fileIDFound)
                [metadatasNotPresents addObject:record];
        }
        
        // delete metadata not present
        for (tableMetadata *metadata in metadatasNotPresents) {
        
            [CCCoreData deleteFile:metadata serverUrl:metadataNet.serverUrl directoryUser:app.directoryUser activeAccount:app.activeAccount];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([metadatasNotPresents count] > 0)
                [app.activeMain reloadDatasource:metadataNet.serverUrl fileID:nil selector:nil];
        });
        
        // ----- Test : (MODIFY) -----
        
        for (tableMetadata *metadata in metadatas) {
            
            // reject cryptated
            if (metadata.cryptated)
                continue;
            
            // dir recursive
            if (metadata.directory) {
                
                NSString *serverUrl = [CCUtility stringAppendServerUrl:metadataNet.serverUrl addFileName:metadata.fileNameData];
                NSString *directoryID = [CCCoreData getDirectoryIDFromServerUrl:serverUrl activeAccount:app.activeAccount];
                    
                // Verify if do not exists this Metadata
                tableMetadata *result = [[NCManageDatabase sharedInstance] getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(account == %@) AND (fileID == %@)", metadataNet.account, metadata.fileID]];

                if (!result)
                    [[NCManageDatabase sharedInstance] addMetadata:metadata activeUrl:app.activeUrl];
              
                // Load if different fileID
                
                TableDirectory *tableDirectory = [CCCoreData getTableDirectoryWithPreficate:[NSPredicate predicateWithFormat:@"(account == %@) AND (serverUrl == %@)", metadataNet.account, serverUrl]];
                
                if (![tableDirectory.rev isEqualToString:metadata.rev]) {
                    
                    [self readFolderServerUrl:serverUrl directoryID:directoryID selector:metadataNet.selector];
                    [CCCoreData updateDirectoryEtagServerUrl:serverUrl fileID:metadata.rev activeAccount:metadataNet.account];
                }
                
            } else {
            
                if ([metadataNet.selector isEqualToString:selectorReadFolderWithDownload]) {
                    
                    // It's in session
                    BOOL recordInSession = NO;
                    for (tableMetadata *record in recordsInSessions) {
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
                    tableMetadata *result = [[NCManageDatabase sharedInstance] getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(account == %@) AND (fileID == %@)", metadataNet.account, metadata.fileID]];

                    if (!result)
                        [[NCManageDatabase sharedInstance] addMetadata:metadata activeUrl:metadataNet.serverUrl];
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

- (void)readFile:(tableMetadata *)metadata withDownload:(BOOL)withDownload
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
    tableAccount *recordAccount = [[NCManageDatabase sharedInstance] getAccountActive];
    
    // File not present, remove it
    if (errorCode == 404 && [recordAccount.account isEqualToString:metadataNet.account]) {
        
        [CCCoreData deleteLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (fileID == %@)", metadataNet.account, metadataNet.fileID]];
        [[NCManageDatabase sharedInstance] deleteMetadata:[NSPredicate predicateWithFormat:@"fileID == %@", metadataNet.account, metadataNet.fileID]];
        
        NSString* serverUrl = [CCCoreData getServerUrlFromDirectoryID:metadataNet.directoryID activeAccount:app.activeAccount];
        [app.activeMain reloadDatasource:serverUrl fileID:nil selector:nil];
    }
}

- (void)readFileSuccess:(CCMetadataNet *)metadataNet metadata:(tableMetadata *)metadata
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
    
    for (tableMetadata *metadata in allRecordMetadatas) {
        
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
    
    if ([metadatas count])
        [self SynchronizeMetadatas:metadatas withDownload:withDownload];
}

// MULTI THREAD
- (void)SynchronizeMetadatas:(NSArray *)metadatas withDownload:(BOOL)withDownload
{
    NSString *oldDirectoryID, *serverUrl;

    for (tableMetadata *metadata in metadatas) {
        
        NSString *selector, *selectorPost;
        BOOL downloadData = NO, downloadPlist = NO;
        
        // it's a offline ?
        BOOL isOffline = [CCCoreData isOfflineLocalEtag:metadata.fileID activeAccount:app.activeAccount];
        
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
            
        [[NCManageDatabase sharedInstance] addMetadata:metadata activeUrl:serverUrl];
        
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
            
        metadataNet.action = actionDownloadFile;
        metadataNet.downloadData = downloadData;
        metadataNet.downloadPlist = downloadPlist;
        metadataNet.fileID = metadata.fileID;
        metadataNet.selector = selector;
        metadataNet.selectorPost = selectorPost;
        metadataNet.serverUrl = serverUrl;
        metadataNet.session = k_download_session;
        metadataNet.taskStatus = k_taskStatusResume;

        [app addNetworkingOperationQueue:app.netQueueDownload delegate:app.activeMain metadataNet:metadataNet];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [app.activeMain reloadDatasource:serverUrl fileID:nil selector:nil];
    });
}

@end
