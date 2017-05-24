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
    NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:serverUrl];
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
        [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@ AND session = ''", metadata.fileID]];
        (void)[[NCManageDatabase sharedInstance] addMetadata:metadata activeUrl:app.activeUrl];
        
        // insert for test NOT favorite
        [filesEtag addObject:metadata.fileID];
        
        // ---- Synchronized ----
        
        // Get ServerUrl
        NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
        serverUrl = [CCUtility stringAppendServerUrl:serverUrl addFileName:metadata.fileNameData];
        
        if (![serverUrl containsString:father]) {
            
            if (metadata.directory) {
                
                NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:serverUrl];
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
    NSArray *allRecordFavorite = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND favorite = true", app.activeAccount] sorted:nil ascending:NO];
    
    for (tableMetadata *metadata in allRecordFavorite)
        if (![filesEtag containsObject:metadata.fileID])
            [[NCManageDatabase sharedInstance] setMetadataFavoriteWithFileID:metadata.fileID favorite:NO];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"clearDateReadDataSource" object:nil];
}

- (void)listingFavoritesFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    NSLog(@"Read Favorites Failure");
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
        
        [[NCManageDatabase sharedInstance] deleteDirectoryAndSubDirectoryWithServerUrl:metadataNet.serverUrl];
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
        
        NSArray *recordsInSessions = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND directoryID = %@ AND session != ''", app.activeAccount, metadataNet.directoryID] sorted:nil ascending:NO];
        
        // ----- Test : (DELETE) -----
        
        NSMutableArray *metadatasNotPresents = [[NSMutableArray alloc] init];
        
        NSArray *tableMetadatas = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND directoryID = %@ AND session = ''", app.activeAccount, metadataNet.directoryID] sorted:nil ascending:NO];
        
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
        
            [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID] error:nil];
            [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID] error:nil];
            
            if (metadata.directory && metadataNet.serverUrl) {
                
                NSString *dirForDelete = [CCUtility stringAppendServerUrl:metadataNet.serverUrl addFileName:metadata.fileNameData];
                
                [[NCManageDatabase sharedInstance] deleteDirectoryAndSubDirectoryWithServerUrl:dirForDelete];
            }
            
            [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", metadata.fileID]];
            [[NCManageDatabase sharedInstance] deleteLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", metadata.fileID]];
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
                NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:serverUrl];
                    
                // Verify if do not exists this Metadata
                tableMetadata *result = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", metadata.fileID]];

                if (!result)
                    (void)[[NCManageDatabase sharedInstance] addMetadata:metadata activeUrl:app.activeUrl];
              
                // Load if different fileID
                
                tableDirectory *tableDirectory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND serverUrl = %@", metadataNet.account, serverUrl]];
                
                if (![tableDirectory.rev isEqualToString:metadata.rev]) {
                    
                    [self readFolderServerUrl:serverUrl directoryID:directoryID selector:metadataNet.selector];
                    
                    [[NCManageDatabase sharedInstance] setDirectoryWithServerUrl:serverUrl serverUrlTo:nil fileID:metadata.rev];                    
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
                    tableMetadata *result = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", metadata.fileID]];

                    if (!result)
                        (void)[[NCManageDatabase sharedInstance] addMetadata:metadata activeUrl:metadataNet.serverUrl];
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
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
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
        
        [[NCManageDatabase sharedInstance] deleteLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", metadataNet.fileID]];
        [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", metadataNet.account, metadataNet.fileID]];
        
        NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadataNet.directoryID];
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
        
        tableLocalFile *localFile = [[NCManageDatabase sharedInstance] getTableLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", metadata.fileID]];
        
        if (withDownload) {
            
            if (![localFile.rev isEqualToString:metadata.rev])
                changeRev = YES;
            
        } else {
            
            if (localFile && ![localFile.rev isEqualToString:metadata.rev]) // it must be in TableRecord
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
            serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
            oldDirectoryID = metadata.directoryID;
            [[NCManageDatabase sharedInstance] clearDateReadWithServerUrl:serverUrl directoryID:nil];
        }
            
        (void)[[NCManageDatabase sharedInstance] addMetadata:metadata activeUrl:serverUrl];
        
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
