//
//  OCnetworking.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 10/05/15.
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

#import "OCNetworking.h"

#import "AppDelegate.h"
#import "CCGraphics.h"
#import "CCCertificate.h"
#import "NSString+Encode.h"
#import "NCBridgeSwift.h"

#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

@interface OCnetworking ()
{
    NSString *_activeUser;
    NSString *_activePassword;
    NSString *_activeUrl;
    
    NSURLSessionDownloadTask *_downloadTask;
    NSURLSessionUploadTask *_uploadTask;
    
    BOOL _isCryptoCloudMode;
}
@end

@implementation OCnetworking

- (id)initWithDelegate:(id <OCNetworkingDelegate>)delegate metadataNet:(CCMetadataNet *)metadataNet withUser:(NSString *)withUser withPassword:(NSString *)withPassword withUrl:(NSString *)withUrl isCryptoCloudMode:(BOOL)isCryptoCloudMode
{
    self = [super init];
    
    if (self) {
        
        _delegate = delegate;
        
        _metadataNet = [CCMetadataNet new];
        _metadataNet = [metadataNet copy];
        
        _activeUser = withUser;
        _activePassword = withPassword;
        _activeUrl = withUrl;
        
        _isCryptoCloudMode = isCryptoCloudMode;
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
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
#endif
        
    if([self respondsToSelector:NSSelectorFromString(_metadataNet.action)])
        [self performSelector:NSSelectorFromString(_metadataNet.action)];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Delegate  =====
#pragma --------------------------------------------------------------------------------------------

- (void)complete
{    
    [self finish];
    
#ifndef EXTENSION
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
#endif
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== downloadFile =====
#pragma --------------------------------------------------------------------------------------------

- (void)downloadFile
{
    [[CCNetworking sharedNetworking] downloadFile:_metadataNet.fileID serverUrl:_metadataNet.serverUrl downloadData:_metadataNet.downloadData downloadPlist:_metadataNet.downloadPlist selector:_metadataNet.selector selectorPost:_metadataNet.selectorPost session:_metadataNet.session taskStatus:_metadataNet.taskStatus delegate:self];
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
    [[CCNetworking sharedNetworking] uploadFileFromAssetLocalIdentifier:_metadataNet.assetLocalIdentifier fileName:_metadataNet.fileName serverUrl:_metadataNet.serverUrl cryptated:_metadataNet.cryptated session:_metadataNet.session taskStatus:_metadataNet.taskStatus selector:_metadataNet.selector selectorPost:_metadataNet.selectorPost errorCode:_metadataNet.errorCode delegate:self];
}

- (void)uploadTemplate
{
    [[CCNetworking sharedNetworking] uploadTemplate:_metadataNet.fileNamePrint fileNameCrypto:_metadataNet.fileName serverUrl:_metadataNet.serverUrl session:_metadataNet.session taskStatus:_metadataNet.taskStatus selector:_metadataNet.selector selectorPost:_metadataNet.selectorPost errorCode:_metadataNet.errorCode delegate:self];
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
    NSString *dimOfThumbnail = (NSString *)_metadataNet.options;
    
    if ([dimOfThumbnail.lowercaseString isEqualToString:@"xs"])      { width = 32;   height = 32;  ext = @"ico"; }
    else if ([dimOfThumbnail.lowercaseString isEqualToString:@"s"])  { width = 64;   height = 64;  ext = @"ico"; }
    else if ([dimOfThumbnail.lowercaseString isEqualToString:@"m"])  { width = 128;  height = 128; ext = @"ico"; }
    else if ([dimOfThumbnail.lowercaseString isEqualToString:@"l"])  { width = 640;  height = 640; ext = @"pvw"; }
    else if ([dimOfThumbnail.lowercaseString isEqualToString:@"xl"]) { width = 1024; height = 1024; ext = @"pvw"; }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.%@", directoryUser, _metadataNet.fileNameLocal, ext]]) {
        
        [self.delegate downloadThumbnailSuccess:_metadataNet];
        
        [self complete];
        
        return;
    }

    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getRemoteThumbnailByServer:[_activeUrl stringByAppendingString:@"/"] ofFilePath:_metadataNet.fileName withWidth:width andHeight:height onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSData *thumbnail, NSString *redirectedServer) {
        
        tableAccount *recordAccount = [[NCManageDatabase sharedInstance] getAccountActive];
        
        if ([recordAccount.account isEqualToString:_metadataNet.account] && [thumbnail length] > 0) {
        
            UIImage *thumbnailImage = [UIImage imageWithData:thumbnail];
            NSString *directoryUser = [CCUtility getDirectoryActiveUser:_activeUser activeUrl:_activeUrl];
            
            [CCGraphics saveIcoWithEtag:_metadataNet.fileNameLocal image:thumbnailImage writeToFile:[NSString stringWithFormat:@"%@/%@.%@", directoryUser, _metadataNet.fileNameLocal, ext] copy:NO move:NO fromPath:nil toPath:nil];

            if ([self.delegate respondsToSelector:@selector(downloadThumbnailSuccess:)] && [_metadataNet.action isEqualToString:actionDownloadThumbnail])
                [self.delegate downloadThumbnailSuccess:_metadataNet];
        } else {
            
            if ([self.delegate respondsToSelector:@selector(downloadThumbnailFailure:message:errorCode:)] && [_metadataNet.action isEqualToString:actionDownloadThumbnail])
                [self.delegate downloadThumbnailFailure:_metadataNet message:@"No data" errorCode:0];
        }
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(downloadThumbnailFailure:message:errorCode:)] && [_metadataNet.action isEqualToString:actionDownloadThumbnail]) {
            
            if (errorCode == 503)
                [self.delegate downloadThumbnailFailure:_metadataNet message:NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil) errorCode:errorCode];
            else
                [self.delegate downloadThumbnailFailure:_metadataNet message:[CCError manageErrorOC:response.statusCode error:error] errorCode:errorCode];
        }
        
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
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication readFolder:_metadataNet.serverUrl withUserSessionToken:nil onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer, NSString *token) {
        
        NSMutableArray *metadatas = [NSMutableArray new];
        tableMetadata *metadataFolder;
        NSString *directoryIDFolder;
        
        // Check items > 0
        if ([items count] == 0) {
            
#ifndef EXTENSION
            [app messageNotification:@"Server error" description:@"Read Folder WebDAV : [items NULL] please fix" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError  errorCode:0];
#endif

            dispatch_async(dispatch_get_main_queue(), ^{
                
                if ([self.delegate respondsToSelector:@selector(readFolderSuccess:metadataFolder:metadatas:)])
                    [self.delegate readFolderSuccess:_metadataNet metadataFolder:nil metadatas:metadatas];
            });

            [self complete];
            
            return;
        }

        // directory [0]
        OCFileDto *itemDtoFolder = [items objectAtIndex:0];
        //NSDate *date = [NSDate dateWithTimeIntervalSince1970:itemDtoDirectory.date];
        
        NSString *directoryID = [[NCManageDatabase sharedInstance] addDirectoryWithServerUrl:_metadataNet.serverUrl permissions:itemDtoFolder.permissions];
        _metadataNet.directoryID = directoryID;

        NSString *autoUploadFileName = [[NCManageDatabase sharedInstance] getAccountAutoUploadFileName];
        NSString *autoUploadDirectory = [[NCManageDatabase sharedInstance] getAccountAutoUploadDirectory:_activeUrl];
        
        NSString *directoryUser = [CCUtility getDirectoryActiveUser:_activeUser activeUrl:_activeUrl];
        
        // Metadata . (Folder)
        if ([_metadataNet.serverUrl isEqualToString:[CCUtility getHomeServerUrlActiveUrl:_activeUrl]]) {
            
            // root folder
            directoryIDFolder = @"00000000-0000-0000-0000-000000000000";
            itemDtoFolder.fileName = @".";
            
        } else {
            
            directoryIDFolder = [[NCManageDatabase sharedInstance] getDirectoryID:[CCUtility deletingLastPathComponentFromServerUrl:_metadataNet.serverUrl]];
            itemDtoFolder.fileName = [_metadataNet.serverUrl lastPathComponent];
        }
        metadataFolder = [CCUtility trasformedOCFileToCCMetadata:itemDtoFolder fileNamePrint:itemDtoFolder.fileName serverUrl:_metadataNet.serverUrl directoryID:directoryIDFolder autoUploadFileName:autoUploadFileName autoUploadDirectory:autoUploadDirectory activeAccount:_metadataNet.account directoryUser:directoryUser];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{

            NSArray *itemsSortedArray = [items sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
                
                NSString *first = [(OCFileDto*)a fileName];
                NSString *second = [(OCFileDto*)b fileName];
                return [[first lowercaseString] compare:[second lowercaseString]];
            }];
        
            for (NSUInteger i=1; i < [itemsSortedArray count]; i++) {
                
                OCFileDto *itemDto = [itemsSortedArray objectAtIndex:i];
                itemDto.fileName = [itemDto.fileName stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                NSString *fileName = itemDto.fileName;
                
                // Skip if not CryptoMode
                if (_isCryptoCloudMode == NO && [CCUtility isFileCryptated:fileName])
                    continue;
                
                if (itemDto.isDirectory) {
                        
                    fileName = [fileName substringToIndex:[fileName length] - 1];
                    NSString *serverUrl = [CCUtility stringAppendServerUrl:_metadataNet.serverUrl addFileName:fileName];
                        
                    (void)[[NCManageDatabase sharedInstance] addDirectoryWithServerUrl:serverUrl permissions:itemDtoFolder.permissions];
                }
                
                // ----- BUG #942 ---------
                if ([itemDto.etag length] == 0) {
#ifndef EXTENSION
                    [app messageNotification:@"Server error" description:@"Metadata fileID absent, record excluded, please fix" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:0];
#endif
                    continue;
                }
                // ------------------------
                
                [metadatas addObject:[CCUtility trasformedOCFileToCCMetadata:itemDto fileNamePrint:itemDto.fileName serverUrl:_metadataNet.serverUrl directoryID:directoryID autoUploadFileName:autoUploadFileName autoUploadDirectory:autoUploadDirectory activeAccount:_metadataNet.account directoryUser:directoryUser]];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                if ([self.delegate respondsToSelector:@selector(readFolderSuccess:metadataFolder:metadatas:)])
                    [self.delegate readFolderSuccess:_metadataNet metadataFolder:metadataFolder metadatas:metadatas];
            });
        });
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *token, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(readFolderFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate readFolderFailure:_metadataNet message:NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil) errorCode:errorCode];
            else
                [self.delegate readFolderFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:_metadataNet.serverUrl fileID:@"" action:k_activityDebugActionReadFolder selector:@"" note:[error.userInfo valueForKey:@"NSLocalizedDescription"] type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:_activeUrl];
        
        [self complete];
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Search =====
#pragma --------------------------------------------------------------------------------------------

- (void)search
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    NSString *path = [_activeUrl stringByAppendingString:dav];
    NSString *folder = [_metadataNet.serverUrl stringByReplacingOccurrencesOfString:[CCUtility getHomeServerUrlActiveUrl:_activeUrl] withString:@""];
    NSString *dateLastModified;
    
    if (_metadataNet.date) {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        [dateFormatter setLocale:enUSPOSIXLocale];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
    
        dateLastModified = [dateFormatter stringFromDate:_metadataNet.date];
    }
    
    [communication search:path folder:folder fileName: [NSString stringWithFormat:@"%%%@%%", _metadataNet.fileName] depth:_metadataNet.options dateLastModified:dateLastModified withUserSessionToken:nil onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer, NSString *token) {
        
        NSMutableArray *metadatas = [NSMutableArray new];
        
        NSString *autoUploadFileName = [[NCManageDatabase sharedInstance] getAccountAutoUploadFileName];
        NSString *autoUploadDirectory = [[NCManageDatabase sharedInstance] getAccountAutoUploadDirectory:_activeUrl];
        NSString *directoryUser = [CCUtility getDirectoryActiveUser:_activeUser activeUrl:_activeUrl];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
            for(OCFileDto *itemDto in items) {
            
                itemDto.fileName = [itemDto.fileName stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            
                // Not in Crypto Cloud file
                NSString *fileName = itemDto.fileName;
                if (itemDto.isDirectory)
                    fileName = [fileName substringToIndex:[fileName length] - 1];
                
                if ([CCUtility isFileCryptated:fileName])
                    continue;
            
                // ----- BUG #942 ---------
                if ([itemDto.etag length] == 0) {
#ifndef EXTENSION
                    [app messageNotification:@"Server error" description:@"Metadata fileID absent, record excluded, please fix" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:0];
#endif
                    continue;
                }
                // ------------------------
            
                NSString *serverUrl = [NSString stringWithFormat:@"%@/files/%@", dav, _activeUser];
                serverUrl = [itemDto.filePath stringByReplacingOccurrencesOfString:serverUrl withString:@""];
            
                /* TRIM */
                if ([serverUrl hasPrefix:@"/"])
                    serverUrl = [serverUrl substringFromIndex:1];
                if ([serverUrl hasSuffix:@"/"])
                    serverUrl = [serverUrl substringToIndex:[serverUrl length] - 1];
                /*      */
            
                serverUrl = [CCUtility stringAppendServerUrl:[_activeUrl stringByAppendingString:webDAV] addFileName:serverUrl];
            
                NSString *directoryID = [[NCManageDatabase sharedInstance] addDirectoryWithServerUrl:serverUrl permissions:itemDto.permissions];

                [metadatas addObject:[CCUtility trasformedOCFileToCCMetadata:itemDto fileNamePrint:itemDto.fileName serverUrl:serverUrl directoryID:directoryID autoUploadFileName:autoUploadFileName autoUploadDirectory:autoUploadDirectory activeAccount:_metadataNet.account directoryUser:directoryUser]];
            }
    
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(searchSuccess:metadatas:)])
                    [self.delegate searchSuccess:_metadataNet metadatas:metadatas];
            });
        
        });
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *token, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;

        // Error
        if ([self.delegate respondsToSelector:@selector(searchFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate searchFailure:_metadataNet message:NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil) errorCode:errorCode];
            else
                [self.delegate searchFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Setting Favorite =====
#pragma --------------------------------------------------------------------------------------------

- (void)settingFavorite
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    NSString *path = [_activeUrl stringByAppendingString:dav];

    [communication settingFavoriteServer:path andFileOrFolderPath:_metadataNet.fileName favorite:[_metadataNet.options boolValue] withUserSessionToken:nil onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer, NSString *token) {
        
        if ([self.delegate respondsToSelector:@selector(settingFavoriteSuccess:)])
            [self.delegate settingFavoriteSuccess:_metadataNet];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *token, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(settingFavoriteFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate settingFavoriteFailure:_metadataNet message:NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil) errorCode:errorCode];
            else
                [self.delegate settingFavoriteFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];

}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Listing Favorites =====
#pragma --------------------------------------------------------------------------------------------

- (void)listingFavorites
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    NSString *path = [_activeUrl stringByAppendingString:dav];
    NSString *folder = [_metadataNet.serverUrl stringByReplacingOccurrencesOfString:[CCUtility getHomeServerUrlActiveUrl:_activeUrl] withString:@""];
    
    [communication listingFavorites:path folder:folder withUserSessionToken:nil onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer, NSString *token) {
        
        NSMutableArray *metadatas = [NSMutableArray new];
        
        NSString *autoUploadFileName = [[NCManageDatabase sharedInstance] getAccountAutoUploadFileName];
        NSString *autoUploadDirectory = [[NCManageDatabase sharedInstance] getAccountAutoUploadDirectory:_activeUrl];

        NSString *directoryUser = [CCUtility getDirectoryActiveUser:_activeUser activeUrl:_activeUrl];
        
        // Order by fileNamePath
        items = [items sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            
            OCFileDto *record1 = obj1, *record2 = obj2;
            
            NSString *path1 = [[record1.filePath stringByAppendingString:record1.fileName] lowercaseString];
            NSString *path2 = [[record2.filePath stringByAppendingString:record2.fileName] lowercaseString];
            
            return [path1 compare:path2];
            
        }];
        
        for(OCFileDto *itemDto in items) {
            
            itemDto.fileName = [itemDto.fileName stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            itemDto.filePath = [itemDto.filePath stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

            // Not in Crypto Cloud file
            NSString *fileName = itemDto.fileName;
            if (itemDto.isDirectory)
                fileName = [fileName substringToIndex:[fileName length] - 1];
            
            if ([CCUtility isFileCryptated:fileName])
                continue;
            
            // ----- BUG #942 ---------
            if ([itemDto.etag length] == 0) {
#ifndef EXTENSION
                [app messageNotification:@"Server error" description:@"Metadata fileID absent, record excluded, please fix" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:0];
#endif
                continue;
            }
            // ------------------------
            
            NSString *serverUrl = [NSString stringWithFormat:@"%@/files/%@", dav, _activeUser];
            serverUrl = [itemDto.filePath stringByReplacingOccurrencesOfString:serverUrl withString:@""];
            
            /* TRIM */
            if ([serverUrl hasPrefix:@"/"])
                serverUrl = [serverUrl substringFromIndex:1];
            if ([serverUrl hasSuffix:@"/"])
                serverUrl = [serverUrl substringToIndex:[serverUrl length] - 1];
            /*      */
            
            serverUrl = [CCUtility stringAppendServerUrl:[_activeUrl stringByAppendingString:webDAV] addFileName:serverUrl];
            
            NSString *directoryID = [[NCManageDatabase sharedInstance] addDirectoryWithServerUrl:serverUrl permissions:itemDto.permissions];
            
            [metadatas addObject:[CCUtility trasformedOCFileToCCMetadata:itemDto fileNamePrint:itemDto.fileName serverUrl:serverUrl directoryID:directoryID autoUploadFileName:autoUploadFileName autoUploadDirectory:autoUploadDirectory activeAccount:_metadataNet.account directoryUser:directoryUser]];
        }
        
        if ([self.delegate respondsToSelector:@selector(listingFavoritesSuccess:metadatas:)])
            [self.delegate listingFavoritesSuccess:_metadataNet metadatas:metadatas];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *token, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(listingFavoritesFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate listingFavoritesFailure:_metadataNet message:NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil) errorCode:errorCode];
            else
                [self.delegate listingFavoritesFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }
        
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
    NSString *autoUploadFileName = [[NCManageDatabase sharedInstance] getAccountAutoUploadFileName];
    NSString *autoUploadDirectory = [[NCManageDatabase sharedInstance] getAccountAutoUploadDirectory:_activeUrl];
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication createFolder:nameFolderURL onCommunication:communication withForbiddenCharactersSupported:YES successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        if ([self.delegate respondsToSelector:@selector(createFolderSuccess:)])
            [self.delegate createFolderSuccess:_metadataNet];
       
        [self complete];

    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message;
        
        if (([_metadataNet.fileName isEqualToString:autoUploadFileName] == YES && [_metadataNet.serverUrl isEqualToString:autoUploadDirectory] == YES))
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
        
        if (([_metadataNet.fileName isEqualToString:autoUploadFileName] == YES && [_metadataNet.serverUrl isEqualToString:autoUploadDirectory] == YES))
            message = nil;
        else {
            
            if (error.code == OCErrorForbidenCharacters)
                message = NSLocalizedStringFromTable(@"_forbidden_characters_from_server_", @"Error", nil);
            else
                message = NSLocalizedStringFromTable(@"_unknow_response_server_", @"Error", nil);
        }
        
        // Error
        if ([self.delegate respondsToSelector:@selector(createFolderFailure:message:errorCode:)]) {
            
            if (error.code == 503)
                [self.delegate createFolderFailure:_metadataNet message:NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil) errorCode:error.code];
            else
                [self.delegate createFolderFailure:_metadataNet message:message errorCode:error.code];
        }
        
        [self complete];
    }];
}

- (BOOL)automaticCreateFolderSync:(NSString *)folderPathName
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    __block BOOL noError = YES;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication readFile:folderPathName onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer) {
        
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        [communication createFolder:folderPathName onCommunication:communication withForbiddenCharactersSupported:YES successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
            
            [[NCManageDatabase sharedInstance] clearDateReadWithServerUrl:[CCUtility deletingLastPathComponentFromServerUrl:folderPathName] directoryID:nil];
            
            dispatch_semaphore_signal(semaphore);
            
        } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
            
            noError = NO;
            
            dispatch_semaphore_signal(semaphore);
            
        } errorBeforeRequest:^(NSError *error) {
            
            noError = NO;
            dispatch_semaphore_signal(semaphore);
        }];
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    return noError;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Delete =====
#pragma --------------------------------------------------------------------------------------------

- (void)deleteFileOrFolder
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    NSString *serverFileUrl = [NSString stringWithFormat:@"%@/%@", _metadataNet.serverUrl, _metadataNet.fileName];
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication deleteFileOrFolder:serverFileUrl onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        if ([_metadataNet.selector rangeOfString:selectorDelete].location != NSNotFound && [self.delegate respondsToSelector:@selector(deleteFileOrFolderSuccess:)])
            [self.delegate deleteFileOrFolderSuccess:_metadataNet];
        
        [self complete];
        
    } failureRquest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(deleteFileOrFolderFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate deleteFileOrFolderFailure:_metadataNet message:NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil) errorCode:errorCode];
            else
                [self.delegate deleteFileOrFolderFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }
        
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
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication moveFileOrFolder:origineURL toDestiny:destinazioneURL onCommunication:communication withForbiddenCharactersSupported:YES successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        if ([_metadataNet.selector isEqualToString:selectorRename] && [self.delegate respondsToSelector:@selector(renameSuccess:)])
            [self.delegate renameSuccess:_metadataNet];
        
        if ([_metadataNet.selector rangeOfString:selectorMove].location != NSNotFound && [self.delegate respondsToSelector:@selector(moveSuccess:)])
            [self.delegate moveSuccess:_metadataNet];
        
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
        
        // Error
        if ([self.delegate respondsToSelector:@selector(renameMoveFileOrFolderFailure:message:errorCode:)]) {
            
            if (error.code == 503)
                [self.delegate renameMoveFileOrFolderFailure:_metadataNet message:NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil) errorCode:error.code];
            else
                [self.delegate renameMoveFileOrFolderFailure:_metadataNet message:message errorCode:error.code];
        }
        
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
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication readFile:fileName onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer) {
        
        tableAccount *recordAccount = [[NCManageDatabase sharedInstance] getAccountActive];
        
        if ([recordAccount.account isEqualToString:_metadataNet.account] && [items count] > 0) {
            
            tableMetadata *metadata = [tableMetadata new];
            
            OCFileDto *itemDto = [items objectAtIndex:0];
            itemDto.fileName = _metadataNet.fileName;
            
            NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:_metadataNet.serverUrl];
            NSString *autoUploadFileName = [[NCManageDatabase sharedInstance] getAccountAutoUploadFileName];
            NSString *autoUploadDirectory = [[NCManageDatabase sharedInstance] getAccountAutoUploadDirectory:_activeUrl];

            NSString *directoryUser = [CCUtility getDirectoryActiveUser:_activeUser activeUrl:_activeUrl];
        
            metadata = [CCUtility trasformedOCFileToCCMetadata:itemDto fileNamePrint:_metadataNet.fileNamePrint serverUrl:_metadataNet.serverUrl directoryID:directoryID autoUploadFileName:autoUploadFileName autoUploadDirectory:autoUploadDirectory activeAccount:_metadataNet.account directoryUser:directoryUser];
                        
            if([self.delegate respondsToSelector:@selector(readFileSuccess:metadata:)])
                [self.delegate readFileSuccess:_metadataNet metadata:metadata];
        }
        
        // BUG 1038
        if ([items count] == 0) {
       
#ifndef EXTENSION
            [app messageNotification:@"Server error" description:@"Read File WebDAV : [items NULL] please fix" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:0];
#endif
        }
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        tableAccount *recordAccount = [[NCManageDatabase sharedInstance] getAccountActive];
        
        _metadataNet.errorRetry++;
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(readFileFailure:message:errorCode:)] && [recordAccount.account isEqualToString:_metadataNet.account]) {
            
            if (errorCode == 503)
                [self.delegate readFileFailure:_metadataNet message:NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil) errorCode:errorCode];
            else
                [self.delegate readFileFailure:_metadataNet message:[CCError manageErrorOC:response.statusCode error:error] errorCode:errorCode];
        }
        
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
    [communication setUserAgent:[CCUtility getUserAgent]];
    
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
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication readSharedByServer:[_activeUrl stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer) {
        
        BOOL openWindow = NO;
        
        [[self getShareID] removeAllObjects];
        
        tableAccount *recordAccount = [[NCManageDatabase sharedInstance] getAccountActive];
        
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
        
        // Error
        if ([self.delegate respondsToSelector:@selector(shareFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate shareFailure:_metadataNet message:NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil) errorCode:errorCode];
            else
                [self.delegate shareFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }
        
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
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication shareFileOrFolderByServer:[_activeUrl stringByAppendingString:@"/"] andFileOrFolderPath:[_metadataNet.fileName encodeString:NSUTF8StringEncoding] andPassword:[_metadataNet.password encodeString:NSUTF8StringEncoding] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *token, NSString *redirectedServer) {
        
        [self readShareServer];
        
    } failureRequest :^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;

        // Error
        if ([self.delegate respondsToSelector:@selector(shareFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate shareFailure:_metadataNet message:NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil) errorCode:errorCode];
            else
                [self.delegate shareFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }
        
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
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication shareWith:_metadataNet.share shareeType:_metadataNet.shareeType inServer:[_activeUrl stringByAppendingString:@"/"] andFileOrFolderPath:[_metadataNet.fileName encodeString:NSUTF8StringEncoding] andPermissions:_metadataNet.sharePermission onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        [self readShareServer];
                
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;

        // Error
        if ([self.delegate respondsToSelector:@selector(shareFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate shareFailure:_metadataNet message:NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil) errorCode:errorCode];
            else
                [self.delegate shareFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }
        
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
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication updateShare:[_metadataNet.share intValue] ofServerPath:[_activeUrl stringByAppendingString:@"/"] withPasswordProtect:[_metadataNet.password encodeString:NSUTF8StringEncoding] andExpirationTime:_metadataNet.expirationTime andPermissions:_metadataNet.sharePermission onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        [self readShareServer];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
#ifndef EXTENSION
        [app messageNotification:@"_error_" description:[CCError manageErrorOC:response.statusCode error:error] visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:error.code];
#endif
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;

        // Error
        if ([self.delegate respondsToSelector:@selector(shareFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate shareFailure:_metadataNet message:NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil) errorCode:errorCode];
            else
                [self.delegate shareFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }
        
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
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication unShareFileOrFolderByServer:[_activeUrl stringByAppendingString:@"/"] andIdRemoteShared:[_metadataNet.share intValue] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        if([self.delegate respondsToSelector:@selector(unShareSuccess:)])
            [self.delegate unShareSuccess:_metadataNet];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
#ifndef EXTENSION
        [app messageNotification:@"_error_" description:[CCError manageErrorOC:response.statusCode error:error] visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:error.code];
#endif
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;

        // Error
        if ([self.delegate respondsToSelector:@selector(shareFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate shareFailure:_metadataNet message:NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil) errorCode:errorCode];
            else
                [self.delegate shareFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }
        
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
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication searchUsersAndGroupsWith:_metadataNet.options forPage:1 with:50 ofServer:[_activeUrl stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *itemList, NSString *redirectedServer) {
        
        if([self.delegate respondsToSelector:@selector(getUserAndGroupSuccess:items:)])
            [self.delegate getUserAndGroupSuccess:_metadataNet items:itemList];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;

        // Error
        if ([self.delegate respondsToSelector:@selector(getUserAndGroupFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate getUserAndGroupFailure:_metadataNet message:NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil) errorCode:errorCode];
            else
                [self.delegate getUserAndGroupFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Activity =====
#pragma --------------------------------------------------------------------------------------------

- (void)getActivityServer
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getActivityServer:[_activeUrl stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *listOfActivity, NSString *redirectedServer) {
        
        if ([self.delegate respondsToSelector:@selector(getActivityServerSuccess:)])
            [self.delegate getActivityServerSuccess:listOfActivity];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(getActivityServerFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate getActivityServerFailure:_metadataNet message:NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil) errorCode:errorCode];
            else
                [self.delegate getActivityServerFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== External Sites =====
#pragma --------------------------------------------------------------------------------------------

- (void)getExternalSitesServer
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getExternalSitesServer:[_activeUrl stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *listOfExternalSites, NSString *redirectedServer) {
        
        if ([self.delegate respondsToSelector:@selector(getExternalSitesServerSuccess:)])
            [self.delegate getExternalSitesServerSuccess:listOfExternalSites];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(getExternalSitesServerFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate getExternalSitesServerFailure:_metadataNet message:NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil) errorCode:errorCode];
            else
                [self.delegate getExternalSitesServerFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];

}
#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Middleware Ping =====
#pragma --------------------------------------------------------------------------------------------

/*
- (void)middlewarePing
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getMiddlewarePing:_metadataNet.serverUrl onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *listOfExternalSites, NSString *redirectedServer) {
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(getExternalSitesServerFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate getExternalSitesServerFailure:_metadataNet message:NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil) errorCode:errorCode];
            else
                [self.delegate getExternalSitesServerFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
    
}
*/

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Notification =====
#pragma --------------------------------------------------------------------------------------------

- (void)getNotificationServer
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getNotificationServer:[_activeUrl stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *listOfNotifications, NSString *redirectedServer) {
        
        if ([self.delegate respondsToSelector:@selector(getNotificationServerSuccess:)])
            [self.delegate getNotificationServerSuccess:listOfNotifications];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(getNotificationServerFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate getNotificationServerFailure:_metadataNet message:NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil) errorCode:errorCode];
            else
                [self.delegate getNotificationServerFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:_activeUrl fileID:@"" action:k_activityDebugActionGetNotification selector:@"" note:[error.userInfo valueForKey:@"NSLocalizedDescription"] type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:_activeUrl];
        
        [self complete];
    }];
}

- (void)setNotificationServer
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    NSString *type = _metadataNet.options;
    
    [communication setNotificationServer:_metadataNet.serverUrl type:type onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        if ([self.delegate respondsToSelector:@selector(setNotificationServerSuccess:)])
            [self.delegate setNotificationServerSuccess:_metadataNet];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(setNotificationServerFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate setNotificationServerFailure:_metadataNet message:NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil) errorCode:errorCode];
            else
                [self.delegate setNotificationServerFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

- (void)subscribingNextcloudServer
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    communication.kindOfCredential = credentialNotSet;
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    NSDictionary *parameter = _metadataNet.options;
    
    NSString *pushToken = [parameter objectForKey:@"pushToken"];
    NSString *pushTokenHash = [parameter objectForKey:@"pushTokenHash"];
    NSString *devicePublicKey = [parameter objectForKey:@"devicePublicKey"];
    
    // encode URL
    devicePublicKey = [CCUtility URLEncodeStringFromString:devicePublicKey];
    
    [communication subscribingNextcloudServerPush:_activeUrl pushTokenHash:pushTokenHash devicePublicKey:devicePublicKey proxyServerPath: [NCBrandOptions sharedInstance].pushNotificationServer onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *publicKey, NSString *deviceIdentifier, NSString *signature, NSString *redirectedServer) {
        
        // encode URL
        deviceIdentifier = [CCUtility URLEncodeStringFromString:deviceIdentifier];
        signature = [CCUtility URLEncodeStringFromString:signature];
    
        [communication subscribingPushProxy:[NCBrandOptions sharedInstance].pushNotificationServer pushToken:pushToken deviceIdentifier:deviceIdentifier deviceIdentifierSignature:signature userPublicKey:[CCUtility URLEncodeStringFromString:publicKey] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
            
            // Activity
            [[NCManageDatabase sharedInstance] addActivityClient:[NCBrandOptions sharedInstance].pushNotificationServer fileID:@"" action:k_activityDebugActionPushProxy selector:@"" note:@"Service registered." type:k_activityTypeSuccess verbose:k_activityVerboseHigh activeUrl:_activeUrl];
            
            [self complete];
            
        } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
           
            NSInteger errorCode = response.statusCode;
            if (errorCode == 0)
                errorCode = error.code;
            
            // Error
            if ([self.delegate respondsToSelector:@selector(subscribingNextcloudServerFailure:message:errorCode:)]) {
                
                if (errorCode == 503)
                    [self.delegate subscribingNextcloudServerFailure:_metadataNet message:NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil) errorCode:errorCode];
                else
                    [self.delegate subscribingNextcloudServerFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
            }
            
            // Request trusted certificated
            if ([error code] == NSURLErrorServerCertificateUntrusted)
                [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];

            // Activity
            [[NCManageDatabase sharedInstance] addActivityClient:[NCBrandOptions sharedInstance].pushNotificationServer fileID:@"" action:k_activityDebugActionPushProxy selector:@"" note:[error.userInfo valueForKey:@"NSLocalizedDescription"] type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:_activeUrl];
            
            [self complete];
        }];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;
    
        // Error
        if ([self.delegate respondsToSelector:@selector(subscribingNextcloudServerFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate subscribingNextcloudServerFailure:_metadataNet message:NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil) errorCode:errorCode];
            else
                [self.delegate subscribingNextcloudServerFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }

        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:_activeUrl fileID:@"" action:k_activityDebugActionServerPush selector:@"" note:[error.userInfo valueForKey:@"NSLocalizedDescription"] type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:_activeUrl];
        
        [self complete];
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  User Profile =====
#pragma --------------------------------------------------------------------------------------------

- (void)getUserProfile
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getUserProfileServer:[_activeUrl stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, OCUserProfile *userProfile, NSString *redirectedServer) {
        
        if ([self.delegate respondsToSelector:@selector(getUserProfileSuccess:userProfile:)])
            [self.delegate getUserProfileSuccess:_metadataNet userProfile:userProfile];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(getUserProfileFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate getUserProfileFailure:_metadataNet message:NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil) errorCode:errorCode];
            else
                [self.delegate getUserProfileFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}


#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Server =====
#pragma --------------------------------------------------------------------------------------------

- (NSError *)checkServerSync:(NSString *)serverUrl
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    __block NSError *returnError;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
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

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Capabilities =====
#pragma --------------------------------------------------------------------------------------------

- (void)getCapabilitiesOfServer
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getCapabilitiesOfServer:[_activeUrl stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, OCCapabilities *capabilities, NSString *redirectedServer) {
        
        tableAccount *recordAccount = [[NCManageDatabase sharedInstance] getAccountActive];
        
        if ([self.delegate respondsToSelector:@selector(getCapabilitiesOfServerSuccess:)] && [recordAccount.account isEqualToString:_metadataNet.account])
            [self.delegate getCapabilitiesOfServerSuccess:capabilities];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0)
            errorCode = error.code;

        // Error
        if ([self.delegate respondsToSelector:@selector(getCapabilitiesOfServerFailure:message:errorCode:)]) {

            if (errorCode == 503)
                [self.delegate getCapabilitiesOfServerFailure:_metadataNet message:NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil) errorCode:errorCode];
            else
                [self.delegate getCapabilitiesOfServerFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];

        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:_activeUrl fileID:@"" action:k_activityDebugActionCapabilities selector:@"" note:[error.userInfo valueForKey:@"NSLocalizedDescription"] type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:_activeUrl];
        
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
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([[CCCertificate sharedManager] checkTrustedChallenge:challenge]) {
            completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]);
        } else {
            completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
        }
    });
}

@end
