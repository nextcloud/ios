//
//  OCnetworking.m
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 10/05/15.
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

#import "OCNetworking.h"

#import "CCUtility.h"
#import "CCGraphics.h"
#import "CCCertificate.h"
#import "NSString+Encode.h"
#import "NCBridgeSwift.h"

#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

@interface OCnetworking ()
{
    NSString *_activeUser;
    NSString *_activeUserID;
    NSString *_activePassword;
    NSString *_activeUrl;
}
@end

@implementation OCnetworking

- (id)initWithDelegate:(id)delegate metadataNet:(CCMetadataNet *)metadataNet withUser:(NSString *)withUser withUserID:(NSString *)withUserID withPassword:(NSString *)withPassword withUrl:(NSString *)withUrl
{
    self = [super init];
    
    if (self) {
        
        _delegate = delegate;
        
        _metadataNet = [CCMetadataNet new];
        _metadataNet = [metadataNet copy];
        
        _activeUser = withUser;
        _activeUserID = withUserID;
        _activePassword = withPassword;
        _activeUrl = withUrl;
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
#pragma mark ===== Server =====
#pragma --------------------------------------------------------------------------------------------

- (void)checkServer:(NSString *)serverUrl success:(void (^)(void))success failure:(void (^)(NSString *message, NSInteger errorCode))failure
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
        
    [communication checkServer:serverUrl onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        success();
            
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message;

        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if (errorCode == 503)
            message = NSLocalizedString(@"_server_error_retry_", nil);
        else
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
    
        failure(message, errorCode);
    }];
}

- (void)serverStatus:(NSString *)serverUrl success:(void(^)(NSString *serverProductName, NSInteger versionMajor, NSInteger versionMicro, NSInteger versionMinor))success failure:(void (^)(NSString *message, NSInteger errorCode))failure
{
    NSString *urlTest = [serverUrl stringByAppendingString:k_serverStatus];
    
    // Remove stored cookies
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [storage cookies])
    {
        [storage deleteCookie:cookie];
    }
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlTest] cachePolicy:0 timeoutInterval:20.0];
    [request addValue:[CCUtility getUserAgent] forHTTPHeaderField:@"User-Agent"];
    [request addValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];
    
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:self.delegate delegateQueue:nil];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            if (error) {
                
                NSString *message;
                NSInteger errorCode;
                
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
                errorCode = httpResponse.statusCode;
                
                if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
                    errorCode = error.code;
                
                // Error
                if (errorCode == 503)
                    message = NSLocalizedString(@"_server_error_retry_", nil);
                else
                    message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
                
                failure(message, errorCode);
                
            } else {
                
                NSString *serverProductName = @"";
                NSString *serverVersion = @"0.0.0";
                NSString *serverVersionString = @"0.0.0";
                
                NSInteger versionMajor = 0;
                NSInteger versionMicro = 0;
                NSInteger versionMinor = 0;
                
                NSError *error;
                NSDictionary *jsongParsed = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
                
                if (error) {
                    failure(error.description, error.code);
                    return;
                }
                
                serverProductName = [[jsongParsed valueForKey:@"productname"] lowercaseString];
                serverVersion = [jsongParsed valueForKey:@"version"];
                serverVersionString = [jsongParsed valueForKey:@"versionstring"];
                
                NSArray *arrayVersion = [serverVersionString componentsSeparatedByString:@"."];
                
                if (arrayVersion.count == 1) {
                    versionMajor = [arrayVersion[0] integerValue];
                } else if (arrayVersion.count == 2) {
                    versionMajor = [arrayVersion[0] integerValue];
                    versionMinor = [arrayVersion[1] integerValue];
                } else if (arrayVersion.count >= 3) {
                    versionMajor = [arrayVersion[0] integerValue];
                    versionMinor = [arrayVersion[1] integerValue];
                    versionMicro = [arrayVersion[2] integerValue];
                }
                
                success(serverProductName, versionMajor, versionMicro, versionMinor);
            }
        });
        
    }];
    
    [task resume];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== download =====
#pragma --------------------------------------------------------------------------------------------

- (NSURLSessionTask *)downloadFileNameServerUrl:(NSString *)fileNameServerUrl fileNameLocalPath:(NSString *)fileNameLocalPath communication:(OCCommunication *)communication success:(void (^)(int64_t length, NSString *etag, NSDate *date))success failure:(void (^)(NSString *message, NSInteger errorCode))failure
{
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    NSURLSessionTask *sessionTask = [communication downloadFileSession:fileNameServerUrl toDestiny:fileNameLocalPath defaultPriority:YES onCommunication:communication progress:^(NSProgress *progress) {
        //float percent = roundf (progress.fractionCompleted * 100);
    } successRequest:^(NSURLResponse *response, NSURL *filePath) {

        int64_t totalUnitCount = 0;
        NSDate *date = [NSDate date];
        NSDateFormatter *dateFormatter = [NSDateFormatter new];
        NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        [dateFormatter setLocale:enUSPOSIXLocale];
        [dateFormatter setDateFormat:@"EEE, dd MMM y HH:mm:ss zzz"];
        NSError *error;
        
        NSDictionary *fields = [(NSHTTPURLResponse*)response allHeaderFields];

        NSString *contentLength = [fields objectForKey:@"Content-Length"];
        if(contentLength) {
            totalUnitCount = (int64_t) [contentLength longLongValue];
        }
        NSString *dateString = [fields objectForKey:@"Date"];
        if (dateString) {
            if (![dateFormatter getObjectValue:&date forString:dateString range:nil error:&error]) {
                date = [NSDate date];
            }
        } else {
            date = [NSDate date];
        }
        
        NSString *etag = [CCUtility removeForbiddenCharactersFileSystem:[fields objectForKey:@"OC-ETag"]];
        if (etag == nil) {
            failure(@"Internal error", k_CCErrorInternalError);
        } else {
            success(totalUnitCount, etag, date);
        }
        
    } failureRequest:^(NSURLResponse *response, NSError *error) {
        
        NSString *message;
        NSInteger errorCode;
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
        errorCode = httpResponse.statusCode;
        
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if (errorCode == 503)
            message = NSLocalizedString(@"_server_error_retry_", nil);
        else
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        
        failure(message, errorCode);
    }];
    
    return sessionTask;
}

- (NSURLSessionTask *)downloadFile:(NSString *)url fileNameLocalPath:(NSString *)fileNameLocalPath success:(void (^)())success failure:(void (^)(NSString *message, NSInteger errorCode))failure
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;

    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    NSURLSessionTask *sessionTask = [communication downloadFileSession:url toDestiny:fileNameLocalPath defaultPriority:YES onCommunication:communication progress:^(NSProgress *progress) {
        //float percent = roundf (progress.fractionCompleted * 100);
    } successRequest:^(NSURLResponse *response, NSURL *filePath) {
        
        success();
        
    } failureRequest:^(NSURLResponse *response, NSError *error) {
        
        NSString *message;
        NSInteger errorCode;
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
        errorCode = httpResponse.statusCode;
        
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if (errorCode == 503)
            message = NSLocalizedString(@"_server_error_retry_", nil);
        else
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        
        failure(message, errorCode);
    }];
    
    return sessionTask;
}


#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== upload =====
#pragma --------------------------------------------------------------------------------------------

- (NSURLSessionTask *)uploadFileNameServerUrl:(NSString *)fileNameServerUrl fileNameLocalPath:(NSString *)fileNameLocalPath communication:(OCCommunication *)communication success:(void(^)(NSString *fileID, NSString *etag, NSDate *date))success failure:(void (^)(NSString *message, NSInteger errorCode))failure
{    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    NSURLSessionTask *sessionTask = [communication uploadFileSession:fileNameLocalPath toDestiny:fileNameServerUrl onCommunication:communication progress:^(NSProgress *progress) {
        //float percent = roundf (progress.fractionCompleted * 100);
    } successRequest:^(NSURLResponse *response, NSString *redirectedServer) {
    
        NSDictionary *fields = [(NSHTTPURLResponse*)response allHeaderFields];

        NSString *fileID = [CCUtility removeForbiddenCharactersFileSystem:[fields objectForKey:@"OC-FileId"]];
        NSString *etag = [CCUtility removeForbiddenCharactersFileSystem:[fields objectForKey:@"OC-ETag"]];
        NSDate *date = [CCUtility dateEnUsPosixFromCloud:[fields objectForKey:@"Date"]];
        
        success(fileID, etag, date);
        
    } failureRequest:^(NSURLResponse *response, NSString *redirectedServer, NSError *error) {
        
        NSString *message;
        NSInteger errorCode;
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
        errorCode = httpResponse.statusCode;
        
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if (errorCode == 503)
            message = NSLocalizedString(@"_server_error_retry_", nil);
        else
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        
        failure(message, errorCode);
        
    } failureBeforeRequest:^(NSError *error) {
        failure(@"", error.code);
    }];
    
    return sessionTask;
}
#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== downloadThumbnail / downloadPreview =====
#pragma --------------------------------------------------------------------------------------------

/*
- (void)downloadThumbnailWithMetadata:(tableMetadata*)metadata withWidth:(CGFloat)width andHeight:(CGFloat)height completion:(void (^)(NSString *message, NSInteger errorCode))completion
{
    NSString *file = [NSString stringWithFormat:@"%@/%@.ico", [CCUtility getDirectoryProviderStorageFileID:metadata.fileID], metadata.fileNameView];

    if ([[NSFileManager defaultManager] fileExistsAtPath:file]) {
        
        completion(nil, 0);
        
    } else {
        
        OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
        
        [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
        [communication setUserAgent:[CCUtility getUserAgent]];
        
        [communication getRemoteThumbnailByServer:_activeUrl ofFilePath:[CCUtility returnFileNamePathFromFileName:metadata.fileName serverUrl:metadata.serverUrl activeUrl:_activeUrl] withWidth:width andHeight:height onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSData *thumbnail, NSString *redirectedServer) {
            
            [thumbnail writeToFile:file atomically:YES];
            
            completion(nil, 0);
            
        } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
            
            NSString *message;

            NSInteger errorCode = response.statusCode;
            if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
                errorCode = error.code;
            
            // Error
            if (errorCode == 503)
                message = NSLocalizedString(@"_server_error_retry_", nil);
            else
                message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
            
            completion(message, errorCode);
        }];
    }
}
*/

- (void)downloadPreviewTrashWithFileID:(NSString *)fileID fileName:(NSString *)fileName account:(NSString *)account completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion
{
    NSString *file = [NSString stringWithFormat:@"%@/%@.ico", [CCUtility getDirectoryProviderStorageFileID:fileID], fileName];
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
     
        completion(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:file]) {
        
        completion(account, nil, 0);
        
    } else {
        
        OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
        
        [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
        [communication setUserAgent:[CCUtility getUserAgent]];
        
        [communication getRemotePreviewTrashByServer:tableAccount.url ofFileID:fileID onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSData *preview, NSString *redirectedServer) {
            
            [preview writeToFile:file atomically:YES];
            
            completion(account, nil, 0);
            
        } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
            
            NSString *message;
            
            NSInteger errorCode = response.statusCode;
            if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
                errorCode = error.code;
            
            // Error
            if (errorCode == 503)
                message = NSLocalizedString(@"_server_error_retry_", nil);
            else
                message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
            
            completion(account, message, errorCode);
        }];
    }
}

- (void)downloadPreviewWithMetadata:(tableMetadata*)metadata withWidth:(CGFloat)width andHeight:(CGFloat)height completion:(void (^)(NSString *message, NSInteger errorCode))completion
{
    NSString *file = [NSString stringWithFormat:@"%@/%@.ico", [CCUtility getDirectoryProviderStorageFileID:metadata.fileID], metadata.fileNameView];
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", metadata.account]];
    if (tableAccount == nil) {
        
        completion(NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
        
    [communication getRemotePreviewByServer:tableAccount.url ofFilePath:[CCUtility returnFileNamePathFromFileName:metadata.fileName serverUrl:metadata.serverUrl activeUrl:tableAccount.url] withWidth:width andHeight:height andA:1 andMode:@"cover" onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSData *preview, NSString *redirectedServer) {

        [preview writeToFile:file atomically:YES];
            
        completion(nil, 0);
            
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
            
        NSString *message;
            
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
            
        // Error
        if (errorCode == 503)
            message = NSLocalizedString(@"_server_error_retry_", nil);
        else
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
            
        completion(message, errorCode);
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Read Folder =====
#pragma --------------------------------------------------------------------------------------------

- (void)readFolder:(NSString *)serverUrl depth:(NSString *)depth account:(NSString *)account success:(void(^)(NSString *account, NSArray *metadatas, tableMetadata *metadataFolder))success failure:(void (^)(NSString *account, NSString *message, NSInteger errorCode))failure
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        failure(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication readFolder:serverUrl depth:depth withUserSessionToken:nil onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer, NSString *token) {
        
        // Check items > 0
        if ([items count] == 0) {
                
#ifndef EXTENSION
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                
            [appDelegate messageNotification:@"Server error" description:@"Read Folder WebDAV : [items NULL] please fix" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:k_CCErrorInternalError];
#endif
            failure(account, NSLocalizedString(@"Read Folder WebDAV : [items NULL] please fix", nil), k_CCErrorInternalError);

        } else {
                
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                
                BOOL showHiddenFiles = [CCUtility getShowHiddenFiles];
                BOOL isFolderEncrypted = [CCUtility isFolderEncrypted:serverUrl account:account];
                    
                // directory [0]
                OCFileDto *itemDtoFolder = [items objectAtIndex:0];
                //NSDate *date = [NSDate dateWithTimeIntervalSince1970:itemDtoDirectory.date];
                    
                NSMutableArray *metadatas = [NSMutableArray new];
                tableMetadata *metadataFolder = [tableMetadata new];
                    
                NSString *autoUploadFileName = [[NCManageDatabase sharedInstance] getAccountAutoUploadFileName];
                NSString *autoUploadDirectory = [[NCManageDatabase sharedInstance] getAccountAutoUploadDirectory:tableAccount.url];
                    
                NSString *serverUrlFolder;

                // Metadata . (self Folder)
                if ([serverUrl isEqualToString:[CCUtility getHomeServerUrlActiveUrl:tableAccount.url]]) {
                        
                    // root folder
                    serverUrlFolder = k_serverUrl_root;
                    metadataFolder = [CCUtility trasformedOCFileToCCMetadata:itemDtoFolder fileName:@"." serverUrl:serverUrlFolder autoUploadFileName:autoUploadFileName autoUploadDirectory:autoUploadDirectory activeAccount:account isFolderEncrypted:isFolderEncrypted];
                        
                } else {
                        
                    serverUrlFolder = [CCUtility deletingLastPathComponentFromServerUrl:serverUrl];
                    metadataFolder = [CCUtility trasformedOCFileToCCMetadata:itemDtoFolder fileName:[serverUrl lastPathComponent] serverUrl:serverUrlFolder autoUploadFileName:autoUploadFileName autoUploadDirectory:autoUploadDirectory activeAccount:account isFolderEncrypted:isFolderEncrypted];
                }
                    
                // Add metadata folder
                (void)[[NCManageDatabase sharedInstance] addDirectoryWithEncrypted:itemDtoFolder.isEncrypted favorite:itemDtoFolder.isFavorite fileID:itemDtoFolder.ocId permissions:itemDtoFolder.permissions serverUrl:serverUrl account:account];

                NSArray *itemsSortedArray = [items sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
                        
                    NSString *first = [(OCFileDto*)a fileName];
                    NSString *second = [(OCFileDto*)b fileName];
                    return [[first lowercaseString] compare:[second lowercaseString]];
                }];
                    
                for (NSUInteger i=1; i < [itemsSortedArray count]; i++) {
                        
                    OCFileDto *itemDto = [itemsSortedArray objectAtIndex:i];
                    NSString *fileName = [itemDto.fileName stringByReplacingOccurrencesOfString:@"/" withString:@""];
                        
                    // Skip hidden files
                    if (fileName.length > 0) {
                        if (!showHiddenFiles && [[fileName substringToIndex:1] isEqualToString:@"."])
                            continue;
                    } else {
                        continue;
                    }
                        
                    if (itemDto.isDirectory) {
                        (void)[[NCManageDatabase sharedInstance] addDirectoryWithEncrypted:itemDto.isEncrypted favorite:itemDto.isFavorite fileID:itemDto.ocId permissions:itemDto.permissions serverUrl:[CCUtility stringAppendServerUrl:serverUrl addFileName:fileName] account:account];
                    }
                        
                    [metadatas addObject:[CCUtility trasformedOCFileToCCMetadata:itemDto fileName:itemDto.fileName serverUrl:serverUrl autoUploadFileName:autoUploadFileName autoUploadDirectory:autoUploadDirectory activeAccount:account isFolderEncrypted:isFolderEncrypted]];
                }
                    
                dispatch_async(dispatch_get_main_queue(), ^{
                    success(account, metadatas, metadataFolder);
                });
            });
        }
    
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *token, NSString *redirectedServer) {
        
        NSString *message;
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if (errorCode == 503)
            message = NSLocalizedString(@"_server_error_retry_", nil);
        else
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:serverUrl fileID:@"" action:k_activityDebugActionReadFolder selector:@"" note:[error.userInfo valueForKey:@"NSLocalizedDescription"] type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:tableAccount.url];

        failure(account, message, errorCode);
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== ReadFile =====
#pragma --------------------------------------------------------------------------------------------

- (void)readFile:(NSString *)fileName serverUrl:(NSString *)serverUrl account:(NSString *)account success:(void(^)(NSString *account, tableMetadata *metadata))success failure:(void (^)(NSString *account, NSString *message, NSInteger errorCode))failure
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        failure(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    NSString *fileNamePath;

    if (fileName) {
        fileNamePath = [NSString stringWithFormat:@"%@/%@", serverUrl, fileName];
    } else {
        fileName= @".";
        fileNamePath = serverUrl;
    }
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication readFile:fileNamePath onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer) {
        
        BOOL isFolderEncrypted = [CCUtility isFolderEncrypted:serverUrl account:account];
            
        if ([items count] > 0) {
                
            tableMetadata *metadata = [tableMetadata new];
                
            OCFileDto *itemDto = [items objectAtIndex:0];
                
            NSString *autoUploadFileName = [[NCManageDatabase sharedInstance] getAccountAutoUploadFileName];
            NSString *autoUploadDirectory = [[NCManageDatabase sharedInstance] getAccountAutoUploadDirectory:tableAccount.url];
                    
            metadata = [CCUtility trasformedOCFileToCCMetadata:itemDto fileName:fileName serverUrl:serverUrl autoUploadFileName:autoUploadFileName autoUploadDirectory:autoUploadDirectory activeAccount:account isFolderEncrypted:isFolderEncrypted];
                    
            success(account, metadata);
            
        // BUG 1038 item == 0
        } else {
                
#ifndef EXTENSION
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                
            [appDelegate messageNotification:@"Server error" description:@"Read File WebDAV : [items NULL] please fix" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:k_CCErrorInternalError];
#endif
            failure(account, NSLocalizedString(@"Read File WebDAV : [items NULL] please fix", nil), k_CCErrorInternalError);
        }
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message;
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if (errorCode == 503)
            message = NSLocalizedString(@"_server_error_retry_", nil);
        else
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:serverUrl fileID:@"" action:k_activityDebugActionReadFolder selector:@"" note:[error.userInfo valueForKey:@"NSLocalizedDescription"] type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:tableAccount.url];
        
        failure(account, message, errorCode);
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Search =====
#pragma --------------------------------------------------------------------------------------------

- (void)search
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    NSString *path = [_activeUrl stringByAppendingString:k_dav];
    NSString *folder = [_metadataNet.serverUrl stringByReplacingOccurrencesOfString:[CCUtility getHomeServerUrlActiveUrl:_activeUrl] withString:@""];
    NSString *dateLastModified;
    
    if (_metadataNet.date) {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        [dateFormatter setLocale:enUSPOSIXLocale];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
    
        dateLastModified = [dateFormatter stringFromDate:_metadataNet.date];
    }
    
    [communication search:path folder:folder fileName: [NSString stringWithFormat:@"%%%@%%", _metadataNet.fileName] depth:_metadataNet.depth dateLastModified:dateLastModified contentType:_metadataNet.contentType withUserSessionToken:nil onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer, NSString *token) {
        
        // Test active account
        tableAccount *recordAccount = [[NCManageDatabase sharedInstance] getAccountActive];
        if (![recordAccount.account isEqualToString:_metadataNet.account]) {
            if ([self.delegate respondsToSelector:@selector(searchSuccessFailure:metadatas:message:errorCode:)])
                [self.delegate searchSuccessFailure:_metadataNet metadatas:nil message:NSLocalizedString(@"_error_user_not_available_", nil) errorCode:k_CCErrorUserNotAvailble];

            [self complete];
            return;
        }
        
        NSMutableArray *metadatas = [NSMutableArray new];
        BOOL showHiddenFiles = [CCUtility getShowHiddenFiles];

        NSString *autoUploadFileName = [[NCManageDatabase sharedInstance] getAccountAutoUploadFileName];
        NSString *autoUploadDirectory = [[NCManageDatabase sharedInstance] getAccountAutoUploadDirectory:_activeUrl];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
            for(OCFileDto *itemDto in items) {
            
                NSString *serverUrl;
                BOOL isFolderEncrypted;

                NSString *fileName = [itemDto.fileName stringByReplacingOccurrencesOfString:@"/" withString:@""];

                // Skip hidden files
                if (fileName.length > 0) {
                    if (!showHiddenFiles && [[fileName substringToIndex:1] isEqualToString:@"."])
                        continue;
                } else
                    continue;
            
                NSRange firstInstance = [itemDto.filePath rangeOfString:[NSString stringWithFormat:@"%@/files/%@", k_dav, _activeUserID]];
                NSString *serverPath = [itemDto.filePath substringFromIndex:firstInstance.length+firstInstance.location+1];
                if ([serverPath hasSuffix:@"/"]) serverPath = [serverPath substringToIndex:[serverPath length] - 1];
                serverUrl = [CCUtility stringAppendServerUrl:[_activeUrl stringByAppendingString:k_webDAV] addFileName:serverPath];
                
                if (itemDto.isDirectory) {
                    (void)[[NCManageDatabase sharedInstance] addDirectoryWithEncrypted:itemDto.isEncrypted favorite:itemDto.isFavorite fileID:itemDto.ocId permissions:itemDto.permissions serverUrl:[NSString stringWithFormat:@"%@/%@", serverUrl, fileName] account:_metadataNet.account];
                }
                
                isFolderEncrypted = [CCUtility isFolderEncrypted:serverUrl account:_metadataNet.account];
                
                [metadatas addObject:[CCUtility trasformedOCFileToCCMetadata:itemDto fileName:itemDto.fileName serverUrl:serverUrl autoUploadFileName:autoUploadFileName autoUploadDirectory:autoUploadDirectory activeAccount:_metadataNet.account isFolderEncrypted:isFolderEncrypted]];
            }
    
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(searchSuccessFailure:metadatas:message:errorCode:)])
                    [self.delegate searchSuccessFailure:_metadataNet metadatas:metadatas message:nil errorCode:0];
            });
        
        });
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *token, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;

        // Error
        if ([self.delegate respondsToSelector:@selector(searchSuccessFailure:metadatas:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate searchSuccessFailure:_metadataNet metadatas:nil message:NSLocalizedString(@"_server_error_retry_", nil) errorCode:errorCode];
            else
                [self.delegate searchSuccessFailure:_metadataNet metadatas:nil message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }

        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Setting Favorite =====
#pragma --------------------------------------------------------------------------------------------

- (void)settingFavorite:(NSString *)fileName account:(NSString *)account favorite:(BOOL)favorite completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    NSString *server = [tableAccount.url stringByAppendingString:k_dav];

    [communication settingFavoriteServer:server andFileOrFolderPath:fileName favorite:favorite withUserSessionToken:nil onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer, NSString *token) {
        
        completion(account, nil, 0);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *token, NSString *redirectedServer) {
        
        NSString *message;
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if (errorCode == 503)
            message = NSLocalizedString(@"_server_error_retry_", nil);
        else
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        completion(account, message, errorCode);
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Listing Favorites =====
#pragma --------------------------------------------------------------------------------------------

- (void)listingFavorites:(NSString *)serverUrl account:(NSString *)account success:(void(^)(NSString *account, NSArray *metadatas))success failure:(void (^)(NSString* account, NSString *message, NSInteger errorCode))failure
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        failure(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    NSString *path = [tableAccount.url stringByAppendingString:k_dav];
    NSString *folder = [serverUrl stringByReplacingOccurrencesOfString:[CCUtility getHomeServerUrlActiveUrl:tableAccount.url] withString:@""];
    
    [communication listingFavorites:path folder:folder withUserSessionToken:nil onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer, NSString *token) {
        
        NSMutableArray *metadatas = [NSMutableArray new];
        BOOL showHiddenFiles = [CCUtility getShowHiddenFiles];

        NSString *autoUploadFileName = [[NCManageDatabase sharedInstance] getAccountAutoUploadFileName];
        NSString *autoUploadDirectory = [[NCManageDatabase sharedInstance] getAccountAutoUploadDirectory:tableAccount.url];
        
        // Order by fileNamePath
        items = [items sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                
            OCFileDto *record1 = obj1, *record2 = obj2;
                
            NSString *path1 = [[record1.filePath stringByAppendingString:record1.fileName] lowercaseString];
            NSString *path2 = [[record2.filePath stringByAppendingString:record2.fileName] lowercaseString];
                
            return [path1 compare:path2];
                
        }];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
           
            for(OCFileDto *itemDto in items) {
                    
                NSString *serverUrl;
                BOOL isFolderEncrypted;
                    
                NSString *fileName = [itemDto.fileName stringByReplacingOccurrencesOfString:@"/" withString:@""];
                    
                // Skip hidden files
                if (fileName.length > 0) {
                    if (!showHiddenFiles && [[fileName substringToIndex:1] isEqualToString:@"."])
                        continue;
                } else
                    continue;
                
                NSRange firstInstance = [itemDto.filePath rangeOfString:[NSString stringWithFormat:@"%@/files/%@", k_dav, tableAccount.userID]];
                NSString *serverPath = [itemDto.filePath substringFromIndex:firstInstance.length+firstInstance.location+1];
                if ([serverPath hasSuffix:@"/"])
                    serverPath = [serverPath substringToIndex:[serverPath length] - 1];
                serverUrl = [CCUtility stringAppendServerUrl:[tableAccount.url stringByAppendingString:k_webDAV] addFileName:serverPath];
                    
                if (itemDto.isDirectory) {
                    (void)[[NCManageDatabase sharedInstance] addDirectoryWithEncrypted:itemDto.isEncrypted favorite:itemDto.isFavorite fileID:itemDto.ocId permissions:itemDto.permissions serverUrl:[NSString stringWithFormat:@"%@/%@", serverUrl, fileName] account:account];
                }
                    
                isFolderEncrypted = [CCUtility isFolderEncrypted:serverUrl account:account];
                    
                [metadatas addObject:[CCUtility trasformedOCFileToCCMetadata:itemDto fileName:itemDto.fileName serverUrl:serverUrl autoUploadFileName:autoUploadFileName autoUploadDirectory:autoUploadDirectory activeAccount:account isFolderEncrypted:isFolderEncrypted]];
            }
                
            dispatch_async(dispatch_get_main_queue(), ^{
                success(account, metadatas);
            });
        });
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *token, NSString *redirectedServer) {
        
        NSString *message;

        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if (errorCode == 503)
            message = NSLocalizedString(@"_server_error_retry_", nil);
        else
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];

        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:serverUrl fileID:@"" action:k_activityDebugActionListingFavorites selector:@"" note:[error.userInfo valueForKey:@"NSLocalizedDescription"] type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:tableAccount.url];

        failure(account, message, errorCode);
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Create Folder =====
#pragma --------------------------------------------------------------------------------------------

- (void)createFolder:(NSString *)fileName serverUrl:(NSString *)serverUrl account:(NSString *)account success:(void(^)(NSString *account, NSString *fileID, NSDate *date))success failure:(void (^)(NSString *account, NSString *message, NSInteger errorCode))failure
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        failure(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    NSString *path = [NSString stringWithFormat:@"%@/%@", serverUrl, fileName];
    NSString *autoUploadFileName = [[NCManageDatabase sharedInstance] getAccountAutoUploadFileName];
    NSString *autoUploadDirectory = [[NCManageDatabase sharedInstance] getAccountAutoUploadDirectory:tableAccount.url];

    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication createFolder:path onCommunication:communication withForbiddenCharactersSupported:YES successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        NSDictionary *fields = [response allHeaderFields];
            
        NSString *fileID = [CCUtility removeForbiddenCharactersFileSystem:[fields objectForKey:@"OC-FileId"]];
        NSDate *date = [CCUtility dateEnUsPosixFromCloud:[fields objectForKey:@"Date"]];
            
        success(account, fileID, date);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {

        NSString *message;
        
        if (([fileName isEqualToString:autoUploadFileName] && [serverUrl isEqualToString:autoUploadDirectory]))
            message = nil;
        else
            message = [CCError manageErrorOC:response.statusCode error:error];
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;

        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:path fileID:@"" action:k_activityDebugActionCreateFolder selector:@"" note:NSLocalizedString(@"_not_possible_create_folder_", nil) type:k_activityTypeFailure verbose:k_activityVerboseDefault activeUrl:tableAccount.url];

        failure(account, message, errorCode);

    } errorBeforeRequest:^(NSError *error) {
        
        NSString *message;
    
        if (([fileName isEqualToString:autoUploadFileName] && [serverUrl isEqualToString:autoUploadDirectory]))
            message = nil;
        else {
            if (error.code == OCErrorForbidenCharacters)
                message = NSLocalizedString(@"_forbidden_characters_from_server_", nil);
            else
                message = NSLocalizedString(@"_unknow_response_server_", nil);
        }
        
        failure(account, message, error.code);
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Delete =====
#pragma --------------------------------------------------------------------------------------------

- (void)deleteFileOrFolder:(NSString *)path completion:(void (^)(NSString *message, NSInteger errorCode))completion
{    
//    NSString *serverFilePath = [NSString stringWithFormat:@"%@/%@", serverUrl, fileName];
    
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;

    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication deleteFileOrFolder:path onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        completion(nil, 0);
        
    } failureRquest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message;
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if (errorCode == 503)
            message = NSLocalizedString(@"_server_error_retry_", nil);
        else
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:_activeUrl fileID:@"" action:k_activityDebugActionDeleteFileFolder selector:@"" note:[error.userInfo valueForKey:@"NSLocalizedDescription"] type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:_activeUrl];
        
        completion(message, errorCode);
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Move =====
#pragma --------------------------------------------------------------------------------------------

- (void)moveFileOrFolder
{
    NSString *fileNamePath = [NSString stringWithFormat:@"%@/%@", _metadataNet.serverUrl, _metadataNet.fileName];
    NSString *fileNameToPath = [NSString stringWithFormat:@"%@/%@", _metadataNet.serverUrlTo, _metadataNet.fileNameTo];
    
    [self moveFileOrFolder:fileNamePath fileNameTo:fileNameToPath success:^{
        
        if ([_metadataNet.selector isEqualToString:selectorRename] && [self.delegate respondsToSelector:@selector(renameSuccess:)])
            [self.delegate renameSuccess:_metadataNet];
        
        if ([_metadataNet.selector isEqualToString:selectorMove] && [self.delegate respondsToSelector:@selector(moveSuccess:)])
            [self.delegate moveSuccess:_metadataNet];
        
        [self complete];
        
    } failure:^(NSString *message, NSInteger errorCode) {
        
        if ([self.delegate respondsToSelector:@selector(renameMoveFileOrFolderFailure:message:errorCode:)])
            [self.delegate renameMoveFileOrFolderFailure:_metadataNet message:message errorCode:errorCode];

        [self complete];
    }];
}

- (void)moveFileOrFolder:(NSString *)fileName fileNameTo:(NSString *)fileNameTo success:(void (^)(void))success failure:(void (^)(NSString *message, NSInteger errorCode))failure
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication moveFileOrFolder:fileName toDestiny:fileNameTo onCommunication:communication withForbiddenCharactersSupported:YES successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {

        success();
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        NSString *message = [CCError manageErrorOC:response.statusCode error:error];
        
        failure(message, error.code);
        
    } errorBeforeRequest:^(NSError *error) {
        
        NSString *message;
        
        if (error.code == OCErrorMovingTheDestinyAndOriginAreTheSame) {
            message = NSLocalizedString(@"_error_folder_destiny_is_the_same_", nil);
        } else if (error.code == OCErrorMovingFolderInsideHimself) {
            message = NSLocalizedString(@"_error_folder_destiny_is_the_same_", nil);
        } else if (error.code == OCErrorMovingDestinyNameHaveForbiddenCharacters) {
            message = NSLocalizedString(@"_forbidden_characters_from_server_", nil);
        } else {
            message = NSLocalizedString(@"_unknow_response_server_", nil);
        }
        
        failure(message, error.code);
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Shared =====
#pragma --------------------------------------------------------------------------------------------

- (void)readShareServer
{
#ifndef EXTENSION
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication readSharedByServer:[_activeUrl stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer) {
        
        // Test active account
        tableAccount *recordAccount = [[NCManageDatabase sharedInstance] getAccountActive];
        if (![recordAccount.account isEqualToString:_metadataNet.account]) {
            if ([self.delegate respondsToSelector:@selector(shareFailure:message:errorCode:)])
                [self.delegate shareFailure:_metadataNet message:NSLocalizedString(@"_error_user_not_available_", nil) errorCode:k_CCErrorUserNotAvailble];
            
            [self complete];
            return;
        }
        
        BOOL openWindow = NO;
        
        [appDelegate.sharesID removeAllObjects];
        
        if ([recordAccount.account isEqualToString:_metadataNet.account]) {
        
            for (OCSharedDto *item in items)
                [appDelegate.sharesID setObject:item forKey:[@(item.idRemoteShared) stringValue]];
            
            if ([_metadataNet.selector isEqual:selectorOpenWindowShare]) openWindow = YES;
            
            if ([_metadataNet.action isEqual:actionUpdateShare]) openWindow = YES;
            if ([_metadataNet.action isEqual:actionShare]) openWindow = YES;
            if ([_metadataNet.action isEqual:actionShareWith]) openWindow = YES;
        }
        
        if([self.delegate respondsToSelector:@selector(readSharedSuccess:items:openWindow:)])
            [self.delegate readSharedSuccess:_metadataNet items:appDelegate.sharesID openWindow:openWindow];
        
        [self complete];
        
    } failureRequest :^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(shareFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate shareFailure:_metadataNet message:NSLocalizedString(@"_server_error_retry_", nil) errorCode:errorCode];
            else
                [self.delegate shareFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
#endif
}

- (void)share
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
        
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication shareFileOrFolderByServer:[_activeUrl stringByAppendingString:@"/"] andFileOrFolderPath:[_metadataNet.fileName encodeString:NSUTF8StringEncoding] andPassword:[_metadataNet.password encodeString:NSUTF8StringEncoding] andPermission:_metadataNet.sharePermission andHideDownload:_metadataNet.hideDownload onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *token, NSString *redirectedServer) {
        
        [self readShareServer];
        
    } failureRequest :^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;

        // Error
        if ([self.delegate respondsToSelector:@selector(shareFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate shareFailure:_metadataNet message:NSLocalizedString(@"_server_error_retry_", nil) errorCode:errorCode];
            else
                [self.delegate shareFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }

        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

// * @param shareeType -> NSInteger: to set the type of sharee (user/group/federated)

- (void)shareWith
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication shareWith:_metadataNet.share shareeType:_metadataNet.shareeType inServer:[_activeUrl stringByAppendingString:@"/"] andFileOrFolderPath:[_metadataNet.fileName encodeString:NSUTF8StringEncoding] andPermissions:_metadataNet.sharePermission onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        [self readShareServer];
                
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;

        // Error
        if ([self.delegate respondsToSelector:@selector(shareFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate shareFailure:_metadataNet message:NSLocalizedString(@"_server_error_retry_", nil) errorCode:errorCode];
            else
                [self.delegate shareFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }

        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

- (void)updateShare
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication updateShare:[_metadataNet.share intValue] ofServerPath:[_activeUrl stringByAppendingString:@"/"] withPasswordProtect:[_metadataNet.password encodeString:NSUTF8StringEncoding] andExpirationTime:_metadataNet.expirationTime andPermissions:_metadataNet.sharePermission andHideDownload:_metadataNet.hideDownload onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        [self readShareServer];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
#ifndef EXTENSION
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

        [appDelegate messageNotification:@"_error_" description:[CCError manageErrorOC:response.statusCode error:error] visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:error.code];
#endif
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;

        // Error
        if ([self.delegate respondsToSelector:@selector(shareFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate shareFailure:_metadataNet message:NSLocalizedString(@"_server_error_retry_", nil) errorCode:errorCode];
            else
                [self.delegate shareFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }

        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

- (void)unShare
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication unShareFileOrFolderByServer:[_activeUrl stringByAppendingString:@"/"] andIdRemoteShared:[_metadataNet.share intValue] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        if([self.delegate respondsToSelector:@selector(unShareSuccess:)])
            [self.delegate unShareSuccess:_metadataNet];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
#ifndef EXTENSION
        [(AppDelegate *)[[UIApplication sharedApplication] delegate] messageNotification:@"_error_" description:[CCError manageErrorOC:response.statusCode error:error] visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:error.code];
#endif
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;

        // Error
        if ([self.delegate respondsToSelector:@selector(shareFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate shareFailure:_metadataNet message:NSLocalizedString(@"_server_error_retry_", nil) errorCode:errorCode];
            else
                [self.delegate shareFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

- (void)getUserAndGroup
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication searchUsersAndGroupsWith:_metadataNet.optionAny forPage:1 with:50 ofServer:[_activeUrl stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *itemList, NSString *redirectedServer) {
        
        if([self.delegate respondsToSelector:@selector(getUserAndGroupSuccess:items:)])
            [self.delegate getUserAndGroupSuccess:_metadataNet items:itemList];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;

        // Error
        if ([self.delegate respondsToSelector:@selector(getUserAndGroupFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate getUserAndGroupFailure:_metadataNet message:NSLocalizedString(@"_server_error_retry_", nil) errorCode:errorCode];
            else
                [self.delegate getUserAndGroupFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

- (void)getSharePermissionsFile
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;

    NSString *fileName = [NSString stringWithFormat:@"%@/%@", _metadataNet.serverUrl, _metadataNet.fileName];
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getSharePermissionsFile:fileName onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *permissions, NSString *redirectedServer) {
        
        // Test active account
        tableAccount *recordAccount = [[NCManageDatabase sharedInstance] getAccountActive];
        if (![recordAccount.account isEqualToString:_metadataNet.account]) {
            if ([self.delegate respondsToSelector:@selector(getSharePermissionsFileFailure:message:errorCode:)])
                [self.delegate getSharePermissionsFileFailure:_metadataNet message:NSLocalizedString(@"_error_user_not_available_", nil) errorCode:k_CCErrorUserNotAvailble];
            
            [self complete];
            return;
        }
        
        if([self.delegate respondsToSelector:@selector(getSharePermissionsFileSuccess:permissions:)])
            [self.delegate getSharePermissionsFileSuccess:_metadataNet permissions:permissions];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(getSharePermissionsFileFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate getSharePermissionsFileFailure:_metadataNet message:NSLocalizedString(@"_server_error_retry_", nil) errorCode:errorCode];
            else
                [self.delegate getSharePermissionsFileFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Activity =====
#pragma --------------------------------------------------------------------------------------------

- (void)getActivityServer
{
    [self getActivityServer:^(NSArray *listOfActivity) {
        
        if ([self.delegate respondsToSelector:@selector(getActivityServerSuccessFailure:listOfActivity:message:errorCode:)])
            [self.delegate getActivityServerSuccessFailure:_metadataNet listOfActivity:listOfActivity message:nil errorCode:0];
        
        [self complete];
        
    } failure:^(NSString *message, NSInteger errorCode) {
        
        if ([self.delegate respondsToSelector:@selector(getActivityServerSuccessFailure:listOfActivity:message:errorCode:)])
            [self.delegate getActivityServerSuccessFailure:_metadataNet listOfActivity:nil message:message errorCode:errorCode];
        
        [self complete];
    }];
}

- (void)getActivityServer:(void(^)(NSArray *listOfActivity))success failure:(void (^)(NSString *message, NSInteger errorCode))failure
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getActivityServer:[_activeUrl stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *listOfActivity, NSString *redirectedServer) {
        
        success(listOfActivity);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message;
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if (errorCode == 503)
            message = NSLocalizedString(@"_server_error_retry_", nil);
        else
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        
        failure(message, errorCode);
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== External Sites =====
#pragma --------------------------------------------------------------------------------------------

- (void)getExternalSitesServer
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getExternalSitesServer:[_activeUrl stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *listOfExternalSites, NSString *redirectedServer) {
        
        // Test active account
        tableAccount *recordAccount = [[NCManageDatabase sharedInstance] getAccountActive];
        if (![recordAccount.account isEqualToString:_metadataNet.account]) {
            if ([self.delegate respondsToSelector:@selector(getExternalSitesServerSuccessFailure:listOfExternalSites:message:errorCode:)])
                [self.delegate getExternalSitesServerSuccessFailure:_metadataNet listOfExternalSites:nil message:NSLocalizedString(@"_error_user_not_available_", nil) errorCode:k_CCErrorUserNotAvailble];
            
            [self complete];
            return;
        }
        
        if ([self.delegate respondsToSelector:@selector(getExternalSitesServerSuccessFailure:listOfExternalSites:message:errorCode:)])
            [self.delegate getExternalSitesServerSuccessFailure:_metadataNet listOfExternalSites:listOfExternalSites message:nil errorCode:0];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(getExternalSitesServerSuccessFailure:listOfExternalSites:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate getExternalSitesServerSuccessFailure:_metadataNet listOfExternalSites:nil message:NSLocalizedString(@"_server_error_retry_", nil) errorCode:errorCode];
            else
                [self.delegate getExternalSitesServerSuccessFailure:_metadataNet listOfExternalSites:nil message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }

        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
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
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(getExternalSitesServerFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate getExternalSitesServerFailure:_metadataNet message:NSLocalizedString(@"_server_error_retry_", nil) errorCode:errorCode];
            else
                [self.delegate getExternalSitesServerFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
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
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getNotificationServer:[_activeUrl stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *listOfNotifications, NSString *redirectedServer) {
        
        // Test active account
        tableAccount *recordAccount = [[NCManageDatabase sharedInstance] getAccountActive];
        if (![recordAccount.account isEqualToString:_metadataNet.account]) {
            if ([self.delegate respondsToSelector:@selector(getNotificationServerSuccessFailure:listOfNotifications:message:errorCode:)])
                [self.delegate getNotificationServerSuccessFailure:_metadataNet listOfNotifications:nil message:NSLocalizedString(@"_error_user_not_available_",  nil) errorCode:k_CCErrorUserNotAvailble];
            
            [self complete];
            return;
        }
        
        if ([self.delegate respondsToSelector:@selector(getNotificationServerSuccessFailure:listOfNotifications:message:errorCode:)])
            [self.delegate getNotificationServerSuccessFailure:_metadataNet listOfNotifications:listOfNotifications message:nil errorCode:0];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(getNotificationServerSuccessFailure:listOfNotifications:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate getNotificationServerSuccessFailure:_metadataNet listOfNotifications:nil message:NSLocalizedString(@"_server_error_retry_", nil) errorCode:errorCode];
            else
                [self.delegate getNotificationServerSuccessFailure:_metadataNet listOfNotifications:nil message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }

        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:_activeUrl fileID:@"" action:k_activityDebugActionGetNotification selector:@"" note:[error.userInfo valueForKey:@"NSLocalizedDescription"] type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:_activeUrl];
        
        [self complete];
    }];
}

- (void)setNotificationServer
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    NSString *type = _metadataNet.optionAny;
    
    [communication setNotificationServer:_metadataNet.serverUrl type:type onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        // Test active account
        tableAccount *recordAccount = [[NCManageDatabase sharedInstance] getAccountActive];
        if (![recordAccount.account isEqualToString:_metadataNet.account]) {
            if ([self.delegate respondsToSelector:@selector(setNotificationServerSuccessFailure:message:errorCode:)])
                [self.delegate setNotificationServerSuccessFailure:_metadataNet message:NSLocalizedString(@"_error_user_not_available_", nil) errorCode:k_CCErrorUserNotAvailble];
            
            [self complete];
            return;
        }
        
        if ([self.delegate respondsToSelector:@selector(setNotificationServerSuccessFailure:message:errorCode:)])
            [self.delegate setNotificationServerSuccessFailure:_metadataNet message:nil errorCode:0];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(setNotificationServerSuccessFailure:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate setNotificationServerSuccessFailure:_metadataNet message:NSLocalizedString(@"_server_error_retry_", nil) errorCode:errorCode];
            else
                [self.delegate setNotificationServerSuccessFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }

        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Push Notification =====
#pragma --------------------------------------------------------------------------------------------

- (void)subscribingPushNotificationServer:(NSString *)url pushToken:(NSString *)pushToken Hash:(NSString *)pushTokenHash devicePublicKey:(NSString *)devicePublicKey success:(void(^)(NSString *deviceIdentifier, NSString *deviceIdentifierSignature, NSString *publicKey))success failure:(void (^)(NSString *message, NSInteger errorCode))failure
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    devicePublicKey = [CCUtility URLEncodeStringFromString:devicePublicKey];

    [communication subscribingNextcloudServerPush:url pushTokenHash:pushTokenHash devicePublicKey:devicePublicKey proxyServerPath: [NCBrandOptions sharedInstance].pushNotificationServerProxy onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *publicKey, NSString *deviceIdentifier, NSString *signature, NSString *redirectedServer) {
        
        deviceIdentifier = [CCUtility URLEncodeStringFromString:deviceIdentifier];
        signature = [CCUtility URLEncodeStringFromString:signature];
        publicKey = [CCUtility URLEncodeStringFromString:publicKey];
        
        [communication subscribingPushProxy:[NCBrandOptions sharedInstance].pushNotificationServerProxy pushToken:pushToken deviceIdentifier:deviceIdentifier deviceIdentifierSignature:signature publicKey:publicKey onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
            
            // Activity
            [[NCManageDatabase sharedInstance] addActivityClient:[NCBrandOptions sharedInstance].pushNotificationServerProxy fileID:@"" action:k_activityDebugActionSubscribingPushProxy selector:@"" note:@"Service registered." type:k_activityTypeSuccess verbose:k_activityVerboseHigh activeUrl:_activeUrl];
            
            success(deviceIdentifier, signature, publicKey);
            
        } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
           
            NSString *message;

            NSInteger errorCode = response.statusCode;
            if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
                errorCode = error.code;
            
            // Error
            if (errorCode == 503)
                message = NSLocalizedString(@"_server_error_retry_", nil);
            else
                message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
            
            // Activity
            [[NCManageDatabase sharedInstance] addActivityClient:[NCBrandOptions sharedInstance].pushNotificationServerProxy fileID:@"" action:k_activityDebugActionSubscribingPushProxy selector:@"" note:[error.userInfo valueForKey:@"NSLocalizedDescription"] type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:_activeUrl];
            
            failure(message, errorCode);
        }];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message;

        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
    
        // Error
        if (errorCode == 503)
            message = NSLocalizedString(@"_server_error_retry_", nil);
        else
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];

        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:_activeUrl fileID:@"" action:k_activityDebugActionSubscribingServerPush selector:@"" note:[error.userInfo valueForKey:@"NSLocalizedDescription"] type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:_activeUrl];
        
        failure(message, errorCode);
    }];
}

- (void)unsubscribingPushNotificationServer:(NSString *)url deviceIdentifier:(NSString *)deviceIdentifier deviceIdentifierSignature:(NSString *)deviceIdentifierSignature publicKey:(NSString *)publicKey success:(void (^)(void))success failure:(void (^)(NSString *message, NSInteger errorCode))failure {
    
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication unsubscribingNextcloudServerPush:url onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {

        [communication unsubscribingPushProxy:[NCBrandOptions sharedInstance].pushNotificationServerProxy deviceIdentifier:deviceIdentifier deviceIdentifierSignature:deviceIdentifierSignature publicKey:publicKey onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
            
            success();
            
        } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)  {
            
            NSString *message;
            
            NSInteger errorCode = response.statusCode;
            if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
                errorCode = error.code;
            
            // Error
            if (errorCode == 503)
                message = NSLocalizedString(@"_server_error_retry_", nil);
            else
                message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
            
            // Activity
            [[NCManageDatabase sharedInstance] addActivityClient:_activeUrl fileID:@"" action:k_activityDebugActionUnsubscribingPushProxy selector:@"" note:[error.userInfo valueForKey:@"NSLocalizedDescription"] type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:_activeUrl];
            
            failure(message, errorCode);
        }];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {

        NSString *message;
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if (errorCode == 503)
            message = NSLocalizedString(@"_server_error_retry_", nil);
        else
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        
        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:_activeUrl fileID:@"" action:k_activityDebugActionUnsubscribingServerPush selector:@"" note:[error.userInfo valueForKey:@"NSLocalizedDescription"] type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:_activeUrl];
        
        failure(message, errorCode);
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  User Profile =====
#pragma --------------------------------------------------------------------------------------------

- (void)getUserProfile
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getUserProfileServer:[_activeUrl stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, OCUserProfile *userProfile, NSString *redirectedServer) {
        
        // Test active account
        tableAccount *recordAccount = [[NCManageDatabase sharedInstance] getAccountActive];
        if (![recordAccount.account isEqualToString:_metadataNet.account]) {
            if ([self.delegate respondsToSelector:@selector(getUserProfileSuccessFailure:userProfile:message:errorCode:)])
                [self.delegate getUserProfileSuccessFailure:_metadataNet userProfile:nil message:NSLocalizedString(@"_error_user_not_available_", nil) errorCode:k_CCErrorUserNotAvailble];
            
            [self complete];
            return;
        }
        
        if ([self.delegate respondsToSelector:@selector(getUserProfileSuccessFailure:userProfile:message:errorCode:)])
            [self.delegate getUserProfileSuccessFailure:_metadataNet userProfile:userProfile message:nil errorCode:0];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(getUserProfileSuccessFailure:userProfile:message:errorCode:)]) {
            
            if (errorCode == 503)
                [self.delegate getUserProfileSuccessFailure:_metadataNet userProfile:nil message:NSLocalizedString(@"_server_error_retry_", nil) errorCode:errorCode];
            else
                [self.delegate getUserProfileSuccessFailure:_metadataNet userProfile:nil message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }

        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Capabilities =====
#pragma --------------------------------------------------------------------------------------------

- (void)getCapabilitiesOfServer
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getCapabilitiesOfServer:[_activeUrl stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, OCCapabilities *capabilities, NSString *redirectedServer) {
        
        // Test active account
        tableAccount *recordAccount = [[NCManageDatabase sharedInstance] getAccountActive];
        if (![recordAccount.account isEqualToString:_metadataNet.account]) {
            if ([self.delegate respondsToSelector:@selector(getCapabilitiesOfServerSuccessFailure:capabilities:message:errorCode:)])
                [self.delegate getCapabilitiesOfServerSuccessFailure:_metadataNet capabilities:nil message:NSLocalizedString(@"_error_user_not_available_", nil) errorCode:k_CCErrorUserNotAvailble];
            
            [self complete];
            return;
        }
        
        if ([self.delegate respondsToSelector:@selector(getCapabilitiesOfServerSuccessFailure:capabilities:message:errorCode:)])
            [self.delegate getCapabilitiesOfServerSuccessFailure:_metadataNet capabilities:capabilities message:nil errorCode:0];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;

        // Error
        if ([self.delegate respondsToSelector:@selector(getCapabilitiesOfServerSuccessFailure:capabilities:message:errorCode:)]) {

            if (errorCode == 503)
                [self.delegate getCapabilitiesOfServerSuccessFailure:_metadataNet capabilities:nil message:NSLocalizedString(@"_server_error_retry_", nil) errorCode:errorCode];
            else
                [self.delegate getCapabilitiesOfServerSuccessFailure:_metadataNet capabilities:nil message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        }

        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];

        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:_activeUrl fileID:@"" action:k_activityDebugActionCapabilities selector:@"" note:[error.userInfo valueForKey:@"NSLocalizedDescription"] type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:_activeUrl];
        
        [self complete];
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== End-to-End Encryption =====
#pragma --------------------------------------------------------------------------------------------

- (void)getEndToEndPublicKeys
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getEndToEndPublicKeys:[_activeUrl stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *publicKey, NSString *redirectedServer) {
        
        _metadataNet.key = publicKey;

        if ([self.delegate respondsToSelector:@selector(getEndToEndPublicKeysSuccess:)])
            [self.delegate getEndToEndPublicKeysSuccess:_metadataNet];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(getEndToEndPublicKeysFailure:message:errorCode:)])
            [self.delegate getEndToEndPublicKeysFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

- (void)getEndToEndPrivateKeyCipher
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getEndToEndPrivateKeyCipher:[_activeUrl stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *privateKeyChiper, NSString *redirectedServer) {
        
        _metadataNet.key = privateKeyChiper;
        
        if ([self.delegate respondsToSelector:@selector(getEndToEndPrivateKeyCipherSuccess:)])
            [self.delegate getEndToEndPrivateKeyCipherSuccess:_metadataNet];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(getEndToEndPrivateKeyCipherFailure:message:errorCode:)])
            [self.delegate getEndToEndPrivateKeyCipherFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

- (void)signEndToEndPublicKey
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    // URL Encode
    NSString *publicKey = [CCUtility URLEncodeStringFromString:_metadataNet.key];

    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication signEndToEndPublicKey:[_activeUrl stringByAppendingString:@"/"] publicKey:publicKey onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *publicKey, NSString *redirectedServer) {
        
        _metadataNet.key = publicKey;

        if ([self.delegate respondsToSelector:@selector(signEndToEndPublicKeySuccess:)])
            [self.delegate signEndToEndPublicKeySuccess:_metadataNet];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(signEndToEndPublicKeyFailure:message:errorCode:)])
            [self.delegate signEndToEndPublicKeyFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

- (void)storeEndToEndPrivateKeyCipher
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    // URL Encode
    NSString *privateKeyChiper = [CCUtility URLEncodeStringFromString:_metadataNet.keyCipher];
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication storeEndToEndPrivateKeyCipher:[_activeUrl stringByAppendingString:@"/"] privateKeyChiper:privateKeyChiper onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *privateKey, NSString *redirectedServer) {
        
        if ([self.delegate respondsToSelector:@selector(storeEndToEndPrivateKeyCipherSuccess:)])
            [self.delegate storeEndToEndPrivateKeyCipherSuccess:_metadataNet];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(storeEndToEndPrivateKeyCipherFailure:message:errorCode:)])
            [self.delegate storeEndToEndPrivateKeyCipherFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

- (void)deleteEndToEndPublicKey
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication deleteEndToEndPublicKey:[_activeUrl stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        if ([self.delegate respondsToSelector:@selector(deleteEndToEndPublicKeySuccess:)])
            [self.delegate deleteEndToEndPublicKeySuccess:_metadataNet];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(deleteEndToEndPublicKeyFailure:message:errorCode:)])
            [self.delegate deleteEndToEndPublicKeyFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

- (void)deleteEndToEndPrivateKey
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication deleteEndToEndPrivateKey:[_activeUrl stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        if ([self.delegate respondsToSelector:@selector(deleteEndToEndPrivateKeySuccess:)])
            [self.delegate deleteEndToEndPrivateKeySuccess:_metadataNet];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(deleteEndToEndPrivateKeyFailure:message:errorCode:)])
            [self.delegate deleteEndToEndPrivateKeyFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

- (void)getEndToEndServerPublicKey
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getEndToEndServerPublicKey:[_activeUrl stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *publicKey, NSString *redirectedServer) {
        
        _metadataNet.key = publicKey;
        
        if ([self.delegate respondsToSelector:@selector(getEndToEndServerPublicKeySuccess:)])
            [self.delegate getEndToEndServerPublicKeySuccess:_metadataNet];
        
        [self complete];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if ([self.delegate respondsToSelector:@selector(getEndToEndServerPublicKeyFailure:message:errorCode:)])
            [self.delegate getEndToEndServerPublicKeyFailure:_metadataNet message:[error.userInfo valueForKey:@"NSLocalizedDescription"] errorCode:errorCode];
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted && self.delegate)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
        
        [self complete];
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Manage Mobile Editor OCS API =====
#pragma --------------------------------------------------------------------------------------------

- (void)createLinkRichdocumentsWithFileID:(NSString *)fileID success:(void(^)(NSString *link))success failure:(void (^)(NSString *message, NSInteger errorCode))failure
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    NSString *fileIDServer = [[NCUtility sharedInstance] convertFileIDClientToFileIDServer:fileID];
    
    [communication createLinkRichdocuments:[_activeUrl stringByAppendingString:@"/"] fileID:fileIDServer onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *link, NSString *redirectedServer) {
        
        success(link);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message;
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if (errorCode == 503)
            message = NSLocalizedString(@"_server_error_retry_", nil);
        else
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        
        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:_activeUrl fileID:@"" action:k_activityDebugActionUnsubscribingServerPush selector:@"" note:[error.userInfo valueForKey:@"NSLocalizedDescription"] type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:_activeUrl];
        
        failure(message, errorCode);
    }];
}

- (void)geTemplatesRichdocumentsWithTypeTemplate:(NSString *)typeTemplate success:(void(^)(NSArray *listOfTemplate))success failure:(void (^)(NSString *message, NSInteger errorCode))failure
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
        
    [communication geTemplatesRichdocuments:[_activeUrl stringByAppendingString:@"/"] typeTemplate:typeTemplate onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *listOfTemplate, NSString *redirectedServer) {
        
        success(listOfTemplate);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message;
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if (errorCode == 503)
            message = NSLocalizedString(@"_server_error_retry_", nil);
        else
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        
        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:_activeUrl fileID:@"" action:k_activityDebugActionUnsubscribingServerPush selector:@"" note:[error.userInfo valueForKey:@"NSLocalizedDescription"] type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:_activeUrl];
        
        failure(message, errorCode);
    }];
}

- (void)createNewRichdocumentsWithFileName:(NSString *)fileName serverUrl:(NSString *)serverUrl templateID:(NSString *)templateID success:(void(^)(NSString *url))success failure:(void (^)(NSString *message, NSInteger errorCode))failure
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
        
    [communication createNewRichdocuments:[_activeUrl stringByAppendingString:@"/"] path:fileName templateID:templateID onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *url, NSString *redirectedServer) {
        
        success(url);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message;
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if (errorCode == 503)
            message = NSLocalizedString(@"_server_error_retry_", nil);
        else
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        
        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:_activeUrl fileID:@"" action:k_activityDebugActionUnsubscribingServerPush selector:@"" note:[error.userInfo valueForKey:@"NSLocalizedDescription"] type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:_activeUrl];
        
        failure(message, errorCode);
    }];
}

- (void)createAssetRichdocumentsWithFileName:(NSString *)fileName serverUrl:(NSString *)serverUrl success:(void(^)(NSString *link))success failure:(void (^)(NSString *message, NSInteger errorCode))failure
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    NSString *fileNamePath = [CCUtility returnFileNamePathFromFileName:fileName serverUrl:serverUrl activeUrl:_activeUrl];
    
    [communication createAssetRichdocuments:[_activeUrl stringByAppendingString:@"/"] path:fileNamePath onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *url, NSString *redirectedServer) {
        
        success(url);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message;
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if (errorCode == 503)
            message = NSLocalizedString(@"_server_error_retry_", nil);
        else
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        
        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:_activeUrl fileID:@"" action:k_activityDebugActionUnsubscribingServerPush selector:@"" note:[error.userInfo valueForKey:@"NSLocalizedDescription"] type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:_activeUrl];
        
        failure(message, errorCode);
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Trash =====
#pragma --------------------------------------------------------------------------------------------

- (void)listingTrash:(NSString *)serverUrl path:(NSString *)path account:(NSString *)account success:(void(^)(NSArray *items))success failure:(void (^)(NSString *message, NSInteger errorCode))failure
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication listingTrash:[serverUrl stringByAppendingString:path] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer) {
        
        // Test active account
        tableAccount *recordAccount = [[NCManageDatabase sharedInstance] getAccountActive];
        if (![recordAccount.account isEqualToString:account]) {
            
            failure(NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
            
        } else {
            
            // Check items > 0
            if ([items count] == 0) {
                
#ifndef EXTENSION
                AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                
                [appDelegate messageNotification:@"Server error" description:@"Read Folder WebDAV : [items NULL] please fix" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:k_CCErrorInternalError];
#endif
                failure(NSLocalizedString(@"Read Folder WebDAV : [items NULL] please fix", nil), k_CCErrorInternalError);
                
            } else {
                
                NSMutableArray *listTrash = [NSMutableArray new];
                
                //OCFileDto *itemDtoFolder = [items objectAtIndex:0];

                if ([items count] > 1) {
                    for (NSUInteger i=1; i < [items count]; i++) {
                        
                        OCFileDto *itemDto = [items objectAtIndex:i];
                        tableTrash *trash = [tableTrash new];
                        
                        trash.account = account;
                        trash.date = [NSDate dateWithTimeIntervalSince1970:itemDto.date];
                        trash.directory = itemDto.isDirectory;
                        trash.fileID = itemDto.ocId;
                        trash.fileName = itemDto.fileName;
                        trash.filePath = itemDto.filePath;
                        trash.size = itemDto.size;
                        trash.trashbinFileName = itemDto.trashbinFileName;
                        trash.trashbinOriginalLocation = itemDto.trashbinOriginalLocation;
                        trash.trashbinDeletionTime = [NSDate dateWithTimeIntervalSince1970:itemDto.trashbinDeletionTime];

                        [CCUtility insertTypeFileIconName:trash.trashbinFileName metadata:(tableMetadata *)trash];

                        [listTrash addObject:trash];
                    }
                }
                
                success(listTrash);
            }
        }
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message;
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if (errorCode == 503)
            message = NSLocalizedString(@"_server_error_retry_", nil);
        else
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        
        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:_activeUrl fileID:@"" action:k_activityDebugActionUnsubscribingServerPush selector:@"" note:[error.userInfo valueForKey:@"NSLocalizedDescription"] type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:_activeUrl];
        
        failure(message, errorCode);
    }];
}


- (void)emptyTrash:(void (^)(NSString *message, NSInteger errorCode))completion
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    [communication setCredentialsWithUser:_activeUser andUserID:_activeUserID andPassword:_activePassword];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    NSString *path = [NSString stringWithFormat:@"%@%@/trashbin/%@/trash", _activeUrl, k_dav, _activeUserID];
    
    [communication emptyTrash:path onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        completion(nil, 0);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message;
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if (errorCode == 503)
            message = NSLocalizedString(@"_server_error_retry_", nil);
        else
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        
        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:_activeUrl fileID:@"" action:k_activityDebugActionUnsubscribingServerPush selector:@"" note:[error.userInfo valueForKey:@"NSLocalizedDescription"] type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:_activeUrl];
        
        completion(message, errorCode);
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
