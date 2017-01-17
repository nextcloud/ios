//
//  CCOfflineFolder.m
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

#import "CCOfflineFolder.h"

#import "AppDelegate.h"
#import "CCCoreData.h"
#import "CCMain.h"

@interface CCOfflineFolder ()
{
    // local
}
@end

@implementation CCOfflineFolder

+ (CCOfflineFolder *)sharedOfflineFolder {
    static CCOfflineFolder *sharedOfflineFolder;
    @synchronized(self)
    {
        if (!sharedOfflineFolder) {
            
            sharedOfflineFolder = [[CCOfflineFolder alloc] init];
        }
        return sharedOfflineFolder;
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Read Folder Offline =====
#pragma --------------------------------------------------------------------------------------------

- (void)readFolderOffline
{
    if ([app.activeAccount length] == 0)
        return;

    // verify is offline procedure is in progress selectorDownloadOffline
    if ([[app verifyExistsInQueuesDownloadSelector:selectorDownloadOffline] count] > 0)
        return;
    
    NSArray *directories = [CCCoreData getOfflineDirectoryActiveAccount:app.activeAccount];
    
    for (TableDirectory *directory in directories) {
        
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
        
        metadataNet.action = actionReadFolder;
        metadataNet.date = [NSDate date];
        metadataNet.directoryID = directory.directoryID;
        metadataNet.priority = NSOperationQueuePriorityVeryLow;
        metadataNet.selector = selectorOfflineFolder;
        metadataNet.serverUrl = directory.serverUrl;
        
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    }
}

//
// Add - Remove Folder offline
//
- (void)addRemoveOfflineFolder:(NSString *)serverUrl
{
    BOOL offline = [CCCoreData isOfflineDirectory:serverUrl activeAccount:app.activeAccount];
    NSString *directoryID = [CCCoreData getDirectoryIDFromServerUrl:serverUrl activeAccount:app.activeAccount];
    
    if (offline) {
        
        [CCCoreData setOfflineDirectory:serverUrl offline:NO activeAccount:app.activeAccount];
        
    } else {
        
        [CCCoreData setOfflineDirectory:serverUrl offline:YES activeAccount:app.activeAccount];
        
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
        
        metadataNet.action = actionReadFolder;
        metadataNet.directoryID = directoryID;
        metadataNet.priority = NSOperationQueuePriorityVeryHigh;
        metadataNet.selector = selectorReadFolder;
        metadataNet.serverUrl = serverUrl;
        
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Read Folder offline =====
#pragma --------------------------------------------------------------------------------------------

- (void)readFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    // verify active user
    TableAccount *recordAccount = [CCCoreData getActiveAccount];
    
    // Folder not present, remove it
    if (errorCode == 404 && [recordAccount.account isEqualToString:metadataNet.account])
        [CCCoreData deleteDirectoryAndSubDirectory:metadataNet.serverUrl activeAccount:app.activeAccount];
}

// MULTI THREAD
- (void)readFolderSuccess:(CCMetadataNet *)metadataNet permissions:(NSString *)permissions rev:(NSString *)rev metadatas:(NSArray *)metadatas
{
    TableAccount *recordAccount = [CCCoreData getActiveAccount];
    
    __block NSMutableArray *metadatasForOfflineFolder = [[NSMutableArray alloc] init];
    
    if ([recordAccount.account isEqualToString:metadataNet.account] == NO && [metadataNet.selector isEqualToString:selectorOfflineFolder])
        return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        NSArray *recordsInSessions = [CCCoreData getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@) AND (session != NULL) AND (session != '')", app.activeAccount, metadataNet.directoryID] context:nil];
        
        // ----- Test metadata not present (DELETE) -----
        
        NSMutableArray *metadatasNotPresents = [[NSMutableArray alloc] init];
        NSArray *metadatasInDB = [CCCoreData getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@)", app.activeAccount, metadataNet.directoryID] context:nil];
        
        for (CCMetadata *metadataDB in metadatasInDB) {
            
            BOOL fileIDFound = NO;
            
            for (CCMetadata *metadata in metadatas) {
                
                if ([metadataDB.fileID isEqualToString:metadata.fileID]) {
                    fileIDFound = YES;
                    break;
                }
            }
            
            if (!fileIDFound)
                [metadatasNotPresents addObject:metadataDB];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            // delete metadata not present
            for (CCMetadata *metadata in metadatasNotPresents)
                [CCCoreData deleteFile:metadata serverUrl:metadataNet.serverUrl directoryUser:app.directoryUser typeCloud:app.typeCloud activeAccount:app.activeAccount];
            
            [app.activeMain getDataSourceWithReloadTableView:metadataNet.directoryID fileID:nil selector:nil];
            
        });
        
        // ----- Search metadata for test change metadata (MODIFY) -----
        
        for (CCMetadata *metadata in metadatas) {
            
            // no dir
            if (metadata.directory)
                continue;
            
            NSInteger typeFilename = [CCUtility getTypeFileName:metadata.fileName];
            
            // reject crypto
            if (typeFilename == metadataTypeFilenameCrypto) continue;
            
            // Verify if the plist is complited
            if (typeFilename == metadataTypeFilenamePlist) {
                
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
        
            // Error password
            if (metadata.errorPasscode)
                continue;
            
            // Plist not download
            if (metadata.cryptated && [metadata.title length] == 0)
                continue;
            
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
        
        if ([metadatasForOfflineFolder count] > 0)
            [self verifyChangeMedatas:metadatasForOfflineFolder serverUrl:metadataNet.serverUrl directoryID:metadataNet.directoryID account:metadataNet.account offline:YES];
    });
}

// MULTI THREAD
- (void)verifyChangeMedatas:(NSArray *)allRecordMetadatas serverUrl:(NSString *)serverUrl directoryID:(NSString *)directoryID account:(NSString *)account offline:(BOOL)offline
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
            
            if (![record.rev isEqualToString:metadata.rev ])
                changeRev = YES;
            
        } else {
            
            if (record && ![record.rev isEqualToString:metadata.rev ])
                changeRev = YES;
        }
        
        if (changeRev) {
            
            if ([metadata.type isEqualToString:metadataType_file]) {
                
                // remove file and ico
                [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID] error:nil];
                [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID] error:nil];
            }
            
            if ([metadata.type isEqualToString:metadataType_model]) {
                
                // remove model
                [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileName] error:nil];
            }
            
            [metadatas addObject:metadata];
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([metadatas count])
            [self offlineMetadatas:metadatas serverUrl:serverUrl directoryID:directoryID offline:offline];
    });
}

// MAIN THREAD
- (void)offlineMetadatas:(NSArray *)metadatas serverUrl:(NSString *)serverUrl directoryID:(NSString *)directoryID offline:(BOOL)offline
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
            BOOL isOffline = [CCCoreData isOffline:metadata.fileID activeAccount:app.activeAccount];
        
            if (isOffline)
                selectorPost = selectorAddOffline;
        
            if ([metadata.type isEqualToString:metadataType_file]) {
                downloadData = YES;
                selector = selectorDownloadOffline;
            }
        
            if ([metadata.type isEqualToString:metadataType_model]) {
                downloadPlist = YES;
                selector = selectorLoadPlist;
            }
        
            [CCCoreData addMetadata:metadata activeAccount:app.activeAccount activeUrl:serverUrl typeCloud:app.typeCloud context:nil];
        
            CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
            
            metadataNet.action = actionDownloadFile;
            metadataNet.metadata = metadata;
            metadataNet.downloadData = downloadData;
            metadataNet.downloadPlist = downloadPlist;
            metadataNet.selector = selector;
            metadataNet.selectorPost = selectorPost;
            metadataNet.serverUrl = serverUrl;
            metadataNet.session = download_session;
            metadataNet.taskStatus = taskStatusResume;

            [app addNetworkingOperationQueue:app.netQueueDownload delegate:app.activeMain metadataNet:metadataNet];
        }
    
        [[CCOfflineFolder sharedOfflineFolder] offlineFolderAnimationDirectory:[[NSArray alloc] initWithObjects:serverUrl, nil] callViewController:YES];
        
        [app.activeMain getDataSourceWithReloadTableView:directoryID fileID:nil selector:nil];
        
        [_hud hideHud];
    });
}

// Graphics Animation Offline Folders
//
// User return BOOL animation for 1 directory only
//

- (BOOL)offlineFolderAnimationDirectory:(NSArray *)directory callViewController:(BOOL)callViewController
{
    BOOL animation = NO;
    NSMutableOrderedSet *serversUrlInDownload = [[NSMutableOrderedSet alloc] init];
    
    NSMutableArray *metadatasNet = [app verifyExistsInQueuesDownloadSelector:selectorDownloadOffline];
    
    for (CCMetadataNet *metadataNet in metadatasNet)
        [serversUrlInDownload addObject:metadataNet.serverUrl];
    
    /* Animation ON/OFF */
    
    for (NSString *serverUrl in directory) {
        
        animation = [serversUrlInDownload containsObject:serverUrl];
        
        if (callViewController) {
            
            NSString *serverUrlOffline = [CCUtility deletingLastPathComponentFromServerUrl:serverUrl];
            CCMain *viewController = [app.listMainVC objectForKey:serverUrlOffline];
            if (viewController)
                [viewController offlineFolderGraphicsServerUrl:serverUrl animation:animation];
        }
    }
    
    return animation;
}

@end
