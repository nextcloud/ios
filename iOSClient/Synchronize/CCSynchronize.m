//
//  CCSynchronize.m
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 19/10/16.
//  Copyright (c) 2017 Marino Faggiana. All rights reserved.
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
    metadataNet.depth = @"1";
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
            
            [[NCManageDatabase sharedInstance] deleteDirectoryAndSubDirectoryWithServerUrl:metadataNet.serverUrl account:metadataNet.account];
            [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:metadataNet.serverUrl fileID:nil action:k_action_NULL];
        }
        
        return;
    }
    
    // Add/update self Folder
    if (!metadataFolder || !metadatas || [metadatas count] == 0) {
        if (metadataFolder.serverUrl != nil) {
            [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:metadataFolder.serverUrl fileID:nil action:k_action_NULL];
        }
        return;
    }
    
    // Add metadata and update etag Directory
    (void)[[NCManageDatabase sharedInstance] addMetadata:metadataFolder];
    [[NCManageDatabase sharedInstance] setDirectoryWithServerUrl:metadataNet.serverUrl serverUrlTo:nil etag:metadataFolder.etag fileID:metadataFolder.fileID encrypted:metadataFolder.e2eEncrypted account:appDelegate.activeAccount];

    // reload folder ../ *
    [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:metadataFolder.serverUrl fileID:nil action:k_action_NULL];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        NSMutableArray *metadatasForVerifyChange = [NSMutableArray new];
        NSMutableArray *addMetadatas = [NSMutableArray new];
    
        NSArray *recordsInSessions = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND session != ''", metadataNet.account, metadataNet.serverUrl] sorted:nil ascending:NO];
        
        // ----- Test : (DELETE) -----
        
        NSMutableArray *metadatasNotPresents = [NSMutableArray new];
        
        NSArray *tableMetadatas = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND session == ''", metadataNet.account, metadataNet.serverUrl] sorted:nil ascending:NO];
        
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
                
                [[NCManageDatabase sharedInstance] deleteDirectoryAndSubDirectoryWithServerUrl:dirForDelete account:metadata.account];
            }
            
            [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID]];
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
            (void)[[NCManageDatabase sharedInstance] addMetadatas:addMetadatas];
        
        if ([metadatasForVerifyChange count] > 0)
            [self verifyChangeMedatas:metadatasForVerifyChange serverUrl:metadataNet.serverUrl account:metadataNet.account withDownload:YES];
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Read File for Folder & Read File=====
#pragma --------------------------------------------------------------------------------------------

- (void)readFile:(NSString *)fileID fileName:(NSString *)fileName serverUrl:(NSString *)serverUrl selector:(NSString *)selector
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:appDelegate.activeAccount];
        
    metadataNet.action = actionReadFile;
    metadataNet.fileID = fileID;
    metadataNet.fileName = fileName;
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
            
            BOOL withDownload = NO;
            
            if ([metadataNet.selector isEqualToString:selectorReadFileWithDownload])
                withDownload = YES;
            
            //Add/Update Metadata
            tableMetadata *addMetadata = [[NCManageDatabase sharedInstance] addMetadata:metadata];
                
            if (addMetadata)
                [self verifyChangeMedatas:[[NSArray alloc] initWithObjects:addMetadata, nil] serverUrl:metadataNet.serverUrl account:appDelegate.activeAccount withDownload:withDownload];
        });
        
    } else {
        
        // File not present, remove it
        if (errorCode == 404) {
                
            [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadataNet.fileID]];
            [[NCManageDatabase sharedInstance] deleteLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadataNet.fileID]];
            [[NCManageDatabase sharedInstance] deletePhotosWithFileID:metadataNet.fileID];
                
            [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:metadataNet.serverUrl fileID:nil action:k_action_NULL];
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
            
            if (![localFile.etag isEqualToString:metadata.etag] || ![CCUtility fileProviderStorageExists:metadata.fileID fileNameView:metadata.fileNameView])
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
        
        // The document file required always a reload 
        if (metadata.hasPreview == 1 && [metadata.typeFile isEqualToString:k_metadataTypeFile_document]) {
             [[NSFileManager defaultManager] removeItemAtPath:[CCUtility getDirectoryProviderStorageIconFileID:metadata.fileID fileNameView:metadata.fileNameView] error:nil];
        }
    }
    
    if ([metadatas count])
        [self SynchronizeMetadatas:metadatas withDownload:withDownload];
}

// MULTI THREAD
- (void)SynchronizeMetadatas:(NSArray *)metadatas withDownload:(BOOL)withDownload
{
    NSString *oldServerUrl;
    NSMutableArray *metadataToAdd = [NSMutableArray new];
    NSMutableArray *serverUrlToReload = [NSMutableArray new];


    for (tableMetadata *metadata in metadatas) {
        
        // Clear date for dorce refresh view
        if (![oldServerUrl isEqualToString:metadata.serverUrl]) {
            oldServerUrl = metadata.serverUrl;
            [serverUrlToReload addObject:metadata.serverUrl];
            [[NCManageDatabase sharedInstance] clearDateReadWithServerUrl:metadata.serverUrl account:metadata.account];
        }
        
        metadata.session = k_download_session;
        metadata.sessionError = @"";
        metadata.sessionSelector = selectorDownloadSynchronize;
        metadata.status = k_metadataStatusWaitDownload;
        
        [metadataToAdd addObject:metadata];
    }
    
    (void)[[NCManageDatabase sharedInstance] addMetadatas:metadataToAdd];
    [appDelegate performSelectorOnMainThread:@selector(loadAutoDownloadUpload) withObject:nil waitUntilDone:YES];
    
    for (NSString *serverUrl in serverUrlToReload) {
        [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:serverUrl fileID:nil action:k_action_NULL];
    }
}

@end
