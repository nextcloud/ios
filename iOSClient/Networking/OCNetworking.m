//
//  OCnetworking.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 10/05/15.
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

#import "OCNetworking.h"

#import "AppDelegate.h"
#import "CCGraphics.h"
#import "CCCertificate.h"
#import "NSString+Encode.h"

#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

@interface OCnetworking ()
{
    NSString *_activeUser;
    NSString *_activePassword;
    NSString *_activeUrl;
    NSString *_typeCloud;
    
    NSURLSessionDownloadTask *_downloadTask;
    NSURLSessionUploadTask *_uploadTask;
    
    BOOL _isCryptoCloudMode;
    BOOL _activityIndicator;
    BOOL _hasServerForbiddenCharactersSupport;
}
@end

@implementation OCnetworking

- (id)initWithDelegate:(id <OCNetworkingDelegate>)delegate metadataNet:(CCMetadataNet *)metadataNet withUser:(NSString *)withUser withPassword:(NSString *)withPassword withUrl:(NSString *)withUrl withTypeCloud:(NSString *)withTypeCloud activityIndicator:(BOOL)activityIndicator isCryptoCloudMode:(BOOL)isCryptoCloudMode
{
    self = [super init];
    
    if (self) {
        
        _delegate = delegate;
        
        _metadataNet = [[CCMetadataNet alloc] init];
        _metadataNet = [metadataNet copy];
        
        _activeUser = withUser;
        _activePassword = withPassword;
        _activeUrl = withUrl;
        _typeCloud = withTypeCloud;
        
        _isCryptoCloudMode = isCryptoCloudMode;
        _activityIndicator = activityIndicator;
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
        
        if (_downloadTask)
            [_downloadTask cancel];
    
        if (_uploadTask)
            [_uploadTask cancel];
    
        [self complete];
    }
    
    [super cancel];
}

- (void)poolNetworking
{
#ifndef EXTENSION
    // Animation network
    if (_activityIndicator) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"setTitleCCMainYESAnimation" object:nil];
        });
    }
    
    _hasServerForbiddenCharactersSupport = app.hasServerForbiddenCharactersSupport;
#else
    _hasServerForbiddenCharactersSupport = YES;
#endif
        
    if([self respondsToSelector:NSSelectorFromString(_metadataNet.action)])
        [self performSelector:NSSelectorFromString(_metadataNet.action)];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Delegate  =====
#pragma --------------------------------------------------------------------------------------------

- (void)complete
{
#ifndef EXTENSION
    // Animation network
    if (_activityIndicator) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"setTitleCCMainNOAnimation" object:nil];
        });
    }
#endif
    
    [self finish];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== downloadFile =====
#pragma --------------------------------------------------------------------------------------------

- (void)downloadFile
{
    [[CCNetworking sharedNetworking] downloadFile:_metadataNet.metadata serverUrl:_metadataNet.serverUrl downloadData:_metadataNet.downloadData downloadPlist:_metadataNet.downloadPlist selector:_metadataNet.selector selectorPost:_metadataNet.selectorPost session:_metadataNet.session taskStatus:_metadataNet.taskStatus delegate:self];
}

- (void)downloadTaskSave:(NSURLSessionDownloadTask *)downloadTask
{
    _downloadTask= downloadTask;
    
    if ([self.delegate respondsToSelector:@selector(downloadTaskSave:)])
        [self.delegate downloadTaskSave:downloadTask];
}

- (void)downloadFileSuccess:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector selectorPost:(NSString *)selectorPost
{
    [self complete];
    
    if ([self.delegate respondsToSelector:@selector(downloadFileSuccess:serverUrl:selector:selectorPost:)])
        [self.delegate downloadFileSuccess:fileID serverUrl:serverUrl selector:selector selectorPost:selectorPost];
}

- (void)downloadFileFailure:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector message:(NSString *)message errorCode:(NSInteger)errorCode
{
    [self complete];
 
    if ([self.delegate respondsToSelector:@selector(downloadFileFailure:serverUrl:selector:message:errorCode:)])
        [self.delegate downloadFileFailure:fileID serverUrl:serverUrl selector:selector message:message errorCode:errorCode];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== uploadFile =====
#pragma --------------------------------------------------------------------------------------------

- (void)uploadFile
{
    [[CCNetworking sharedNetworking] uploadFile:_metadataNet.fileName serverUrl:_metadataNet.serverUrl cryptated:_metadataNet.cryptated onlyPlist:NO session:_metadataNet.session taskStatus:_metadataNet.taskStatus selector:_metadataNet.selector selectorPost:_metadataNet.selectorPost errorCode:_metadataNet.errorCode delegate:self];
}

- (void)uploadOnlyPlist
{
    [[CCNetworking sharedNetworking] uploadFile:_metadataNet.fileName serverUrl:_metadataNet.serverUrl cryptated:YES onlyPlist:YES session:_metadataNet.session taskStatus:_metadataNet.taskStatus selector:_metadataNet.selector selectorPost:_metadataNet.selectorPost errorCode:_metadataNet.errorCode delegate:self];
}

- (void)uploadAsset
{
    [[CCNetworking sharedNetworking] uploadFileFromAssetLocalIdentifier:_metadataNet.identifier fileName:_metadataNet.fileName serverUrl:_metadataNet.serverUrl cryptated:_metadataNet.cryptated session:_metadataNet.session taskStatus:_metadataNet.taskStatus selector:_metadataNet.selector selectorPost:_metadataNet.selectorPost errorCode:_metadataNet.errorCode delegate:self];
}

- (void)uploadTemplate
{
    [[CCNetworking sharedNetworking] uploadTemplate:_metadataNet.fileNamePrint fileNameCrypto:_metadataNet.fileName serverUrl:_metadataNet.serverUrl session:_metadataNet.session taskStatus:_metadataNet.taskStatus selector:_metadataNet.selector selectorPost:_metadataNet.selectorPost errorCode:_metadataNet.errorCode delegate:self];
}

- (void)uploadTaskSave:(NSURLSessionUploadTask *)uploadTask
{
    _uploadTask = uploadTask;
    
    if ([self.delegate respondsToSelector:@selector(uploadTaskSave:)])
        [self.delegate uploadTaskSave:uploadTask];
}

- (void)uploadFileSuccess:(CCMetadataNet *)metadataNet fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector selectorPost:(NSString *)selectorPost
{
    [self complete];
    
    if ([self.delegate respondsToSelector:@selector(uploadFileSuccess:fileID:serverUrl:selector:selectorPost:)])
        [self.delegate uploadFileSuccess:_metadataNet fileID:fileID serverUrl:serverUrl selector:selector selectorPost:selectorPost];
}

- (void)uploadFileFailure:(CCMetadataNet *)metadataNet fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector message:(NSString *)message errorCode:(NSInteger)errorCode
{
    [self complete];
    
    if ([self.delegate respondsToSelector:@selector(uploadFileFailure:fileID:serverUrl:selector:message:errorCode:)])
        [self.delegate uploadFileFailure:_metadataNet fileID:fileID serverUrl:serverUrl selector:selector message:message errorCode:errorCode];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== downloadThumbnail =====
#pragma --------------------------------------------------------------------------------------------

- (void)downloadThumbnail
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    __block NSString *ext;
    NSInteger width = 0, height = 0;
    
    NSString *directoryUser = [CCUtility getDirectoryActiveUser:_activeUser activeUrl:_activeUrl];
    
    if ([_metadataNet.options.lowercaseString isEqualToString:@"xs"])      { width = 32;   height = 32;  ext = @"ico"; }
    else if ([_metadataNet.options.lowercaseString isEqualToString:@"s"])  { width = 64;   height = 64;  ext = @"ico"; }
    else if ([_metadataNet.options.lowercaseString isEqualToString:@"m"])  { width = 128;  height = 128; ext = @"ico"; }
    else if ([_metadataNet.options.lowercaseString isEqualToString:@"l"])  { width = 640;  height = 640; ext = @"pvw"; }
    else if ([_metadataNet.options.lowercaseString isEqualToString:@"xl"]) { width = 1024; height = 1024; ext = @"pvw"; }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.%@", directoryUser, _metadataNet.fileNameLocal, ext]]) {
        
        [self.delegate downloadThumbnailSuccess:_metadataNet];
        
        [self complete];
        
        return;
    }

    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent:_typeCloud]];
    
    [communication getRemoteThumbnailByServer:[_activeUrl stringByAppendingString:@"/"] ofFilePath:_metadataNet.fileName withWidth:width andHeight:height onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSData *thumbnail, NSString *redirectedServer) {
        
        TableAccount *recordAccount = [CCCoreData getActiveAccount];
        
        if ([recordAccount.account isEqualToString:_metadataNet.account]) {
        
            UIImage *thumbnailImage = [UIImage imageWithData:thumbnail];
            NSString *directoryUser = [CCUtility getDirectoryActiveUser:_activeUser activeUrl:_activeUrl];
            
            [CCGraphics saveIcoWithFileID:_metadataNet.fileNameLocal image:thumbnailImage writeToFile:[NSString stringWithFormat:@"%@/%@.%@", directoryUser, _metadataNet.fileNameLocal, ext] copy:NO move:NO fromPath:nil toPath:nil];

            if ([self.delegate respondsToSelector:@selector(downloadThumbnailSuccess:)] && [_metadataNet.action isEqualToString:actionDownloadThumbnail])
                [self.delegate downloadThumbnailSuccess:_metadataNet];
        }
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;
        
        if ([self.delegate respondsToSelector:@selector(downloadThumbnailFailure:message:errorCode:)] && [_metadataNet.action isEqualToString:actionDownloadThumbnail])
            [self.delegate downloadThumbnailFailure:_metadataNet message:[CCError manageErrorOC:response.statusCode error:error] errorCode:errorCode];
        
        [self complete];
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Read Folder =====
#pragma --------------------------------------------------------------------------------------------

- (void)readFolder
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent:_typeCloud]];
    
    [communication readFolder:_metadataNet.serverUrl withUserSessionToken:nil onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer, NSString *token) {
        
        NSMutableArray *metadatas = [[NSMutableArray alloc] init];
        
        // Check items > 0
        if ([items count] == 0) {
            
#ifndef EXTENSION
            [app messageNotification:@"Server error" description:@"Read Folder WebDAV : [items NULL] please fix" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError];
#endif

            dispatch_async(dispatch_get_main_queue(), ^{
                
                if ([self.delegate respondsToSelector:@selector(readFolderSuccess:permissions:rev:metadatas:)])
                    [self.delegate readFolderSuccess:_metadataNet permissions:@"" rev:@"" metadatas:metadatas];
            });

            [self complete];
            
            return;
        }

        // directory [0]
        OCFileDto *itemDtoDirectory = [items objectAtIndex:0];
        NSString *permissions = itemDtoDirectory.permissions;
        NSString *rev = itemDtoDirectory.etag;
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:itemDtoDirectory.date];
        
        NSString *directoryID = [CCCoreData addDirectory:_metadataNet.serverUrl date:date permissions:permissions activeAccount:_metadataNet.account];
            
        NSString *cameraFolderName = [CCCoreData getCameraUploadFolderNameActiveAccount:_metadataNet.account];
        NSString *cameraFolderPath = [CCCoreData getCameraUploadFolderPathActiveAccount:_metadataNet.account activeUrl:_activeUrl typeCloud:_typeCloud];
        NSString *directoryUser = [CCUtility getDirectoryActiveUser:_activeUser activeUrl:_activeUrl];
        
        // Update metadataNet.directoryID
        _metadataNet.directoryID = directoryID;
        
#ifndef EXTENSION
        NSString *root = [CCUtility getHomeServerUrlActiveUrl:_activeUrl typeCloud:_typeCloud];
        
        if ([root isEqualToString:_metadataNet.serverUrl]) {
            
            app.quotaUsed = itemDtoDirectory.quotaUsed;
            app.quotaAvailable = itemDtoDirectory.quotaAvailable;
        }
#endif
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{

            NSArray *itemsSortedArray = [items sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
                
                NSString *first = [(OCFileDto*)a fileName];
                NSString *second = [(OCFileDto*)b fileName];
                return [[first lowercaseString] compare:[second lowercaseString]];
            }];
        
            for (NSUInteger i=1; i < [itemsSortedArray count]; i++) {
                
                OCFileDto *itemDto = [itemsSortedArray objectAtIndex:i];
                itemDto.fileName = [itemDto.fileName stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                
                // Not in Crypto Cloud Mode OR Search skip File Crypto
                if (_isCryptoCloudMode == NO || [_metadataNet.selector isEqualToString:selectorSearch]) {
                    
                    NSString *fileName = itemDto.fileName;
                    if (itemDto.isDirectory)
                        fileName = [fileName substringToIndex:[fileName length] - 1];
                
                    if ([CCUtility isFileCryptated:fileName])
                        continue;
                }
                
                // ----- BUG #942 ---------
                if ([itemDto.etag length] == 0) {
#ifndef EXTENSION
                    [app messageNotification:@"Server error" description:@"Metadata etag absent, record excluded, please fix" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError];
#endif
                    continue;
                }
                // ------------------------
                
                // Starting with [itemDto.fileName.lowercaseString hasPrefix:_metadataNet.fileName.lowercaseString]
                if ([_metadataNet.selector isEqualToString:selectorSearch] && [itemDto.fileName.lowercaseString containsString:_metadataNet.fileName.lowercaseString]) {
                    
                    [metadatas addObject:[CCUtility trasformedOCFileToCCMetadata:itemDto fileNamePrint:itemDto.fileName serverUrl:_metadataNet.serverUrl directoryID:directoryID cameraFolderName:cameraFolderName cameraFolderPath:cameraFolderPath activeAccount:_metadataNet.account directoryUser:directoryUser typeCloud:_typeCloud]];
                }
                
                if ([_metadataNet.selector isEqualToString:selectorReadFolder]) {
                    
                    [metadatas addObject:[CCUtility trasformedOCFileToCCMetadata:itemDto fileNamePrint:itemDto.fileName serverUrl:_metadataNet.serverUrl directoryID:directoryID cameraFolderName:cameraFolderName cameraFolderPath:cameraFolderPath activeAccount:_metadataNet.account directoryUser:directoryUser typeCloud:_typeCloud]];
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                if ([_metadataNet.selector isEqualToString:selectorReadFolder] && [self.delegate respondsToSelector:@selector(readFolderSuccess:permissions:rev:metadatas:)])
                    [self.delegate readFolderSuccess:_metadataNet permissions:permissions rev:rev metadatas:metadatas];

                if ([_metadataNet.selector isEqualToString:selectorSearch] && [self.delegate respondsToSelector:@selector(searchSuccess:metadatas:)])
                    [self.delegate searchSuccess:_metadataNet metadatas:metadatas];
        
            });
        });
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *token, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;
        
        if ([_metadataNet.selector isEqualToString:selectorReadFolder] && [self.delegate respondsToSelector:@selector(readFolderFailure:message:errorCode:)])
            [self.delegate readFolderFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        
        if ([_metadataNet.selector isEqualToString:selectorSearch] && [self.delegate respondsToSelector:@selector(searchFailure:message:errorCode:)])
            [self.delegate searchFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];

        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Create Folder =====
#pragma --------------------------------------------------------------------------------------------

- (void)createFolder
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    NSString *nameFolderURL = [NSString stringWithFormat:@"%@/%@", _metadataNet.serverUrl, _metadataNet.fileName];
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent:_typeCloud]];
    
    [communication createFolder:nameFolderURL onCommunication:communication withForbiddenCharactersSupported:_hasServerForbiddenCharactersSupport successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        if ([self.delegate respondsToSelector:@selector(createFolderSuccess:)])
            [self.delegate createFolderSuccess:_metadataNet];
       
        [self complete];

    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message;
        
        if (([_metadataNet.fileName isEqualToString:[CCCoreData getCameraUploadFolderNameActiveAccount:_metadataNet.account]] == YES && [_metadataNet.serverUrl isEqualToString:[CCCoreData getCameraUploadFolderPathActiveAccount:_metadataNet.account activeUrl:_activeUrl typeCloud:_typeCloud]] == YES))
            message = nil;
        else
            message = [CCError manageErrorOC:response.statusCode error:error];
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;

        if ([self.delegate respondsToSelector:@selector(createFolderFailure:message:errorCode:)])
            [self.delegate createFolderFailure:_metadataNet message:message errorCode:errorCode];
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
        
    } errorBeforeRequest:^(NSError *error) {
        
         NSString *message;
        
        if (([_metadataNet.fileName isEqualToString:[CCCoreData getCameraUploadFolderNameActiveAccount:_metadataNet.account]] == YES && [_metadataNet.serverUrl isEqualToString:[CCCoreData getCameraUploadFolderPathActiveAccount:_metadataNet.account activeUrl:_activeUrl typeCloud:_typeCloud]] == YES))
            message = nil;
        else {
            
            if (error.code == OCErrorForbidenCharacters)
                message = NSLocalizedStringFromTable(@"_forbidden_characters_from_server_", @"Error", nil);
            else
                message = NSLocalizedStringFromTable(@"_unknow_response_server_", @"Error", nil);
        }
        
        if ([self.delegate respondsToSelector:@selector(createFolderFailure:message:errorCode:)])
            [self.delegate createFolderFailure:_metadataNet message:message errorCode:error.code];
        
        [self complete];
    }];
}

- (NSError *)createFolderSync:(NSString *)folderPathName
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    __block NSError *returnError;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent:_typeCloud]];
    
    [communication createFolder:folderPathName onCommunication:communication withForbiddenCharactersSupported:_hasServerForbiddenCharactersSupport successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        returnError = error;
        
        dispatch_semaphore_signal(semaphore);
        
    } errorBeforeRequest:^(NSError *error) {
    
        returnError = error;
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    return returnError;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Delete =====
#pragma --------------------------------------------------------------------------------------------

- (void)deleteFileOrFolder
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    NSString *serverFileUrl = [NSString stringWithFormat:@"%@/%@", _metadataNet.serverUrl, _metadataNet.fileName];
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent:_typeCloud]];
    
    [communication deleteFileOrFolder:serverFileUrl onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        if ([_metadataNet.selector rangeOfString:selectorDelete].location != NSNotFound && [self.delegate respondsToSelector:@selector(deleteFileOrFolderSuccess:)])
            [self.delegate deleteFileOrFolderSuccess:_metadataNet];
        
        [self complete];
        
    } failureRquest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;
        
        if ([self.delegate respondsToSelector:@selector(deleteFileOrFolderFailure:message:errorCode:)])
            [self.delegate deleteFileOrFolderFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Move =====
#pragma --------------------------------------------------------------------------------------------

- (void)moveFileOrFolder
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    NSString *origineURL = [NSString stringWithFormat:@"%@/%@", _metadataNet.serverUrl, _metadataNet.fileName];
    NSString *destinazioneURL = [NSString stringWithFormat:@"%@/%@", _metadataNet.serverUrlTo, _metadataNet.fileNameTo];
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent:_typeCloud]];
    
    [communication moveFileOrFolder:origineURL toDestiny:destinazioneURL onCommunication:communication withForbiddenCharactersSupported:_hasServerForbiddenCharactersSupport successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        if ([_metadataNet.selector isEqualToString:selectorRename] && [self.delegate respondsToSelector:@selector(renameSuccess:)])
            [self.delegate renameSuccess:_metadataNet];
        
        if ([_metadataNet.selector rangeOfString:selectorMove].location != NSNotFound && [self.delegate respondsToSelector:@selector(moveSuccess:revTo:)])
            [self.delegate moveSuccess:_metadataNet revTo:nil];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;
        
        if ([self.delegate respondsToSelector:@selector(renameMoveFileOrFolderFailure:message:errorCode:)])
            [self.delegate renameMoveFileOrFolderFailure:_metadataNet message:[CCError manageErrorOC:response.statusCode error:error] errorCode:errorCode];
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
        
    } errorBeforeRequest:^(NSError *error) {
        
        NSString *message;
        
        if (error.code == OCErrorMovingTheDestinyAndOriginAreTheSame) {
            message = NSLocalizedStringFromTable(@"_error_folder_destiny_is_the_same_", @"Error", nil);
        } else if (error.code == OCErrorMovingFolderInsideHimself) {
            message = NSLocalizedStringFromTable(@"_error_folder_destiny_is_the_same_", @"Error", nil);
        } else if (error.code == OCErrorMovingDestinyNameHaveForbiddenCharacters) {
            message = NSLocalizedStringFromTable(@"_forbidden_characters_from_server_", @"Error", nil);
        } else {
            message = NSLocalizedStringFromTable(@"_unknow_response_server_", @"Error", nil);
        }
        
        if ([self.delegate respondsToSelector:@selector(renameMoveFileOrFolderFailure:message:errorCode:)])
            [self.delegate renameMoveFileOrFolderFailure:_metadataNet message:message errorCode:error.code];

        [self complete];
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== ReadFile =====
#pragma --------------------------------------------------------------------------------------------

- (void)readFile
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    NSString *fileName;
    
    if (_metadataNet.fileName)
        fileName = [NSString stringWithFormat:@"%@/%@", _metadataNet.serverUrl, _metadataNet.fileName];
    else
        fileName = _metadataNet.serverUrl;
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent:_typeCloud]];
    
    [communication readFile:fileName onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer) {
        
        TableAccount *recordAccount = [CCCoreData getActiveAccount];
        
        if ([recordAccount.account isEqualToString:_metadataNet.account] && [items count] > 0) {
            
            CCMetadata *metadata = [[CCMetadata alloc] init];
            
            OCFileDto *itemDto = [items objectAtIndex:0];
            itemDto.fileName = _metadataNet.fileName;
            
            NSString *directoryID = [CCCoreData getDirectoryIDFromServerUrl:_metadataNet.serverUrl activeAccount:_metadataNet.account];
            NSString *cameraFolderName = [CCCoreData getCameraUploadFolderNameActiveAccount:_metadataNet.account];
            NSString *cameraFolderPath = [CCCoreData getCameraUploadFolderPathActiveAccount:_metadataNet.account activeUrl:_activeUrl typeCloud:_typeCloud];
            NSString *directoryUser = [CCUtility getDirectoryActiveUser:_activeUser activeUrl:_activeUrl];
        
            metadata = [CCUtility trasformedOCFileToCCMetadata:itemDto fileNamePrint:_metadataNet.fileNamePrint serverUrl:_metadataNet.serverUrl directoryID:directoryID cameraFolderName:cameraFolderName cameraFolderPath:cameraFolderPath activeAccount:_metadataNet.account directoryUser:directoryUser typeCloud:_typeCloud];
            
#ifndef EXTENSION
            NSString *root = [CCUtility getHomeServerUrlActiveUrl:_activeUrl typeCloud:_typeCloud];
            
            if ([root isEqualToString:fileName]) {
                
                app.quotaUsed = itemDto.quotaUsed;
                app.quotaAvailable = itemDto.quotaAvailable;
            }
#endif
            
            if([self.delegate respondsToSelector:@selector(readFileSuccess:metadata:)])
                [self.delegate readFileSuccess:_metadataNet metadata:metadata];
        }
        
        // BUG 1038
        if ([items count] == 0) {
       
#ifndef EXTENSION
            [app messageNotification:@"Server error" description:@"Read File WebDAV : [items NULL] please fix" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError];
#endif
        }
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        TableAccount *recordAccount = [CCCoreData getActiveAccount];
        
        _metadataNet.errorRetry++;
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;
        
        if([self.delegate respondsToSelector:@selector(readFileFailure:message:errorCode:)] && [recordAccount.account isEqualToString:_metadataNet.account])
            [self.delegate readFileFailure:_metadataNet message:[CCError manageErrorOC:response.statusCode error:error] errorCode:errorCode];
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

- (NSError *)readFileSync:(NSString *)filePathName
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    __block NSError *returnError;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent:_typeCloud]];
    
    [communication readFile:filePathName onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer) {
        
        returnError = nil;
        dispatch_semaphore_signal(semaphore);

    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        returnError = error;
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    return returnError;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Shared =====
#pragma --------------------------------------------------------------------------------------------

- (NSMutableDictionary *)getShareID
{
#ifndef EXTENSION
    return app.sharesID;
#endif
    return [NSMutableDictionary new];
}

- (void)readShareServer
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent:_typeCloud]];
    
    [communication readSharedByServer:[_activeUrl stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer) {
        
        BOOL openWindow = NO;
        
        [[self getShareID] removeAllObjects];
        
        TableAccount *recordAccount = [CCCoreData getActiveAccount];
        
        if ([recordAccount.account isEqualToString:_metadataNet.account]) {
        
            for (OCSharedDto *item in items)
                [[self getShareID] setObject:item forKey:[@(item.idRemoteShared) stringValue]];
            
            if ([_metadataNet.selector isEqual:selectorOpenWindowShare]) openWindow = YES;
            
            if ([_metadataNet.action isEqual:actionUpdateShare]) openWindow = YES;
            if ([_metadataNet.action isEqual:actionShare]) openWindow = YES;
            if ([_metadataNet.action isEqual:actionShareWith]) openWindow = YES;
        }
        
        if([self.delegate respondsToSelector:@selector(readSharedSuccess:items:openWindow:)])
            [self.delegate readSharedSuccess:_metadataNet items:[self getShareID] openWindow:openWindow];
        
        [self complete];
        
    } failureRequest :^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;
        
        if([self.delegate respondsToSelector:@selector(shareFailure:message:errorCode:)])
            [self.delegate shareFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

- (void)share
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
        
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent:_typeCloud]];
    
    [communication shareFileOrFolderByServer:[_activeUrl stringByAppendingString:@"/"] andFileOrFolderPath:[_metadataNet.fileName encodeString:NSUTF8StringEncoding] andPassword:[_metadataNet.password encodeString:NSUTF8StringEncoding] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *token, NSString *redirectedServer) {
        
        [self readShareServer];
        
    } failureRequest :^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;

        if([self.delegate respondsToSelector:@selector(shareFailure:message:errorCode:)])
            [self.delegate shareFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

// * @param shareeType -> NSInteger: to set the type of sharee (user/group/federated)

- (void)shareWith
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent:_typeCloud]];
    
    [communication shareWith:_metadataNet.share shareeType:_metadataNet.shareeType inServer:[_activeUrl stringByAppendingString:@"/"] andFileOrFolderPath:[_metadataNet.fileName encodeString:NSUTF8StringEncoding] andPermissions:_metadataNet.sharePermission onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        [self readShareServer];
                
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;

        if([self.delegate respondsToSelector:@selector(shareFailure:message:errorCode:)])
            [self.delegate shareFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

- (void)updateShare
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent:_typeCloud]];
    
    [communication updateShare:[_metadataNet.share intValue] ofServerPath:[_activeUrl stringByAppendingString:@"/"] withPasswordProtect:[_metadataNet.password encodeString:NSUTF8StringEncoding] andExpirationTime:_metadataNet.expirationTime andPermissions:_metadataNet.sharePermission onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        [self readShareServer];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
#ifndef EXTENSION
        [app messageNotification:@"_error_" description:[CCError manageErrorOC:response.statusCode error:error] visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError];
#endif
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;

        if([self.delegate respondsToSelector:@selector(shareFailure:message:errorCode:)])
            [self.delegate shareFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

- (void)unShare
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent:_typeCloud]];
    
    [communication unShareFileOrFolderByServer:[_activeUrl stringByAppendingString:@"/"] andIdRemoteShared:[_metadataNet.share intValue] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        if([self.delegate respondsToSelector:@selector(unShareSuccess:)])
            [self.delegate unShareSuccess:_metadataNet];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
#ifndef EXTENSION
        [app messageNotification:@"_error_" description:[CCError manageErrorOC:response.statusCode error:error] visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError];
#endif
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;

        if([self.delegate respondsToSelector:@selector(shareFailure:message:errorCode:)])
            [self.delegate shareFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

- (void)getUserAndGroup
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent:_typeCloud]];
    
    [communication searchUsersAndGroupsWith:_metadataNet.options forPage:1 with:50 ofServer:[_activeUrl stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *itemList, NSString *redirectedServer) {
        
        if([self.delegate respondsToSelector:@selector(getUserAndGroupSuccess:items:)])
            [self.delegate getUserAndGroupSuccess:_metadataNet items:itemList];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;

        if([self.delegate respondsToSelector:@selector(getUserAndGroupFailure:message:errorCode:)])
            [self.delegate getUserAndGroupFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Notification =====
#pragma --------------------------------------------------------------------------------------------

- (void)getNotificationsOfServer
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent:_typeCloud]];
    
    [communication getNotificationsOfServer:[_activeUrl stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *listOfNotifications, NSString *redirectedServer) {
        
        if ([self.delegate respondsToSelector:@selector(getNotificationsOfServerSuccess:)])
            [self.delegate getNotificationsOfServerSuccess:listOfNotifications];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;
        
        if([self.delegate respondsToSelector:@selector(getNotificationsOfServerFailure:message:errorCode:)])
            [self.delegate getNotificationsOfServerFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

- (void)setNotificationServer
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent:_typeCloud]];
    
    NSString *type = _metadataNet.options;
    
    [communication setNotificationServer:_metadataNet.serverUrl type:type onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        if ([self.delegate respondsToSelector:@selector(setNotificationServerSuccess:)])
            [self.delegate setNotificationServerSuccess:_metadataNet];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;
        
        if([self.delegate respondsToSelector:@selector(setNotificationServerFailure:message:errorCode:)])
            [self.delegate setNotificationServerFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Server =====
#pragma --------------------------------------------------------------------------------------------

- (NSError *)checkServerSync:(NSString *)serverUrl
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    __block NSError *returnError;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent:_typeCloud]];
    
    [communication checkServer:serverUrl onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        returnError = nil;
        dispatch_semaphore_signal(semaphore);

    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        returnError = error;
        dispatch_semaphore_signal(semaphore);
    }];
     
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
     
    return returnError;
}

- (void)getFeaturesSupportedByServer
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent:_typeCloud]];
    
    [communication getFeaturesSupportedByServer:[_activeUrl stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, BOOL hasShareSupport, BOOL hasShareeSupport, BOOL hasCookiesSupport, BOOL hasForbiddenCharactersSupport, BOOL hasCapabilitiesSupport, BOOL hasFedSharesOptionShareSupport, NSString *redirectedServer) {
        
        TableAccount *recordAccount = [CCCoreData getActiveAccount];
        
        if ([self.delegate respondsToSelector:@selector(getFeaturesSupportedByServerSuccess:hasForbiddenCharactersSupport:hasShareSupport:hasShareeSupport:)] && [recordAccount.account isEqualToString:_metadataNet.account])
            [self.delegate getFeaturesSupportedByServerSuccess:hasCapabilitiesSupport hasForbiddenCharactersSupport:hasForbiddenCharactersSupport hasShareSupport:hasShareSupport hasShareeSupport:hasShareeSupport];

        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;

        if([self.delegate respondsToSelector:@selector(getInfoServerFailure:message:errorCode:)])
            [self.delegate getInfoServerFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];

        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

- (void)getCapabilitiesOfServer
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent:_typeCloud]];
    
    [communication getCapabilitiesOfServer:[_activeUrl stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, OCCapabilities *capabilities, NSString *redirectedServer) {
        
        TableAccount *recordAccount = [CCCoreData getActiveAccount];
        
        if ([self.delegate respondsToSelector:@selector(getCapabilitiesOfServerSuccess:)] && [recordAccount.account isEqualToString:_metadataNet.account])
            [self.delegate getCapabilitiesOfServerSuccess:capabilities];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;

        if([self.delegate respondsToSelector:@selector(getInfoServerFailure:message:errorCode:)])
            [self.delegate getInfoServerFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];

        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];

        [self complete];
    }];
}

@end

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  OCURLSessionManager =====
#pragma --------------------------------------------------------------------------------------------

@implementation OCURLSessionManager

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
    // The pinnning check
    
    if ([[CCCertificate sharedManager] checkTrustedChallenge:challenge]) {
        completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]);
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

@end
