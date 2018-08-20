//
//  CCSynchronize.m
//  Nextcloud iOS
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

@interface CCSynchronize () 
{
    AppDelegate *appDelegate;
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
            sharedSynchronize->appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        }
        return sharedSynchronize;
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Read Folder =====
#pragma --------------------------------------------------------------------------------------------

// serverUrl    : start
// directoryID  : start
// selector     : selectorReadFolder, selectorReadFolderWithDownload
//

- (void)readFolder:(NSString *)serverUrl selector:(NSString *)selector
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:appDelegate.activeAccount];
    
    metadataNet.action = actionReadFolder;
    NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:serverUrl];
    if (!directoryID) return;
    
    metadataNet.depth = @"1";
    metadataNet.directoryID = directoryID;
    metadataNet.priority = NSOperationQueuePriorityLow;
    metadataNet.selector = selector;
    metadataNet.serverUrl = serverUrl;
    
    [appDelegate addNetworkingOperationQueue:appDelegate.netQueue delegate:self metadataNet:metadataNet];
    
    NSLog(@"[LOG] %@ directory : %@", selector, serverUrl);
}

// MULTI THREAD
- (void)readFolderSuccessFailure:(CCMetadataNet *)metadataNet metadataFolder:(tableMetadata *)metadataFolder metadatas:(NSArray *)metadatas message:(NSString *)message errorCode:(NSInteger)errorCode
{
    // Check Active Account
    if (![metadataNet.account isEqualToString:appDelegate.activeAccount])
        return;
    
    // ERROR
    if (errorCode != 0) {
        
        // Folder not present, remove it
        if (errorCode == 404) {
            
            [[NCManageDatabase sharedInstance] deleteDirectoryAndSubDirectoryWithServerUrl:metadataNet.serverUrl];
            [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:metadataNet.serverUrl fileID:nil action:k_action_NULL];
        }
        
        return;
    }
    
    // Add/update self Folder
    if (!metadataFolder || !metadatas || [metadatas count] == 0)
        return;
    
    // Add metadata and update etag Directory
    (void)[[NCManageDatabase sharedInstance] addMetadata:metadataFolder];
    [[NCManageDatabase sharedInstance] setDirectoryWithServerUrl:metadataNet.serverUrl serverUrlTo:nil etag:metadataFolder.etag fileID:metadataFolder.fileID encrypted:metadataFolder.e2eEncrypted];

    // reload folder ../ *
    NSString *serverUrlParent = [[NCManageDatabase sharedInstance] getServerUrl:metadataFolder.directoryID];
    if (serverUrlParent) {
        [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:serverUrlParent fileID:nil action:k_action_NULL];
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        NSMutableArray *metadatasForVerifyChange = [NSMutableArray new];
        NSMutableArray *addMetadatas = [NSMutableArray new];
    
        NSArray *recordsInSessions = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"directoryID == %@ AND session != ''", metadataNet.directoryID] sorted:nil ascending:NO];
        
        // ----- Test : (DELETE) -----
        
        NSMutableArray *metadatasNotPresents = [NSMutableArray new];
        
        NSArray *tableMetadatas = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"directoryID == %@ AND session == ''", metadataNet.directoryID] sorted:nil ascending:NO];
        
        for (tableMetadata *record in tableMetadatas) {
            
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
        
            [[NSFileManager defaultManager] removeItemAtPath:[CCUtility getDirectoryProviderStorageFileID:metadata.fileID] error:nil];
            
            if (metadata.directory && metadataNet.serverUrl) {
                
                NSString *dirForDelete = [CCUtility stringAppendServerUrl:metadataNet.serverUrl addFileName:metadata.fileName];
                
                [[NCManageDatabase sharedInstance] deleteDirectoryAndSubDirectoryWithServerUrl:dirForDelete];
            }
            
            [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID] clearDateReadDirectoryID:nil];
            [[NCManageDatabase sharedInstance] deleteLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID]];
            [[NCManageDatabase sharedInstance] deletePhotosWithFileID:metadata.fileID];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([metadatasNotPresents count] > 0)
                [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:metadataNet.serverUrl fileID:nil action:k_action_NULL];
        });
        
        // ----- Test : (MODIFY) -----
        
        for (tableMetadata *metadata in metadatas) {
            
            // RECURSIVE DIRECTORY MODE
            if (metadata.directory) {
                
                NSString *serverUrl = [CCUtility stringAppendServerUrl:metadataNet.serverUrl addFileName:metadata.fileName];
                
                // Verify if do not exists this Metadata
                tableMetadata *result = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID]];

                if (!result)
                    (void)[[NCManageDatabase sharedInstance] addMetadata:metadata];
              
                    // Load if different etag
                    //tableDirectory *tableDirectory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", metadataNet.account, serverUrl]];
                
                    //if (![tableDirectory.etag isEqualToString:metadata.etag] || [metadataNet.selector isEqualToString:selectorReadFolderWithDownload]) {
                                        
                    //    [self readFolder:serverUrl selector:metadataNet.selector];
                    //}
                
                [self readFolder:serverUrl selector:metadataNet.selector];
                    
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
                    tableMetadata *result = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID]];

                    if (!result)
                        [addMetadatas addObject:metadata];
                }
            }
        }
        
        if ([addMetadatas count] > 0)
            (void)[[NCManageDatabase sharedInstance] addMetadatas:addMetadatas serverUrl:metadataNet.serverUrl];
        
        if ([metadatasForVerifyChange count] > 0)
            [self verifyChangeMedatas:metadatasForVerifyChange serverUrl:metadataNet.serverUrl account:metadataNet.account withDownload:YES];
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Read File for Folder & Read File=====
#pragma --------------------------------------------------------------------------------------------

- (void)readFileForFolder:(NSString *)fileName serverUrl:(NSString *)serverUrl selector:(NSString *)selector
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:appDelegate.activeAccount];
    
    metadataNet.action = actionReadFile;
    metadataNet.fileName = fileName;
    metadataNet.priority = NSOperationQueuePriorityLow;
    metadataNet.selector = selector;
    metadataNet.serverUrl = serverUrl;
    
    [appDelegate addNetworkingOperationQueue:appDelegate.netQueue delegate:self metadataNet:metadataNet];
}

- (void)readFile:(tableMetadata *)metadata selector:(NSString *)selector
{
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
    if (!serverUrl) return;
        
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:appDelegate.activeAccount];
        
    metadataNet.action = actionReadFile;
    metadataNet.fileID = metadata.fileID;
    metadataNet.fileName = metadata.fileName;
    metadataNet.priority = NSOperationQueuePriorityLow;
    metadataNet.selector = selector;
    metadataNet.serverUrl = serverUrl;
    
    [appDelegate addNetworkingOperationQueue:appDelegate.netQueue delegate:self metadataNet:metadataNet];
}

- (void)readFileSuccessFailure:(CCMetadataNet *)metadataNet metadata:(tableMetadata *)metadata message:(NSString *)message errorCode:(NSInteger)errorCode
{
    // Check Active Account
    if (![metadataNet.account isEqualToString:appDelegate.activeAccount])
        return;
    
    if (errorCode == 0) {
    
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            
            // Selector : selectorReadFile, selectorReadFileWithDownload
            if ([metadataNet.selector isEqualToString:selectorReadFile] || [metadataNet.selector isEqualToString:selectorReadFileWithDownload]) {
            
                BOOL withDownload = NO;
            
                if ([metadataNet.selector isEqualToString:selectorReadFileWithDownload])
                    withDownload = YES;
            
                //Add/Update Metadata
                tableMetadata *addMetadata = [[NCManageDatabase sharedInstance] addMetadata:metadata];
                
                if (addMetadata)
                    [self verifyChangeMedatas:[[NSArray alloc] initWithObjects:addMetadata, nil] serverUrl:metadataNet.serverUrl account:appDelegate.activeAccount withDownload:withDownload];
            }
            
            // Selector : selectorReadFileReloadFolder, selectorReadFileFolderWithDownload
            if ([metadataNet.selector isEqualToString:selectorReadFileFolder] || [metadataNet.selector isEqualToString:selectorReadFileFolderWithDownload]) {
                
                NSString *serverUrl = [CCUtility stringAppendServerUrl:metadataNet.serverUrl addFileName:metadataNet.fileName];
                tableDirectory *tableDirectory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", metadataNet.account, serverUrl]];
                tableMetadata *tableMetadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID]];
                
                // Verify changed etag OR was not favorite
                if (!([tableDirectory.etag isEqualToString:metadata.etag]) || (tableMetadata == nil || tableMetadata.favorite == NO)) {
                    
                    if ([metadataNet.selector isEqualToString:selectorReadFileFolder])
                        [self readFolder:serverUrl selector:selectorReadFolder];
                    if ([metadataNet.selector isEqualToString:selectorReadFileFolderWithDownload])
                        [self readFolder:serverUrl selector:selectorReadFolderWithDownload];
                }
            }
        });
        
    } else {
        
        // Selector : selectorReadFile, selectorReadFileWithDownload
        if ([metadataNet.selector isEqualToString:selectorReadFile] || [metadataNet.selector isEqualToString:selectorReadFileWithDownload]) {
            
            // File not present, remove it
            if (errorCode == 404) {
                
                [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadataNet.fileID] clearDateReadDirectoryID:nil];
                [[NCManageDatabase sharedInstance] deleteLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadataNet.fileID]];
                [[NCManageDatabase sharedInstance] deletePhotosWithFileID:metadataNet.fileID];
                
                NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadataNet.directoryID];
                if (serverUrl)
                    [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:serverUrl fileID:nil action:k_action_NULL];
            }
        }
    }
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
        
        tableLocalFile *localFile = [[NCManageDatabase sharedInstance] getTableLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID]];
        
        if (withDownload) {
            
            if (![localFile.etag isEqualToString:metadata.etag])
                changeRev = YES;
            
        } else {
            
            if (localFile && ![localFile.etag isEqualToString:metadata.etag]) // it must be in TableRecord
                changeRev = YES;
        }
        
        if (changeRev) {
            
            // remove & re-create
            [[NSFileManager defaultManager] removeItemAtPath:[CCUtility getDirectoryProviderStorageFileID:metadata.fileID] error:nil];
            [CCUtility getDirectoryProviderStorageFileID:metadata.fileID fileNameView:metadata.fileNameView];
            
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
    NSMutableArray *metadataToAdd = [NSMutableArray new];

    for (tableMetadata *metadata in metadatas) {
        
        // Clear date for dorce refresh view
        if (![oldDirectoryID isEqualToString:metadata.directoryID]) {
            serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
            if (!serverUrl)
                continue;
            oldDirectoryID = metadata.directoryID;
            [[NCManageDatabase sharedInstance] clearDateReadWithServerUrl:serverUrl directoryID:nil];
        }
        
        metadata.session = k_download_session;
        metadata.sessionError = @"";
        metadata.sessionSelector = selectorDownloadSynchronize;
        metadata.status = k_metadataStatusWaitDownload;
        
        [metadataToAdd addObject:metadata];
    }
    
    (void)[[NCManageDatabase sharedInstance] addMetadatas:metadataToAdd serverUrl:nil];
    [appDelegate performSelectorOnMainThread:@selector(loadAutoDownloadUpload) withObject:nil waitUntilDone:YES];
    
    [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:serverUrl fileID:nil action:k_action_NULL];
}

@end
