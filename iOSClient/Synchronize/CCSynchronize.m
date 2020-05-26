//
//  CCSynchronize.m
//  Nextcloud
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
            
            sharedSynchronize->_operationSynchronizeQueue = [NSOperationQueue new];
            sharedSynchronize->_operationSynchronizeQueue.name = @"com.nextcloud.operationSynchronizeQueue";
            sharedSynchronize->_operationSynchronizeQueue.maxConcurrentOperationCount = 1;
        }
        return sharedSynchronize;
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Read Folder =====
#pragma --------------------------------------------------------------------------------------------

// serverUrl    : start
// selector     : selectorReadFolder, selectorReadFolderWithDownload
//

- (void)readFolder:(NSString *)serverUrl selector:(NSString *)selector account:(NSString *)account
{
    id operation = [[CCOperationSynchronize alloc] initWithDelegate:self serverUrl:serverUrl selector:selector account:account];

    [self.operationSynchronizeQueue addOperation:operation];
}

- (void)readFolderSuccessFailureWithAccount:(NSString *)account serverUrl:(NSString *)serverUrl metadataFolder:(tableMetadata *)metadataFolder metadatas:(NSArray *)metadatas selector:(NSString *)selector message:(NSString *)message errorCode:(NSInteger)errorCode
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    // ERROR
    if (errorCode != 0 || ![account isEqualToString:appDelegate.activeAccount]) {
        
        // Folder not present, remove it
        if (errorCode == kOCErrorServerPathNotFound) {
            
            [[NCManageDatabase sharedInstance] deleteDirectoryAndSubDirectoryWithServerUrl:serverUrl account:account];
            [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:serverUrl ocId:nil action:k_action_NULL];
        }
        
        return;
    }
    
    // Add/update self Folder
    if (!metadataFolder || !metadatas || [metadatas count] == 0) {
        if (metadataFolder.serverUrl != nil) {
            [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:metadataFolder.serverUrl ocId:nil action:k_action_NULL];
        }
        return;
    }
    
    // Add metadata and update etag Directory
    [[NCManageDatabase sharedInstance] addMetadata:metadataFolder];
    [[NCManageDatabase sharedInstance] setDirectoryWithServerUrl:serverUrl serverUrlTo:nil etag:metadataFolder.etag ocId:metadataFolder.ocId fileId:metadataFolder.fileId encrypted:metadataFolder.e2eEncrypted richWorkspace:nil account:appDelegate.activeAccount];
    
    // reload folder ../ *
    [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:metadataFolder.serverUrl ocId:nil action:k_action_NULL];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        NSMutableArray *metadatasForVerifyChange = [NSMutableArray new];
        NSMutableArray *addMetadatas = [NSMutableArray new];
        
        NSArray *recordsInSessions = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND session != ''", account, serverUrl] sorted:nil ascending:NO];
        
        // ----- Test : (DELETE) -----
        
        NSMutableArray *metadatasNotPresents = [NSMutableArray new];
        
        NSArray *tableMetadatas = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND session == ''", account, serverUrl] sorted:nil ascending:NO];
        
        for (tableMetadata *record in tableMetadatas) {
            
            BOOL ocIdFound = NO;
            
            for (tableMetadata *metadata in metadatas) {
                
                if ([record.ocId isEqualToString:metadata.ocId]) {
                    ocIdFound = YES;
                    break;
                }
            }
            
            if (!ocIdFound)
                [metadatasNotPresents addObject:record];
        }
        
        // delete metadata not present
        for (tableMetadata *metadata in metadatasNotPresents) {
            
            [[NSFileManager defaultManager] removeItemAtPath:[CCUtility getDirectoryProviderStorageOcId:metadata.ocId] error:nil];
            
            if (metadata.directory && serverUrl) {
                
                NSString *dirForDelete = [CCUtility stringAppendServerUrl:serverUrl addFileName:metadata.fileName];
                
                [[NCManageDatabase sharedInstance] deleteDirectoryAndSubDirectoryWithServerUrl:dirForDelete account:account];
            }
            
            [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", metadata.ocId]];
            [[NCManageDatabase sharedInstance] deleteLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", metadata.ocId]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([metadatasNotPresents count] > 0)
                [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:serverUrl ocId:nil action:k_action_NULL];
        });
        
        // ----- Test : (MODIFY) -----
        
        for (tableMetadata *metadata in metadatas) {
            
            // RECURSIVE DIRECTORY MODE
            if (metadata.directory) {
                
                // Verify if do not exists this Metadata
                tableMetadata *result = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", metadata.ocId]];
                
                if (!result)
                    [[NCManageDatabase sharedInstance] addMetadata:metadata];
                
                [self readFolder:[CCUtility stringAppendServerUrl:serverUrl addFileName:metadata.fileName] selector:selector account:account];
                
            } else {
                
                if ([selector isEqualToString:selectorReadFolderWithDownload]) {
                    
                    // It's in session
                    BOOL recordInSession = NO;
                    for (tableMetadata *record in recordsInSessions) {
                        if ([record.ocId isEqualToString:metadata.ocId]) {
                            recordInSession = YES;
                            break;
                        }
                    }
                    
                    if (recordInSession)
                        continue;
                    
                    // Ohhhh INSERT
                    [metadatasForVerifyChange addObject:metadata];
                }
                
                if ([selector isEqualToString:selectorReadFolder]) {
                    
                    // Verify if do not exists this Metadata
                    tableMetadata *result = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", metadata.ocId]];
                    
                    if (!result)
                        [addMetadatas addObject:metadata];
                }
            }
        }
        
        if ([addMetadatas count] > 0)
            [[NCManageDatabase sharedInstance] addMetadatas:addMetadatas];
        
        if ([metadatasForVerifyChange count] > 0)
            [self verifyChangeMedatas:metadatasForVerifyChange serverUrl:serverUrl account:account withDownload:YES];
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Read File for Folder & Read File=====
#pragma --------------------------------------------------------------------------------------------

- (void)readFile:(NSString *)ocId fileName:(NSString *)fileName serverUrl:(NSString *)serverUrl selector:(NSString *)selector account:(NSString *)account
{
    NSString *serverUrlFileName = [NSString stringWithFormat:@"%@/%@", serverUrl, fileName];

    [[NCNetworking shared] readFileWithServerUrlFileName:serverUrlFileName account:account completion:^(NSString *account, tableMetadata *metadata, NSInteger errorCode, NSString *errorDescription) {
        
        if (errorCode == 0 && [account isEqualToString:account]) {
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                
                BOOL withDownload = NO;
                
                if ([selector isEqualToString:selectorReadFileWithDownload])
                    withDownload = YES;
                
                //Add/Update Metadata
                tableMetadata *addMetadata = [[NCManageDatabase sharedInstance] addMetadata:metadata];
                if (addMetadata)
                    [self verifyChangeMedatas:[[NSArray alloc] initWithObjects:addMetadata, nil] serverUrl:serverUrl account:account withDownload:withDownload];
            });
            
        } else if (errorCode == kOCErrorServerPathNotFound) {
                
            [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", ocId]];
            [[NCManageDatabase sharedInstance] deleteLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", ocId]];
                
            [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:serverUrl ocId:nil action:k_action_NULL];
        }
    }];
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
        
        tableLocalFile *localFile = [[NCManageDatabase sharedInstance] getTableLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", metadata.ocId]];
        
        if (withDownload) {
            
            if (![localFile.etag isEqualToString:metadata.etag] || ![CCUtility fileProviderStorageExists:metadata.ocId fileNameView:metadata.fileNameView])
                changeRev = YES;
            
        } else {
            
            if (localFile && ![localFile.etag isEqualToString:metadata.etag]) // it must be in TableRecord
                changeRev = YES;
        }
        
        if (changeRev) {
            
            // remove & re-create
            [[NSFileManager defaultManager] removeItemAtPath:[CCUtility getDirectoryProviderStorageOcId:metadata.ocId] error:nil];
            [CCUtility getDirectoryProviderStorageOcId:metadata.ocId fileNameView:metadata.fileNameView];
            
            [metadatas addObject:metadata];
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
    
    [[NCManageDatabase sharedInstance] addMetadatas:metadataToAdd];
    
    for (NSString *serverUrl in serverUrlToReload) {
        [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:serverUrl ocId:nil action:k_action_NULL];
    }
}

@end

@implementation CCOperationSynchronize

- (id)initWithDelegate:(id)delegate serverUrl:(NSString *)serverUrl selector:(NSString *)selector account:(NSString *)account
{
    self = [super init];
    
    if (self) {
        self.delegate = delegate;
        self.serverUrl = serverUrl;
        self.selector = selector;
        self.account = account;
    }
    
    return self;
}

- (void)start
{
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:NO];
        return;
    }
    
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    if (self.isCancelled) {
        
        [self finish];
        
    } else {
        
        [self poolNetworking];
    }
}

- (void)finish
{
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    _isExecuting = NO;
    _isFinished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (void)cancel
{
    if (_isExecuting) {
        
        [self complete];
    }
    
    [super cancel];
}

- (void)poolNetworking
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
    [[NCCommunication shared] readFileOrFolderWithServerUrlFileName:self.serverUrl depth:@"1" showHiddenFiles:[CCUtility getShowHiddenFiles] customUserAgent:nil addCustomHeaders:nil completionHandler:^(NSString *account, NSArray *files, NSInteger errorCode, NSString *errorDescription) {
               
        [[NCManageDatabase sharedInstance] convertNCCommunicationFilesToMetadatas:files useMetadataFolder:true account:account completion:^(tableMetadata *metadataFolder, NSArray<tableMetadata *> *metadatasFolder, NSArray<tableMetadata *> *metadatas) {
            
            if ([self.delegate respondsToSelector:@selector(readFolderSuccessFailureWithAccount:serverUrl:metadataFolder:metadatas:selector:message:errorCode:)])
                [self.delegate readFolderSuccessFailureWithAccount:self.account serverUrl:self.serverUrl metadataFolder:metadataFolder metadatas:metadatas selector:self.selector message:errorDescription errorCode:errorCode];
            
            [self complete];
        }];
    }];
}

- (void)complete
{
    [self finish];
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

@end
