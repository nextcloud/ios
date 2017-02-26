//
//  CCSynchronize.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 19/10/16.
//  Copyright (c) 2016 TWS. All rights reserved.
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

#import "Nextcloud-Swift.h"


@interface CCSynchronize () <CCActionsListingFavoritesDelegate>
{
    // local
}
@end

@implementation CCSynchronize

+ (CCSynchronize *)sharedSynchronize{
    static CCSynchronize *sharedSynchronize;
    @synchronized(self)
    {
        if (!sharedSynchronize) {
            
            sharedSynchronize = [[CCSynchronize alloc] init];
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
    
    // verify is offline procedure is in progress selectorDownloadFavorites
    if ([[app verifyExistsInQueuesDownloadSelector:selectorDownloadFavorites] count] > 0)
        return;
    
    [[CCActions sharedInstance] listingFavorites:@"" delegate:self];
}

- (void)listingFavoritesSuccess:(CCMetadataNet *)metadataNet metadatas:(NSArray *)metadatas
{
    // verify active user
    TableAccount *record = [CCCoreData getActiveAccount];
    
    if (![record.account isEqualToString:metadataNet.account])
        return;
    
    for (CCMetadata *metadata in metadatas) {
        
        // Delete Record NOT in session
        [CCCoreData deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@) AND (fileID = %@) AND ((session == NULL) OR (session == ''))", app.activeAccount, metadata.directoryID, metadata.fileID]];
        
        // type of file
        NSInteger typeFilename = [CCUtility getTypeFileName:metadata.fileName];
        
        // if crypto do not insert
        if (typeFilename == k_metadataTypeFilenameCrypto) continue;
        
        // verify if the record encrypted has plist + crypto
        if (typeFilename == k_metadataTypeFilenamePlist && metadata.directory == NO) {
            
            BOOL isCryptoComplete = NO;
            NSString *fileNameCrypto = [CCUtility trasformedFileNamePlistInCrypto:metadata.fileName];
            
            for (CCMetadata *completeMetadata in metadatas) {
                
                if (completeMetadata.cryptated == NO) continue;
                else  if ([completeMetadata.fileName isEqualToString:fileNameCrypto]) {
                    isCryptoComplete = YES;
                    break;
                }
            }
            if (isCryptoComplete == NO) continue;
        }
        
        // end test, insert in CoreData
        [CCCoreData addMetadata:metadata activeAccount:app.activeAccount activeUrl:app.activeUrl context:nil];
        
        if (metadata.directory) {
            NSString* serverUrl = [CCCoreData getServerUrlFromDirectoryID:metadata.directoryID activeAccount:app.activeAccount];
            [self readFolderServerUrl:serverUrl directoryID:metadata.directoryID];
        } else {
            [self readFile:metadata];
        }
    }
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
    
    // verify is offline procedure is in progress selectorDownloadOffline
    if ([[app verifyExistsInQueuesDownloadSelector:selectorDownloadOffline] count] > 0)
        return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        NSString *father = @"";
        NSArray *directories = [CCCoreData getOfflineDirectoryActiveAccount:app.activeAccount];

        for (TableDirectory *directory in directories) {
        
            if (![directory.serverUrl containsString:father]) {
             
                father = directory.serverUrl;
                [self readFolderServerUrl:directory.serverUrl directoryID:directory.directoryID];
            }
        }
        
        NSArray *metadatas = [CCCoreData getOfflineLocalFileActiveAccount:app.activeAccount directoryUser:app.directoryUser];
        
        for (CCMetadata *metadata in metadatas) {
            
            [self readFile:metadata];
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
    metadataNet.priority = NSOperationQueuePriorityVeryHigh;
    metadataNet.selector = selectorReadFolder;
    metadataNet.serverUrl = serverUrl;
    
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    
    NSLog(@"[LOG] Read offline directory : %@", serverUrl);
}

// Graphics Animation Offline Folders
//
//

- (BOOL)offlineFolderAnimationDirectory:(NSArray *)directory setGraphicsFolder:(BOOL)setGraphicsFolder
{
    BOOL animation = NO;
    BOOL isAtLeastOneInAnimation = NO;
    NSMutableOrderedSet *serversUrlInDownload = [[NSMutableOrderedSet alloc] init];
    
    // Active for download
    NSMutableArray *metadatasNet = [app verifyExistsInQueuesDownloadSelector:selectorDownloadOffline];
    
    for (CCMetadataNet *metadataNet in metadatasNet)
        [serversUrlInDownload addObject:metadataNet.serverUrl];
    
    // Animation ON/OFF
    
    for (NSString *serverUrl in directory) {
        
        animation = [serversUrlInDownload containsObject:serverUrl];
        
        if (animation)
            isAtLeastOneInAnimation = YES;
        
        if (setGraphicsFolder) {
            
            NSString *serverUrlOffline = [CCUtility deletingLastPathComponentFromServerUrl:serverUrl];
            CCMain *viewController = [app.listMainVC objectForKey:serverUrlOffline];
            if (viewController)
                [viewController offlineFolderGraphicsServerUrl:serverUrl animation:animation];
        }
    }
    
    return isAtLeastOneInAnimation;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Read Folder =====
#pragma --------------------------------------------------------------------------------------------

// MULTI THREAD
- (void)readFolderServerUrl:(NSString *)serverUrl directoryID:(NSString *)directoryID
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    
    metadataNet.action = actionReadFolder;
    metadataNet.directoryID = directoryID;
    metadataNet.priority = NSOperationQueuePriorityVeryLow;
    metadataNet.selector = selectorReadFolder;
    metadataNet.serverUrl = serverUrl;
        
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
            
    NSLog(@"[LOG] Read offline directory : %@", serverUrl);
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
- (void)readFolderSuccess:(CCMetadataNet *)metadataNet permissions:(NSString *)permissions metadatas:(NSArray *)metadatas
{
    TableAccount *recordAccount = [CCCoreData getActiveAccount];
    
    __block NSMutableArray *metadatasForOfflineFolder = [[NSMutableArray alloc] init];
    
    if ([recordAccount.account isEqualToString:metadataNet.account] == NO)
        return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        NSArray *recordsInSessions = [CCCoreData getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@) AND (session != NULL) AND (session != '')", app.activeAccount, metadataNet.directoryID] context:nil];
        
        // ----- Test : (DELETE) -----
        
        NSMutableArray *metadatasNotPresents = [[NSMutableArray alloc] init];
        NSArray *tableMetadatasInDB = [CCCoreData getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@) AND ((session == NULL) OR (session == ''))", app.activeAccount, metadataNet.directoryID] context:nil];
        
        for (TableMetadata *tableMetadataDB in tableMetadatasInDB) {
            
            BOOL fileIDFound = NO;
            
            for (CCMetadata *metadata in metadatas) {
                
                if ([tableMetadataDB.fileID isEqualToString:metadata.fileID]) {
                    fileIDFound = YES;
                    break;
                }
            }
            
            if (!fileIDFound)
                [metadatasNotPresents addObject:[CCCoreData insertEntityInMetadata:tableMetadataDB]];
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
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    NSString *dir = [CCUtility stringAppendServerUrl:metadataNet.serverUrl addServerUrl:metadata.fileNameData];
                    
                    [CCCoreData addMetadata:metadata activeAccount:app.activeAccount activeUrl:app.activeUrl context:nil];
                    
                    [[CCSynchronize sharedSynchronize] addOfflineFolder:dir];

                });
                
            } else {
            
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
                [metadatasForOfflineFolder addObject:metadata];
            }
        }
        
        if ([metadatasForOfflineFolder count] > 0)
            [self verifyChangeMedatas:metadatasForOfflineFolder serverUrl:metadataNet.serverUrl account:metadataNet.account offline:YES];
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Read File =====
#pragma --------------------------------------------------------------------------------------------

- (void)readFile:(CCMetadata *)metadata
{
    NSString *serverUrl = [CCCoreData getServerUrlFromDirectoryID:metadata.directoryID activeAccount:app.activeAccount];
    if (serverUrl == nil) return;
        
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
        
    metadataNet.action = actionReadFile;
    metadataNet.fileID = metadata.fileID;
    metadataNet.fileName = metadata.fileName;
    metadataNet.fileNamePrint = metadata.fileNamePrint;
    metadataNet.serverUrl = serverUrl;
    metadataNet.selector = selectorReadFileOffline;
    metadataNet.priority = NSOperationQueuePriorityVeryLow;
        
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
        
        [self verifyChangeMedatas:[[NSArray alloc] initWithObjects:metadata, nil] serverUrl:metadataNet.serverUrl account:app.activeAccount offline:NO];
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Verify Metadatas =====
#pragma --------------------------------------------------------------------------------------------


// MULTI THREAD
- (void)verifyChangeMedatas:(NSArray *)allRecordMetadatas serverUrl:(NSString *)serverUrl account:(NSString *)account offline:(BOOL)offline
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
        
        if (offline) {
            
            if (![record.rev isEqualToString:metadata.rev])
                changeRev = YES;
            
        } else {
            
            if (record && ![record.rev isEqualToString:metadata.rev])
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
            [self SynchronizeMetadatas:metadatas serverUrl:serverUrl offline:offline];
    });
}

// MAIN THREAD
- (void)SynchronizeMetadatas:(NSArray *)metadatas serverUrl:(NSString *)serverUrl offline:(BOOL)offline
{
    // HUD
    if ([metadatas count] > 50 && offline) {
        if (!_hud) _hud = [[CCHud alloc] initWithView:[[[UIApplication sharedApplication] delegate] window]];
        [_hud visibleIndeterminateHud];
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
        
        for (CCMetadata *metadata in metadatas) {
        
            NSString *selector, *selectorPost;
            BOOL downloadData, downloadPlist;
        
            // it's a offline ?
            BOOL isOffline = [CCCoreData isOfflineLocalFileID:metadata.fileID activeAccount:app.activeAccount];
        
            if (isOffline)
                selectorPost = selectorAddOffline;
        
            if ([metadata.type isEqualToString: k_metadataType_file]) {
                downloadData = YES;
                selector = selectorDownloadOffline;
            }
        
            if ([metadata.type isEqualToString: k_metadataType_template]) {
                downloadPlist = YES;
                selector = selectorLoadPlist;
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
    
        [[CCSynchronize sharedSynchronize] offlineFolderAnimationDirectory:[[NSArray alloc] initWithObjects:serverUrl, nil] setGraphicsFolder:YES];
        
        [app.activeMain reloadDatasource:serverUrl fileID:nil selector:nil];
        
        [_hud hideHud];
    });
}


@end
