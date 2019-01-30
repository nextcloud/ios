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

@implementation OCNetworking

+ (OCNetworking *)sharedManager {
    static OCNetworking *sharedManager;
    @synchronized(self)
    {
        if (!sharedManager) {
            sharedManager = [OCNetworking new];
        }
        return sharedManager;
    }
}

- (id)init
{
    self = [super init];
    
    [self sharedOCCommunication];
    
    return self;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== OCCommunication =====
#pragma --------------------------------------------------------------------------------------------

- (OCCommunication *)sharedOCCommunication
{
    static OCCommunication* sharedOCCommunication = nil;
    
    if (sharedOCCommunication == nil)
    {
        // Network
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.allowsCellularAccess = YES;
        configuration.discretionary = NO;
        configuration.HTTPMaximumConnectionsPerHost = k_maxConcurrentOperation;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        
        OCURLSessionManager *networkSessionManager = [[OCURLSessionManager alloc] initWithSessionConfiguration:configuration];
        [networkSessionManager.operationQueue setMaxConcurrentOperationCount: k_maxConcurrentOperation];
        networkSessionManager.responseSerializer = [AFHTTPResponseSerializer serializer];
        
        // Download
        NSURLSessionConfiguration *configurationDownload = [NSURLSessionConfiguration defaultSessionConfiguration];
        configurationDownload.allowsCellularAccess = YES;
        configurationDownload.discretionary = NO;
        configurationDownload.HTTPMaximumConnectionsPerHost = k_maxHTTPConnectionsPerHost;
        configurationDownload.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        configurationDownload.timeoutIntervalForRequest = k_timeout_upload;
        
        OCURLSessionManager *downloadSessionManager = [[OCURLSessionManager alloc] initWithSessionConfiguration:configurationDownload];
        [downloadSessionManager.operationQueue setMaxConcurrentOperationCount:k_maxHTTPConnectionsPerHost];
        [downloadSessionManager setSessionDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition (NSURLSession *session, NSURLAuthenticationChallenge *challenge, NSURLCredential * __autoreleasing *credential) {
            return NSURLSessionAuthChallengePerformDefaultHandling;
        }];
        
        // Upload
        NSURLSessionConfiguration *configurationUpload = [NSURLSessionConfiguration defaultSessionConfiguration];
        configurationUpload.allowsCellularAccess = YES;
        configurationUpload.discretionary = NO;
        configurationUpload.HTTPMaximumConnectionsPerHost = k_maxHTTPConnectionsPerHost;
        configurationUpload.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        configurationUpload.timeoutIntervalForRequest = k_timeout_upload;
        
        OCURLSessionManager *uploadSessionManager = [[OCURLSessionManager alloc] initWithSessionConfiguration:configurationUpload];
        [uploadSessionManager.operationQueue setMaxConcurrentOperationCount:k_maxHTTPConnectionsPerHost];
        [uploadSessionManager setSessionDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition (NSURLSession *session, NSURLAuthenticationChallenge *challenge, NSURLCredential * __autoreleasing *credential) {
            return NSURLSessionAuthChallengePerformDefaultHandling;
        }];
        
        sharedOCCommunication = [[OCCommunication alloc] initWithUploadSessionManager:uploadSessionManager andDownloadSessionManager:downloadSessionManager andNetworkSessionManager:networkSessionManager];
    }
    
    return sharedOCCommunication;
}

- (OCCommunication *)sharedOCCommunicationExtensionDownload
{
    static OCCommunication *sharedOCCommunicationExtensionDownload = nil;
    
    if (sharedOCCommunicationExtensionDownload == nil)
    {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:k_download_session_extension];
        config.sharedContainerIdentifier = [NCBrandOptions sharedInstance].capabilitiesGroups;
        config.HTTPMaximumConnectionsPerHost = 1;
        config.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        config.timeoutIntervalForRequest = k_timeout_upload;
        config.sessionSendsLaunchEvents = YES;
        [config setAllowsCellularAccess:YES];
        
        OCURLSessionManager *sessionManager = [[OCURLSessionManager alloc] initWithSessionConfiguration:config];
        [sessionManager.operationQueue setMaxConcurrentOperationCount:1];
        [sessionManager setSessionDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition (NSURLSession *session, NSURLAuthenticationChallenge *challenge, NSURLCredential * __autoreleasing *credential) {
            return NSURLSessionAuthChallengePerformDefaultHandling;
        }];
        
        sharedOCCommunicationExtensionDownload = [[OCCommunication alloc] initWithUploadSessionManager:nil andDownloadSessionManager:sessionManager andNetworkSessionManager:nil];
    }
    
    return sharedOCCommunicationExtensionDownload;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Server =====
#pragma --------------------------------------------------------------------------------------------

- (void)checkServerUrl:(NSString *)serverUrl user:(NSString *)user userID:(NSString *)userID password:(NSString *)password completion:(void (^)(NSString *message, NSInteger errorCode))completion
{
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
        
    [communication checkServer:serverUrl onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
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

- (void)serverStatusUrl:(NSString *)serverUrl delegate:(id)delegate completion:(void(^)(NSString *serverProductName, NSInteger versionMajor, NSInteger versionMicro, NSInteger versionMinor, NSString *message, NSInteger errorCode))completion
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
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:delegate delegateQueue:nil];
    
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
                
                completion(nil, 0, 0, 0, message, errorCode);
                
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
                    completion(nil, 0, 0, 0, NSLocalizedString(@"_no_nextcloud_found_", nil), k_CCErrorInternalError);
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
                
                completion(serverProductName, versionMajor, versionMicro, versionMinor, nil, 0);
            }
        });
        
    }];
    
    [task resume];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== download / upload =====
#pragma --------------------------------------------------------------------------------------------

- (NSURLSessionTask *)downloadWithAccount:(NSString *)account fileNameServerUrl:(NSString *)fileNameServerUrl fileNameLocalPath:(NSString *)fileNameLocalPath communication:(OCCommunication *)communication completion:(void (^)(NSString *account, int64_t length, NSString *etag, NSDate *date, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, 0, nil, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
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
            completion(account, 0, nil, nil, NSLocalizedString(@"Internal error", nil), k_CCErrorInternalError);
        } else {
            completion(account, totalUnitCount, etag, date, nil, 0);
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
        
        completion(account, 0, nil, nil, message, errorCode);
    }];
    
    return sessionTask;
}

- (NSURLSessionTask *)downloadWithAccount:(NSString *)account url:(NSString *)url fileNameLocalPath:(NSString *)fileNameLocalPath completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];

    NSURLSessionTask *sessionTask = [communication downloadFileSession:url toDestiny:fileNameLocalPath defaultPriority:YES onCommunication:communication progress:^(NSProgress *progress) {
        //float percent = roundf (progress.fractionCompleted * 100);
    } successRequest:^(NSURLResponse *response, NSURL *filePath) {
        
        completion(account, nil, 0);
        
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
        
        completion(account, message, errorCode);
    }];
    
    return sessionTask;
}

- (NSURLSessionTask *)uploadWithAccount:(NSString *)account fileNameServerUrl:(NSString *)fileNameServerUrl fileNameLocalPath:(NSString *)fileNameLocalPath communication:(OCCommunication *)communication completion:(void(^)(NSString *account, NSString *fileID, NSString *etag, NSDate *date, NSString *message, NSInteger errorCode))completion
{    
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, nil, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    NSURLSessionTask *sessionTask = [communication uploadFileSession:fileNameLocalPath toDestiny:fileNameServerUrl onCommunication:communication progress:^(NSProgress *progress) {
        //float percent = roundf (progress.fractionCompleted * 100);
    } successRequest:^(NSURLResponse *response, NSString *redirectedServer) {
    
        NSDictionary *fields = [(NSHTTPURLResponse*)response allHeaderFields];

        NSString *fileID = [CCUtility removeForbiddenCharactersFileSystem:[fields objectForKey:@"OC-FileId"]];
        NSString *etag = [CCUtility removeForbiddenCharactersFileSystem:[fields objectForKey:@"OC-ETag"]];
        NSDate *date = [CCUtility dateEnUsPosixFromCloud:[fields objectForKey:@"Date"]];
        
        completion(account, fileID, etag, date, nil, 0);
        
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
        
        completion(account, nil, nil, nil, message, errorCode);
        
    } failureBeforeRequest:^(NSError *error) {
        completion(account, nil, nil, nil, error.description, error.code);
    }];
    
    return sessionTask;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== WebDav =====
#pragma --------------------------------------------------------------------------------------------

- (void)readFolderWithAccount:(NSString *)account serverUrl:(NSString *)serverUrl depth:(NSString *)depth completion:(void(^)(NSString *account, NSArray *metadatas, tableMetadata *metadataFolder, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication readFolder:serverUrl depth:depth withUserSessionToken:nil onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer, NSString *token) {
        
        // Check items > 0
        if ([items count] == 0) {
                
#ifndef EXTENSION
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                
            [appDelegate messageNotification:@"Server error" description:@"Read Folder WebDAV : [items NULL] please fix" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:k_CCErrorInternalError];
#endif
            completion(account, nil, nil, NSLocalizedString(@"Read Folder WebDAV : [items NULL] please fix", nil), k_CCErrorInternalError);

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
                    completion(account, metadatas, metadataFolder, nil, 0);
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
        
        completion(account, nil, nil, message, errorCode);
    }];
}

- (void)readFileWithAccount:(NSString *)account serverUrl:(NSString *)serverUrl fileName:(NSString *)fileName completion:(void(^)(NSString *account, tableMetadata *metadata, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
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
                    
            completion(account, metadata, nil, 0);
            
        // BUG 1038 item == 0
        } else {
                
#ifndef EXTENSION
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                
            [appDelegate messageNotification:@"Server error" description:@"Read File WebDAV : [items NULL] please fix" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:k_CCErrorInternalError];
#endif
            completion(account, nil, NSLocalizedString(@"Read File WebDAV : [items NULL] please fix", nil), k_CCErrorInternalError);
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
        
        completion(account, nil, message, errorCode);
    }];
}

- (void)createFolderWithAccount:(NSString *)account serverUrl:(NSString *)serverUrl fileName:(NSString *)fileName completion:(void(^)(NSString *account, NSString *fileID, NSDate *date, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    NSString *path = [NSString stringWithFormat:@"%@/%@", serverUrl, fileName];
    NSString *autoUploadFileName = [[NCManageDatabase sharedInstance] getAccountAutoUploadFileName];
    NSString *autoUploadDirectory = [[NCManageDatabase sharedInstance] getAccountAutoUploadDirectory:tableAccount.url];
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication createFolder:path onCommunication:communication withForbiddenCharactersSupported:YES successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        NSDictionary *fields = [response allHeaderFields];
        
        NSString *fileID = [CCUtility removeForbiddenCharactersFileSystem:[fields objectForKey:@"OC-FileId"]];
        NSDate *date = [CCUtility dateEnUsPosixFromCloud:[fields objectForKey:@"Date"]];
        
        completion(account, fileID, date, nil, 0);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message;
        
        if (([fileName isEqualToString:autoUploadFileName] && [serverUrl isEqualToString:autoUploadDirectory]))
            message = nil;
        else
            message = [CCError manageErrorOC:response.statusCode error:error];
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        completion(account, nil, nil, message, errorCode);
        
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
        
        completion(account, nil, nil, message, error.code);
    }];
}

- (void)deleteFileOrFolderWithAccount:(NSString *)account path:(NSString *)path completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication deleteFileOrFolder:path onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        completion(account, nil, 0);
        
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
        
        completion(account, message, errorCode);
    }];
}

- (void)moveFileOrFolderWithAccount:(NSString *)account fileName:(NSString *)fileName fileNameTo:(NSString *)fileNameTo completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication moveFileOrFolder:fileName toDestiny:fileNameTo onCommunication:communication withForbiddenCharactersSupported:YES successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        completion(account, nil, 0);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        NSString *message = [CCError manageErrorOC:response.statusCode error:error];
        
        completion(account, message, error.code);
        
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
        
        completion(account, message, error.code);
    }];
}

- (void)searchWithAccount:(NSString *)account fileName:(NSString *)fileName serverUrl:(NSString *)serverUrl contentType:(NSArray *)contentType date:(NSDate *)date depth:(NSString *)depth completion:(void(^)(NSString *account, NSArray *metadatas, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];

    NSString *path = [tableAccount.url stringByAppendingString:k_dav];
    NSString *folder = [serverUrl stringByReplacingOccurrencesOfString:[CCUtility getHomeServerUrlActiveUrl:tableAccount.url] withString:@""];
    NSString *dateLastModified;
    
    if (date) {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        [dateFormatter setLocale:enUSPOSIXLocale];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
        
        dateLastModified = [dateFormatter stringFromDate:date];
    }
 
    [communication search:path folder:folder fileName: [NSString stringWithFormat:@"%%%@%%", fileName] depth:depth dateLastModified:dateLastModified contentType:contentType withUserSessionToken:nil onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer, NSString *token) {
        
        NSMutableArray *metadatas = [NSMutableArray new];
        BOOL showHiddenFiles = [CCUtility getShowHiddenFiles];
        
        NSString *autoUploadFileName = [[NCManageDatabase sharedInstance] getAccountAutoUploadFileName];
        NSString *autoUploadDirectory = [[NCManageDatabase sharedInstance] getAccountAutoUploadDirectory:tableAccount.url];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            
            for (OCFileDto *itemDto in items) {
                
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
                if ([serverPath hasSuffix:@"/"]) serverPath = [serverPath substringToIndex:[serverPath length] - 1];
                serverUrl = [CCUtility stringAppendServerUrl:[tableAccount.url stringByAppendingString:k_webDAV] addFileName:serverPath];
                
                if (itemDto.isDirectory) {
                    (void)[[NCManageDatabase sharedInstance] addDirectoryWithEncrypted:itemDto.isEncrypted favorite:itemDto.isFavorite fileID:itemDto.ocId permissions:itemDto.permissions serverUrl:[NSString stringWithFormat:@"%@/%@", serverUrl, fileName] account:account];
                }
                
                isFolderEncrypted = [CCUtility isFolderEncrypted:serverUrl account:account];
                
                [metadatas addObject:[CCUtility trasformedOCFileToCCMetadata:itemDto fileName:itemDto.fileName serverUrl:serverUrl autoUploadFileName:autoUploadFileName autoUploadDirectory:autoUploadDirectory activeAccount:account isFolderEncrypted:isFolderEncrypted]];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(account, metadatas, nil, 0);
            });
        });
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *token, NSString *redirectedServer) {
        
        NSString *message = @"";
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if (errorCode == 503) {
            message = NSLocalizedString(@"_server_error_retry_", nil);
        } else {
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        }
        
        completion(account, nil, message, errorCode);
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== downloadPreview =====
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

- (void)downloadPreviewWithAccount:(NSString *)account metadata:(tableMetadata*)metadata withWidth:(CGFloat)width andHeight:(CGFloat)height completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    NSString *file = [NSString stringWithFormat:@"%@/%@.ico", [CCUtility getDirectoryProviderStorageFileID:metadata.fileID], metadata.fileNameView];
    
    [communication getRemotePreviewByServer:tableAccount.url ofFilePath:[CCUtility returnFileNamePathFromFileName:metadata.fileName serverUrl:metadata.serverUrl activeUrl:tableAccount.url] withWidth:width andHeight:height andA:1 andMode:@"cover" path:@"" onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSData *preview, NSString *redirectedServer) {
        
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

- (void)downloadPreviewWithAccount:(NSString *)account serverPath:(NSString *)serverPath fileNamePath:(NSString *)fileNamePath completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getRemotePreviewByServer:tableAccount.url ofFilePath:@"" withWidth:0 andHeight:0 andA:0 andMode:@"" path:serverPath onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSData *preview, NSString *redirectedServer) {
        
        [preview writeToFile:fileNamePath atomically:YES];
        
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

- (void)downloadPreviewTrashWithAccount:(NSString *)account FileID:(NSString *)fileID fileName:(NSString *)fileName completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        
        completion(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    NSString *file = [NSString stringWithFormat:@"%@/%@.ico", [CCUtility getDirectoryProviderStorageFileID:fileID], fileName];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:file]) {
        
        completion(account, nil, 0);
        
    } else {
        
        OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
        
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

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Favorite =====
#pragma --------------------------------------------------------------------------------------------

- (void)listingFavoritesWithAccount:(NSString *)account completion:(void(^)(NSString *account, NSArray *metadatas, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    NSString *path = [tableAccount.url stringByAppendingString:k_dav];
    
    [communication listingFavorites:path folder:@"" withUserSessionToken:nil onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer, NSString *token) {
        
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
                completion(account, metadatas, nil, 0);
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
        
        completion(account, nil, message, errorCode);
    }];
}

- (void)settingFavoriteWithAccount:(NSString *)account fileName:(NSString *)fileName favorite:(BOOL)favorite completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
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
        
        completion(account, message, errorCode);
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Share =====
#pragma --------------------------------------------------------------------------------------------

- (void)readShareWithAccount:(NSString *)account completion:(void (^)(NSString *account, NSArray *items, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication readSharedByServer:[tableAccount.url stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer) {
        
        completion(account, items, nil, 0);
        
    } failureRequest :^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message = @"";
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if (errorCode == 503) {
            message = NSLocalizedString(@"_server_error_retry_", nil);
        } else {
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        }
        
        completion(account, nil, message, errorCode);
    }];
}

- (void)shareWithAccount:(NSString *)account fileName:(NSString *)fileName password:(NSString *)password permission:(NSInteger)permission hideDownload:(BOOL)hideDownload completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication shareFileOrFolderByServer:[tableAccount.url stringByAppendingString:@"/"] andFileOrFolderPath:[fileName encodeString:NSUTF8StringEncoding] andPassword:[password encodeString:NSUTF8StringEncoding] andPermission:permission andHideDownload:hideDownload onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *token, NSString *redirectedServer) {
        
        completion(account, nil, 0);
                
    } failureRequest :^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message = @"";
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;

        // Error
        if (errorCode == 503) {
            message = NSLocalizedString(@"_server_error_retry_", nil);
        } else {
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        }
        
        completion(account, message, errorCode);
    }];
}

// * @param shareeType -> NSInteger: to set the type of sharee (user/group/federated)

- (void)shareUserGroupWithAccount:(NSString *)account userOrGroup:(NSString *)userOrGroup fileName:(NSString *)fileName permission:(NSInteger)permission shareeType:(NSInteger)shareeType completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication shareWith:userOrGroup shareeType:shareeType inServer:[tableAccount.url stringByAppendingString:@"/"] andFileOrFolderPath:[fileName encodeString:NSUTF8StringEncoding] andPermissions:permission onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        completion(account, nil, 0);
                
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message = @"";
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;

        // Error
        if (errorCode == 503) {
            message = NSLocalizedString(@"_server_error_retry_", nil);
        } else {
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        }
        
        completion(account, message, errorCode);
    }];
}

- (void)shareUpdateAccount:(NSString *)account shareID:(NSInteger)shareID password:(NSString *)password permission:(NSInteger)permission expirationTime:(NSString *)expirationTime hideDownload:(BOOL)hideDownload completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication updateShare:shareID ofServerPath:[tableAccount.url stringByAppendingString:@"/"] withPasswordProtect:[password encodeString:NSUTF8StringEncoding] andExpirationTime:expirationTime andPermissions:permission andHideDownload:hideDownload onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        completion(account, nil, 0);
                
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {

        NSString *message = @"";
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;

        // Error
        if (errorCode == 503) {
            message = NSLocalizedString(@"_server_error_retry_", nil);
        } else {
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        }
        
        completion(account, message, errorCode);
    }];
}

- (void)unshareAccount:(NSString *)account shareID:(NSInteger)shareID completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication unShareFileOrFolderByServer:[tableAccount.url stringByAppendingString:@"/"] andIdRemoteShared:shareID onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        completion(account, nil, 0);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message = @"";
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;

        // Error
        if (errorCode == 503) {
            message = NSLocalizedString(@"_server_error_retry_", nil);
        } else {
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        }
        
        completion(account, message, errorCode);
    }];
}

- (void)getUserGroupWithAccount:(NSString *)account searchString:(NSString *)searchString completion:(void (^)(NSString *account, NSArray *item, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication searchUsersAndGroupsWith:searchString forPage:1 with:50 ofServer:[tableAccount.url stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *itemList, NSString *redirectedServer) {
        
        completion(account, itemList, nil, 0);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message = @"";
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;

        // Error
        if (errorCode == 503) {
            message = NSLocalizedString(@"_server_error_retry_", nil);
        } else {
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        }
        
        completion(account, nil, message, errorCode);
    }];
}

- (void)getSharePermissionsFileWithAccount:(NSString *)account fileNamePath:(NSString *)fileNamePath completion:(void (^)(NSString *account, NSString *permissions, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, 0, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
        
    [communication getSharePermissionsFile:fileNamePath onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *permissions, NSString *redirectedServer) {
        
        completion(account, permissions, nil ,0);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message = @"";
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if (errorCode == 503) {
            message = NSLocalizedString(@"_server_error_retry_", nil);
        } else {
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        }
        
        completion(account, nil, message, errorCode);
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== API =====
#pragma --------------------------------------------------------------------------------------------

- (void)getActivityWithAccount:(NSString *)account since:(NSInteger)since limit:(NSInteger)limit completion:(void(^)(NSString *account, NSArray *listOfActivity, NSString *message, NSInteger errorCode))completion
{
    BOOL previews = false;

    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    tableCapabilities *capabilities = [[NCManageDatabase sharedInstance] getCapabilitesWithAccount:account];
    if (capabilities != nil && capabilities.versionMajor >= k_nextcloud_version_12_0) {
        previews = true;
    }
    
    [communication getActivityServer:[tableAccount.url stringByAppendingString:@"/"] since:since limit:limit previews:previews onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *listOfActivity, NSString *redirectedServer) {
        
        completion(account, listOfActivity, nil, 0);
        
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
        
        completion(account, nil, message, errorCode);
    }];
}

- (void)getExternalSitesWithAccount:(NSString *)account completion:(void (^)(NSString *account, NSArray *listOfExternalSites, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getExternalSitesServer:[tableAccount.url stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *listOfExternalSites, NSString *redirectedServer) {
        
        completion(account, listOfExternalSites, nil, 0);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message = @"";
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if (errorCode == 503) {
            message = NSLocalizedString(@"_server_error_retry_", nil);
        } else {
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        }
        
        completion(account, nil, message, errorCode);
    }];
}

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

- (void)getNotificationWithAccount:(NSString *)account completion:(void (^)(NSString *account, NSArray *listOfNotifications, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getNotificationServer:[tableAccount.url stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *listOfNotifications, NSString *redirectedServer) {
        
        completion(account, listOfNotifications, nil, 0);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message = @"";
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if (errorCode == 503) {
            message = NSLocalizedString(@"_server_error_retry_", nil);
        } else {
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        }
        
        completion(account, nil, message, errorCode);
    }];
}

- (void)setNotificationWithAccount:(NSString *)account serverUrl:(NSString *)serverUrl type:(NSString *)type completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication setNotificationServer:serverUrl type:type onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        completion(account, nil, 0);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message = @"";
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if (errorCode == 503) {
            message = NSLocalizedString(@"_server_error_retry_", nil);
        } else {
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        }
        
        completion(account, message, errorCode);
    }];
}

- (void)getCapabilitiesWithAccount:(NSString *)account completion:(void (^)(NSString *account, OCCapabilities *capabilities, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getCapabilitiesOfServer:[tableAccount.url stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, OCCapabilities *capabilities, NSString *redirectedServer) {
        
        completion(account, capabilities, nil, 0);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message = @"";
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if (errorCode == 503) {
            message = NSLocalizedString(@"_server_error_retry_", nil);
        } else {
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        }
        
        completion(account, nil, message, errorCode);
    }];
}

- (void)getUserProfileWithAccount:(NSString *)account completion:(void (^)(NSString *account, OCUserProfile *userProfile, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getUserProfileServer:[tableAccount.url stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, OCUserProfile *userProfile, NSString *redirectedServer) {
        
        completion(account, userProfile, nil, 0);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message = @"";
        NSInteger errorCode = response.statusCode;
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Error
        if (errorCode == 503) {
            message = NSLocalizedString(@"_server_error_retry_", nil);
        } else {
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        }
        
        completion(account, nil, message, errorCode);
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Push Notification =====
#pragma --------------------------------------------------------------------------------------------

- (void)subscribingPushNotificationWithAccount:(NSString *)account url:(NSString *)url pushToken:(NSString *)pushToken Hash:(NSString *)pushTokenHash devicePublicKey:(NSString *)devicePublicKey completion:(void(^)(NSString *account, NSString *deviceIdentifier, NSString *deviceIdentifierSignature, NSString *publicKey, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, nil, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    devicePublicKey = [CCUtility URLEncodeStringFromString:devicePublicKey];

    [communication subscribingNextcloudServerPush:url pushTokenHash:pushTokenHash devicePublicKey:devicePublicKey proxyServerPath: [NCBrandOptions sharedInstance].pushNotificationServerProxy onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *publicKey, NSString *deviceIdentifier, NSString *signature, NSString *redirectedServer) {
        
        deviceIdentifier = [CCUtility URLEncodeStringFromString:deviceIdentifier];
        signature = [CCUtility URLEncodeStringFromString:signature];
        publicKey = [CCUtility URLEncodeStringFromString:publicKey];
        
        [communication subscribingPushProxy:[NCBrandOptions sharedInstance].pushNotificationServerProxy pushToken:pushToken deviceIdentifier:deviceIdentifier deviceIdentifierSignature:signature publicKey:publicKey onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
            
            completion(account, deviceIdentifier, signature, publicKey, nil, 0);
            
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
                        
            completion(account, nil, nil, nil, message, errorCode);
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

        completion(account, nil, nil, nil, message, errorCode);
    }];
}

- (void)unsubscribingPushNotificationWithAccount:(NSString *)account url:(NSString *)url deviceIdentifier:(NSString *)deviceIdentifier deviceIdentifierSignature:(NSString *)deviceIdentifierSignature publicKey:(NSString *)publicKey completion:(void (^)(NSString *account ,NSString *message, NSInteger errorCode))completion {
    
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication unsubscribingNextcloudServerPush:url onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {

        [communication unsubscribingPushProxy:[NCBrandOptions sharedInstance].pushNotificationServerProxy deviceIdentifier:deviceIdentifier deviceIdentifierSignature:deviceIdentifierSignature publicKey:publicKey onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
            
            completion(account, nil, 0);
            
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
            
            completion(account, message, errorCode);
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
        
        completion(account, message, errorCode);
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Manage Mobile Editor OCS API =====
#pragma --------------------------------------------------------------------------------------------

- (void)createLinkRichdocumentsWithAccount:(NSString *)account fileID:(NSString *)fileID completion:(void(^)(NSString *account, NSString *link, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    NSString *fileIDServer = [[NCUtility sharedInstance] convertFileIDClientToFileIDServer:fileID];
    
    [communication createLinkRichdocuments:[tableAccount.url stringByAppendingString:@"/"] fileID:fileIDServer onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *link, NSString *redirectedServer) {
        
        completion(account, link, nil, 0);
        
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
        
        completion(account, nil,message, errorCode);
    }];
}

- (void)geTemplatesRichdocumentsWithAccount:(NSString *)account typeTemplate:(NSString *)typeTemplate completion:(void(^)(NSString *account, NSArray *listOfTemplate, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
        
    [communication geTemplatesRichdocuments:[tableAccount.url stringByAppendingString:@"/"] typeTemplate:typeTemplate onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *listOfTemplate, NSString *redirectedServer) {
        
        completion(account, listOfTemplate, nil, 0);
        
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
        
        completion(account, nil, message, errorCode);
    }];
}

- (void)createNewRichdocumentsWithAccount:(NSString *)account fileName:(NSString *)fileName serverUrl:(NSString *)serverUrl templateID:(NSString *)templateID completion:(void(^)(NSString *account, NSString *url, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
        
    [communication createNewRichdocuments:[tableAccount.url stringByAppendingString:@"/"] path:fileName templateID:templateID onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *url, NSString *redirectedServer) {
        
        completion(account, url, nil, 0);
        
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
        
        completion(account, nil, message, errorCode);
    }];
}

- (void)createAssetRichdocumentsWithAccount:(NSString *)account fileName:(NSString *)fileName serverUrl:(NSString *)serverUrl completion:(void(^)(NSString *account, NSString *link, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    NSString *fileNamePath = [CCUtility returnFileNamePathFromFileName:fileName serverUrl:serverUrl activeUrl:tableAccount.url];
    
    [communication createAssetRichdocuments:[tableAccount.url stringByAppendingString:@"/"] path:fileNamePath onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *url, NSString *redirectedServer) {
        
        completion(account, url, nil, 0);
        
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
        
        completion(account, nil, message, errorCode);
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Trash =====
#pragma --------------------------------------------------------------------------------------------

- (void)listingTrashWithAccount:(NSString *)account path:(NSString *)path serverUrl:(NSString *)serverUrl completion:(void (^)(NSString *account, NSArray *items, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication listingTrash:[serverUrl stringByAppendingString:path] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer) {
        
        // Check items > 0
        if ([items count] == 0) {
                
#ifndef EXTENSION
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                
            [appDelegate messageNotification:@"Server error" description:@"Read Folder WebDAV : [items NULL] please fix" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:k_CCErrorInternalError];
#endif
            completion(account, nil, NSLocalizedString(@"Read Folder WebDAV : [items NULL] please fix", nil), k_CCErrorInternalError);
                
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
                
            completion(account, listTrash, nil, 0);
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
        
        completion(account, nil,message, errorCode);
    }];
}

- (void)emptyTrashWithAccount:(NSString *)account completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:tableAccount.password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    NSString *path = [NSString stringWithFormat:@"%@%@/trashbin/%@/trash", tableAccount.url, k_dav, tableAccount.userID];
    
    [communication emptyTrash:path onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
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

