//
//  CCNetworking.m
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 01/06/15.
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

#import "CCNetworking.h"

#import "AppDelegate.h"
#import "CCCertificate.h"
#import "NSDate+ISO8601.h"
#import "NSString+Encode.h"
#import "NCBridgeSwift.h"

@interface CCNetworking ()
{
    NSMutableDictionary *_taskData;
    
    NSString *_activeAccount;
    NSString *_activePassword;
    NSString *_activeUser;
    NSString *_activeUserID;
    NSString *_activeUrl;
    NSString *_directoryUser;
}
@end

@implementation CCNetworking

+ (CCNetworking *)sharedNetworking {
    static CCNetworking *sharedNetworking;
    @synchronized(self)
    {
        if (!sharedNetworking) {
            sharedNetworking = [[CCNetworking alloc] init];
        }
        return sharedNetworking;
    }
}

- (id)init
{    
    self = [super init];
       
    _taskData = [[NSMutableDictionary alloc] init];
    _delegates = [[NSMutableDictionary alloc] init];
    
    // Initialization Sessions
    [self sessionDownload];
    [self sessionDownloadForeground];
    [self sessionWWanDownload];

    [self sessionUpload];
    [self sessionUploadForeground];
    [self sessionWWanUpload];
    
    [self sharedOCCommunication];
    
    [self settingAccount];
    
    return self;
}

- (void)settingAccount
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountActive];

    _activeAccount = tableAccount.account;
    _activePassword = tableAccount.password;
    _activeUser = tableAccount.user;
    _activeUserID = tableAccount.userID;
    _activeUrl = tableAccount.url;
    _directoryUser = [CCUtility getDirectoryActiveUser:_activeUser activeUrl:_activeUrl];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Session =====
#pragma --------------------------------------------------------------------------------------------

- (NSURLSession *)sessionDownload
{
    static NSURLSession *sessionDownload = nil;
    
    if (sessionDownload == nil) {
        
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:k_download_session];
        
        configuration.allowsCellularAccess = YES;
        configuration.sessionSendsLaunchEvents = YES;
        configuration.discretionary = NO;
        configuration.HTTPMaximumConnectionsPerHost = 1;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        
        sessionDownload = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
        sessionDownload.sessionDescription = k_download_session;
    }
    return sessionDownload;
}

- (NSURLSession *)sessionDownloadForeground
{
    static NSURLSession *sessionDownloadForeground = nil;
    
    if (sessionDownloadForeground == nil) {
        
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    
        configuration.allowsCellularAccess = YES;
        configuration.discretionary = NO;
        configuration.HTTPMaximumConnectionsPerHost = 1;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    
        sessionDownloadForeground = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
        sessionDownloadForeground.sessionDescription = k_download_session_foreground;
    }
    return sessionDownloadForeground;
}

- (NSURLSession *)sessionWWanDownload
{
    static NSURLSession *sessionWWanDownload = nil;
    
    if (sessionWWanDownload == nil) {
        
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:k_download_session_wwan];
        
        configuration.allowsCellularAccess = NO;
        configuration.sessionSendsLaunchEvents = YES;
        configuration.discretionary = NO;
        configuration.HTTPMaximumConnectionsPerHost = 1;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        
        sessionWWanDownload = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
        sessionWWanDownload.sessionDescription = k_download_session_wwan;
    }
    return sessionWWanDownload;
}

- (NSURLSession *)sessionUpload
{
    static NSURLSession *sessionUpload = nil;
    
    if (sessionUpload == nil) {
        
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:k_upload_session];
        
        configuration.allowsCellularAccess = YES;
        configuration.sessionSendsLaunchEvents = YES;
        configuration.discretionary = NO;
        configuration.HTTPMaximumConnectionsPerHost = 1;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        
        sessionUpload = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
        sessionUpload.sessionDescription = k_upload_session;
    }
    return sessionUpload;
}

- (NSURLSession *)sessionUploadForeground
{
    static NSURLSession *sessionUploadForeground;
    
    if (sessionUploadForeground == nil) {
        
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        
        configuration.allowsCellularAccess = YES;
        configuration.discretionary = NO;
        configuration.HTTPMaximumConnectionsPerHost = 1;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        
        sessionUploadForeground = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
        sessionUploadForeground.sessionDescription = k_upload_session_foreground;
    }
    return sessionUploadForeground;
}

- (NSURLSession *)sessionWWanUpload
{
    static NSURLSession *sessionWWanUpload = nil;
    
    if (sessionWWanUpload == nil) {
        
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:k_upload_session_wwan];
        
        configuration.allowsCellularAccess = NO;
        configuration.sessionSendsLaunchEvents = YES;
        configuration.discretionary = NO;
        configuration.HTTPMaximumConnectionsPerHost = 1;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        
        sessionWWanUpload = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
        sessionWWanUpload.sessionDescription = k_upload_session_wwan;
    }
    return sessionWWanUpload;
}

- (OCCommunication *)sharedOCCommunication
{
    static OCCommunication* sharedOCCommunication = nil;
    
    if (sharedOCCommunication == nil)
    {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        
        configuration.allowsCellularAccess = YES;
        configuration.discretionary = NO;
        configuration.HTTPMaximumConnectionsPerHost = k_maxConcurrentOperation;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        
        OCURLSessionManager *networkSessionManager = [[OCURLSessionManager alloc] initWithSessionConfiguration:configuration];
        [networkSessionManager.operationQueue setMaxConcurrentOperationCount: k_maxConcurrentOperation];
        networkSessionManager.responseSerializer = [AFHTTPResponseSerializer serializer];
        
        sharedOCCommunication = [[OCCommunication alloc] initWithUploadSessionManager:nil andDownloadSessionManager:nil andNetworkSessionManager:networkSessionManager];
    }
    
    return sharedOCCommunication;
}

- (NSURLSession *)getSessionfromSessionDescription:(NSString *)sessionDescription
{
    if ([sessionDescription isEqualToString:k_download_session]) return [self sessionDownload];
    if ([sessionDescription isEqualToString:k_download_session_foreground]) return [self sessionDownloadForeground];
    if ([sessionDescription isEqualToString:k_download_session_wwan]) return [self sessionWWanDownload];
    
    if ([sessionDescription isEqualToString:k_upload_session]) return [self sessionUpload];
    if ([sessionDescription isEqualToString:k_upload_session_foreground]) return [self sessionUploadForeground];
    if ([sessionDescription isEqualToString:k_upload_session_wwan]) return [self sessionWWanUpload];
    
    return nil;
}

- (void)invalidateAndCancelAllSession
{
    [[self sessionDownload] invalidateAndCancel];
    [[self sessionDownloadForeground] invalidateAndCancel];
    [[self sessionWWanDownload] invalidateAndCancel];
    
    [[self sessionUpload] invalidateAndCancel];
    [[self sessionUploadForeground] invalidateAndCancel];
    [[self sessionWWanUpload] invalidateAndCancel];    
}

- (void)settingSessionsDownload:(BOOL)download upload:(BOOL)upload taskStatus:(NSInteger)taskStatus activeAccount:(NSString *)activeAccount activeUser:(NSString *)activeUser activeUrl:(NSString *)activeUrl
{
    if (download) {
        
        [[self sessionDownload] getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            for (NSURLSessionTask *task in downloadTasks)
                if (taskStatus == k_taskStatusCancel) [task cancel];
                else if (taskStatus == k_taskStatusSuspend) [task suspend];
                else if (taskStatus == k_taskStatusResume) [task resume];
        }];
        
        [[self sessionDownloadForeground] getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            for (NSURLSessionTask *task in downloadTasks)
                if (taskStatus == k_taskStatusCancel) [task cancel];
                else if (taskStatus == k_taskStatusSuspend) [task suspend];
                else if (taskStatus == k_taskStatusResume) [task resume];
        }];
        
        [[self sessionWWanDownload] getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            for (NSURLSessionTask *task in downloadTasks)
                if (taskStatus == k_taskStatusCancel) [task cancel];
                else if (taskStatus == k_taskStatusSuspend) [task suspend];
                else if (taskStatus == k_taskStatusResume) [task resume];
        }];
    }
        
    if (upload) {
        
        [[self sessionUpload] getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            for (NSURLSessionTask *task in uploadTasks)
                if (taskStatus == k_taskStatusCancel)[task cancel];
                else if (taskStatus == k_taskStatusSuspend) [task suspend];
                else if (taskStatus == k_taskStatusResume) [task resume];
        }];
        
        [[self sessionUploadForeground] getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            for (NSURLSessionTask *task in uploadTasks)
                if (taskStatus == k_taskStatusCancel) [task cancel];
                else if (taskStatus == k_taskStatusSuspend) [task suspend];
                else if (taskStatus == k_taskStatusResume) [task resume];
        }];
        
        [[self sessionWWanUpload] getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            for (NSURLSessionTask *task in uploadTasks)
                if (taskStatus == k_taskStatusCancel) [task cancel];
                else if (taskStatus == k_taskStatusSuspend) [task suspend];
                else if (taskStatus == k_taskStatusResume) [task resume];
        }];
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        if (download && taskStatus == k_taskStatusCancel) {
        
            [[NCManageDatabase sharedInstance] setMetadataSession:@"" sessionError:@"" sessionSelector:@"" sessionSelectorPost:@"" sessionTaskIdentifier:k_taskIdentifierDone predicate:[NSPredicate predicateWithFormat:@"account = %@ AND session CONTAINS 'download'", _activeAccount]];
        }
    
        if (upload && taskStatus == k_taskStatusCancel) {
        
            [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"session CONTAINS 'upload'"] clearDateReadDirectoryID:nil];
        
            // File System
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [CCUtility removeAllFileID_UPLOAD_ActiveUser:activeUser activeUrl:activeUrl];
            });
        }
    });
}

- (void)settingSession:(NSString *)sessionDescription sessionTaskIdentifier:(NSUInteger)sessionTaskIdentifier taskStatus:(NSInteger)taskStatus
{
    NSURLSession *session = [self getSessionfromSessionDescription:sessionDescription];
    
    [session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        
        if ([sessionDescription containsString:@"download"])
            for (NSURLSessionTask *task in downloadTasks)
                if (task.taskIdentifier == sessionTaskIdentifier) {
                    if (taskStatus == k_taskStatusCancel) [task cancel];
                    else if (taskStatus == k_taskStatusSuspend) [task suspend];
                    else if (taskStatus == k_taskStatusResume) [task resume];
                }
        if ([sessionDescription containsString:@"upload"])
            for (NSURLSessionTask *task in uploadTasks)
                if (task.taskIdentifier == sessionTaskIdentifier) {
                    if (taskStatus == k_taskStatusCancel) [task cancel];
                    else if (taskStatus == k_taskStatusSuspend) [task suspend];
                    else if (taskStatus == k_taskStatusResume) [task resume];
                }
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== URLSession download/upload =====
#pragma --------------------------------------------------------------------------------------------

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
    // The pinnning check
    
    if ([[CCCertificate sharedManager] checkTrustedChallenge:challenge]) {
        completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]);
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    NSString *url = [[[task currentRequest].URL absoluteString] stringByRemovingPercentEncoding];
    
    if (!url)
        return;
    
    NSString *fileName = [url lastPathComponent];
    NSString *serverUrl = [self getServerUrlFromUrl:url];
    if (!serverUrl) return;
    NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:serverUrl];
    if (!directoryID) return;
    tableMetadata *metadata;
    
    NSInteger errorCode;
    NSDate *date = [NSDate date];
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    [dateFormatter setLocale:enUSPOSIXLocale];
    [dateFormatter setDateFormat:@"EEE, dd MMM y HH:mm:ss zzz"];
    
    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)task.response;
    
    if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        
        errorCode = error.code;
        
    } else {
        
        if (httpResponse.statusCode > 0)
            errorCode = httpResponse.statusCode;
        else
            errorCode = error.code;
    }

    // ----------------------- DOWNLOAD -----------------------
    
    if ([task isKindOfClass:[NSURLSessionDownloadTask class]]) {
        
        metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"session = %@ AND sessionTaskIdentifier = %i",session.sessionDescription, task.taskIdentifier]];
        
        if (!metadata)
            metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"directoryID = %@ AND fileName = %@", directoryID, fileName, fileName]];
        
        if (metadata) {
            
            NSString *etag = metadata.etag;
            NSString *fileID = metadata.fileID;
            NSDictionary *fields = [httpResponse allHeaderFields];
            
            if (errorCode == 0) {
            
                etag = [CCUtility removeForbiddenCharactersFileSystem:[fields objectForKey:@"OC-ETag"]];
            
                NSString *dateString = [fields objectForKey:@"Date"];
                if (![dateFormatter getObjectValue:&date forString:dateString range:nil error:&error]) {
                    NSLog(@"Date '%@' could not be parsed: %@", dateString, error);
                    date = [NSDate date];
                }
            
            }
        
            NSArray *object = [[NSArray alloc] initWithObjects:session, fileID, task, nil];
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_networkingSessionNotification object:object];
            
            if (fileName.length > 0 && serverUrl.length > 0)
                [self downloadFileSuccessFailure:fileName fileID:metadata.fileID etag:etag date:date serverUrl:serverUrl selector:metadata.sessionSelector selectorPost:metadata.sessionSelectorPost errorCode:errorCode];
        } else {
            
            NSLog(@"[LOG] Remove record ? : metadata not found %@", url);

            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(downloadFileFailure:serverUrl:selector:message:errorCode:)])
                    [self.delegate downloadFileFailure:@"" serverUrl:serverUrl selector:@"" message:@"" errorCode:k_CCErrorInternalError];
            });
        }
    }
    
    // ------------------------ UPLOAD -----------------------
    
    if ([task isKindOfClass:[NSURLSessionUploadTask class]]) {
        
        metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"session = %@ AND sessionTaskIdentifier = %i",session.sessionDescription, task.taskIdentifier]];
        
        if (!metadata)
            metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"directoryID = %@ AND fileName = %@", directoryID, fileName]];

        if (metadata) {
            
            NSDictionary *fields = [httpResponse allHeaderFields];
            NSString *fileID = metadata.fileID;
            NSString *etag = metadata.etag;
            
            if (errorCode == 0) {
            
                fileID = [CCUtility removeForbiddenCharactersFileSystem:[fields objectForKey:@"OC-FileId"]];
                etag = [CCUtility removeForbiddenCharactersFileSystem:[fields objectForKey:@"OC-ETag"]];
            
                NSString *dateString = [fields objectForKey:@"Date"];
                if (dateString) {
                    if (![dateFormatter getObjectValue:&date forString:dateString range:nil error:&error]) {
                        NSLog(@"Date '%@' could not be parsed: %@", dateString, error);
                        date = [NSDate date];
                    }
                } else {
                    date = [NSDate date];
                }
            }
        
            NSArray *object = [[NSArray alloc] initWithObjects:session, fileID, task, nil];
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_networkingSessionNotification object:object];
        
            if (fileName.length > 0 && fileID.length > 0 && serverUrl.length > 0)
                [self uploadFileSuccessFailure:metadata fileName:fileName fileID:fileID etag:etag date:date serverUrl:serverUrl errorCode:errorCode];
            
        } else {
            
            NSLog(@"[LOG] Remove record ? : metadata not found %@", url);

            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(uploadFileFailure:fileID:serverUrl:selector:message:errorCode:)])
                    [self.delegate uploadFileFailure:nil fileID:@"" serverUrl:serverUrl selector:@"" message:@"" errorCode:k_CCErrorInternalError];
            });
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Download =====
#pragma --------------------------------------------------------------------------------------------

- (void)downloadFile:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector selectorPost:(NSString *)selectorPost session:(NSString *)session taskStatus:(NSInteger)taskStatus delegate:(id)delegate
{
    // add delegate
    [_delegates setObject:delegate forKey:fileID];
    
    if (fileID.length == 0) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([[self getDelegate:fileID] respondsToSelector:@selector(downloadFileFailure:serverUrl:selector:message:errorCode:)])
                [[self getDelegate:fileID] downloadFileFailure:fileID serverUrl:serverUrl selector:selector message:NSLocalizedStringFromTable(@"_file_folder_not_exists_", @"Error", nil) errorCode:kOCErrorServerPathNotFound];
        });
        
        return;
    }
    
    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
    
    if (!metadata) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([[self getDelegate:fileID] respondsToSelector:@selector(downloadFileFailure:serverUrl:selector:message:errorCode:)])
                [[self getDelegate:fileID] downloadFileFailure:fileID serverUrl:serverUrl selector:selector message:NSLocalizedStringFromTable(@"_file_folder_not_exists_", @"Error", nil) errorCode:kOCErrorServerPathNotFound];
        });

        return;
    }
    
    // it's in download
    tableMetadata *result = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@ AND session CONTAINS 'download' AND sessionTaskIdentifier >= 0", _activeAccount, metadata.fileID]];
        
    if (result) {
            
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([[self getDelegate:fileID] respondsToSelector:@selector(downloadFileFailure:serverUrl:selector:message:errorCode:)])
                [[self getDelegate:fileID] downloadFileFailure:fileID serverUrl:serverUrl selector:selector message:@"File already in download" errorCode:k_CCErrorFileAlreadyInDownload];
        });

        return;
    }
        
    // File exists ?
    tableLocalFile *localfile = [[NCManageDatabase sharedInstance] getTableLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", metadata.fileID]];
        
    if (localfile != nil && [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, metadata.fileID]]) {
            
        [[NCManageDatabase sharedInstance] setMetadataSession:@"" sessionError:@"" sessionSelector:@"" sessionSelectorPost:@"" sessionTaskIdentifier:k_taskIdentifierDone predicate:[NSPredicate predicateWithFormat:@"fileID = %@", metadata.fileID]];
            
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([[self getDelegate:metadata.fileID] respondsToSelector:@selector(downloadFileSuccess:serverUrl:selector:selectorPost:)])
                [[self getDelegate:metadata.fileID] downloadFileSuccess:metadata.fileID serverUrl:serverUrl selector:selector selectorPost:selectorPost];
        });
            
        return;
    }
        
    [[NCManageDatabase sharedInstance] setMetadataSession:session sessionError:@"" sessionSelector:selector sessionSelectorPost:selectorPost sessionTaskIdentifier:k_taskIdentifierNULL predicate:[NSPredicate predicateWithFormat:@"fileID = %@",metadata.fileID]];
        
    [self downloaURLSession:metadata.fileName serverUrl:serverUrl fileID:metadata.fileID session:session taskStatus:taskStatus selector:selector];
}

- (void)downloaURLSession:(NSString *)fileName serverUrl:(NSString *)serverUrl fileID:(NSString *)fileID session:(NSString *)session taskStatus:(NSInteger)taskStatus selector:(NSString *)selector
{
    NSURLSession *sessionDownload;
    NSURL *url;
    NSMutableURLRequest *request;
    
    NSString *serverFileUrl = [[NSString stringWithFormat:@"%@/%@", serverUrl, fileName] encodeString:NSUTF8StringEncoding];
        
    url = [NSURL URLWithString:serverFileUrl];
    request = [NSMutableURLRequest requestWithURL:url];
        
    NSData *authData = [[NSString stringWithFormat:@"%@:%@", _activeUser, _activePassword] dataUsingEncoding:NSUTF8StringEncoding];
    NSString *authValue = [NSString stringWithFormat: @"Basic %@",[authData base64EncodedStringWithOptions:0]];
    [request setValue:authValue forHTTPHeaderField:@"Authorization"];
    
    if ([session isEqualToString:k_download_session]) sessionDownload = [self sessionDownload];
    else if ([session isEqualToString:k_download_session_foreground]) sessionDownload = [self sessionDownloadForeground];
    else if ([session isEqualToString:k_download_session_wwan]) sessionDownload = [self sessionWWanDownload];
    
    NSURLSessionDownloadTask *downloadTask = [sessionDownload downloadTaskWithRequest:request];
    
    if (downloadTask == nil) {
        
        [[NCManageDatabase sharedInstance] setMetadataSession:nil sessionError:[NSString stringWithFormat:@"%@", @k_CCErrorTaskNil] sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:k_taskIdentifierError predicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
        
        NSLog(@"[LOG] downloadFileSession TaskIdentifier [error CCErrorTaskNil] - %@", fileName);
        
    } else {
        
        [[NCManageDatabase sharedInstance] setMetadataSession:nil sessionError:nil sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:downloadTask.taskIdentifier predicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
        
        // Manage uploadTask cancel,suspend,resume
        if (taskStatus == k_taskStatusCancel) [downloadTask cancel];
        else if (taskStatus == k_taskStatusSuspend) [downloadTask suspend];
        else if (taskStatus == k_taskStatusResume) [downloadTask resume];
        
        NSLog(@"[LOG] downloadFileSession %@ Task [%lu]", fileID, (unsigned long)downloadTask.taskIdentifier);
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Refresh datasource if is not a Plist
        if ([_delegate respondsToSelector:@selector(reloadDatasource:)])
            [_delegate reloadDatasource:serverUrl];
        
#ifndef EXTENSION
        [app updateApplicationIconBadgeNumber];
#endif
    });
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    NSString *url = [[[downloadTask currentRequest].URL absoluteString] stringByRemovingPercentEncoding];
    NSString *fileName = [url lastPathComponent];
    NSString *serverUrl = [self getServerUrlFromUrl:url];
    if (!serverUrl) return;
    NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:serverUrl];
    if (!directoryID) return;
    
    float progress = (float) totalBytesWritten / (float)totalBytesExpectedToWrite;
    
    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataFromFileName:fileName directoryID:directoryID];
    
    if (metadata) {
        
        NSDictionary* userInfo = @{@"fileID": (metadata.fileID), @"serverUrl": (serverUrl), @"progress": ([NSNumber numberWithFloat:progress])};
            
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"NotificationProgressTask" object:nil userInfo:userInfo];
    } else {
        NSLog(@"metadata not found");
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    NSURLRequest *url = [downloadTask currentRequest];
    NSString *fileName = [[url.URL absoluteString] lastPathComponent];
    NSString *serverUrl = [self getServerUrlFromUrl:[url.URL absoluteString]];
    if (!serverUrl) return;
    
    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"session = %@ AND sessionTaskIdentifier = %i",session.sessionDescription, downloadTask.taskIdentifier]];
    
    // If the record metadata do not exists, exit
    if (!metadata) {
        
        [[NCManageDatabase sharedInstance] addActivityClient:fileName fileID:@"" action:k_activityDebugActionUpload selector:@"" note:[NSString stringWithFormat:@"Serious error internal download : metadata not found %@", url] type:k_activityTypeFailure verbose:k_activityVerboseDefault activeUrl:_activeUrl];
        
        NSLog(@"[LOG] Serious error internal download : metadata not found %@ ", url);

        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(downloadFileFailure:serverUrl:selector:message:errorCode:)])
                [self.delegate downloadFileFailure:@"" serverUrl:serverUrl selector:@"" message:@"" errorCode:k_CCErrorInternalError];
        });
        
        return;
    }
    
    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)downloadTask.response;
    
    if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        
        NSString *destinationFilePath = [NSString stringWithFormat:@"%@/%@", [CCUtility getDirectoryActiveUser:_activeUser activeUrl:_activeUrl], metadata.fileID];
        NSURL *destinationURL = [NSURL fileURLWithPath:destinationFilePath];
        
        [[NSFileManager defaultManager] removeItemAtURL:destinationURL error:NULL];
        [[NSFileManager defaultManager] copyItemAtURL:location toURL:destinationURL error:nil];
    }
}

- (void)downloadFileSuccessFailure:(NSString *)fileName fileID:(NSString *)fileID etag:(NSString *)etag date:(NSDate *)date serverUrl:(NSString *)serverUrl selector:(NSString *)selector selectorPost:(NSString *)selectorPost errorCode:(NSInteger)errorCode
{
#ifndef EXTENSION
    [app.listProgressMetadata removeObjectForKey:fileID];
#endif
    
    // Progress Task
    NSDictionary* userInfo = @{@"fileID": (fileID), @"serverUrl": (serverUrl), @"progress": ([NSNumber numberWithFloat:0.0])};
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"NotificationProgressTask" object:nil userInfo:userInfo];
        
    if (errorCode != 0) {
        
        if (errorCode != kCFURLErrorCancelled) {
            
            [[NCManageDatabase sharedInstance] setMetadataSession:nil sessionError:[NSString stringWithFormat:@"%@", @(errorCode)] sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:k_taskIdentifierError predicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([[self getDelegate:fileID] respondsToSelector:@selector(downloadFileFailure:serverUrl:selector:message:errorCode:)])
                [[self getDelegate:fileID] downloadFileFailure:fileID serverUrl:serverUrl selector:selector message:[CCError manageErrorKCF:errorCode withNumberError:YES] errorCode:errorCode];
        });
        
    } else {
        
        __block tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
        if (!metadata) {
            
            [[NCManageDatabase sharedInstance] addActivityClient:fileName fileID:fileID action:k_activityDebugActionUpload selector:@"" note:[NSString stringWithFormat:@"Serious error internal download : metadata not found %@", fileName] type:k_activityTypeFailure verbose:k_activityVerboseDefault activeUrl:_activeUrl];
            
            NSLog(@"[LOG] Serious error internal download : metadata not found %@ ", fileName);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(downloadFileFailure:serverUrl:selector:message:errorCode:)])
                    [self.delegate downloadFileFailure:fileID serverUrl:serverUrl selector:selector message:[NSString stringWithFormat:@"Serious error internal download : metadata not found %@", fileName] errorCode:k_CCErrorInternalError];
            });

            return;
        }
        
        metadata.session = @"";
        metadata.sessionError = @"";
        metadata.sessionSelector = @"";
        metadata.sessionSelectorPost = @"";
        metadata.sessionTaskIdentifier = k_taskIdentifierDone;
            
        metadata = [[NCManageDatabase sharedInstance] updateMetadata:metadata];
        [[NCManageDatabase sharedInstance] addLocalFileWithMetadata:metadata];
            
        if ([metadata.typeFile isEqualToString: k_metadataTypeFile_image])
            [[CCExifGeo sharedInstance] setExifLocalTableEtag:metadata directoryUser:_directoryUser activeAccount:_activeAccount];

        // Icon
        [CCGraphics createNewImageFrom:metadata.fileID directoryUser:_directoryUser fileNameTo:metadata.fileID extension:[metadata.fileName pathExtension] size:@"m" imageForUpload:NO typeFile:metadata.typeFile writePreview:YES optimizedFileName:[CCUtility getOptimizedPhoto]];
                
        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:fileName fileID:metadata.fileID action:k_activityDebugActionDownload selector:metadata.sessionSelector note:serverUrl type:k_activityTypeSuccess verbose:k_activityVerboseDefault activeUrl:_activeUrl];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([[self getDelegate:fileID] respondsToSelector:@selector(downloadFileSuccess:serverUrl:selector:selectorPost:)])
                [[self getDelegate:fileID] downloadFileSuccess:fileID serverUrl:serverUrl selector:selector selectorPost:selectorPost];
        });
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Upload =====
#pragma --------------------------------------------------------------------------------------------

- (void)uploadFileFromAssetLocalIdentifier:(CCMetadataNet *)metadataNet delegate:(id)delegate
{
    //delegate
    if (delegate == nil)
        delegate = self.delegate;
    
    PHFetchResult *result = [PHAsset fetchAssetsWithLocalIdentifiers:@[metadataNet.assetLocalIdentifier] options:nil];
    
    if (!result.count) {
        
        // Delete record on Table Auto Upload
        [[NCManageDatabase sharedInstance] deleteQueueUploadWithAssetLocalIdentifier:metadataNet.assetLocalIdentifier selector:metadataNet.selector];

        [[NCManageDatabase sharedInstance] addActivityClient:metadataNet.fileName fileID:metadataNet.assetLocalIdentifier action:k_activityDebugActionUpload selector:metadataNet.selector note:@"Error photo/video not found, remove from upload" type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:_activeUrl];
        
        if ([delegate respondsToSelector:@selector(uploadFileFailure:fileID:serverUrl:selector:message:errorCode:)])
            [delegate uploadFileFailure:metadataNet fileID:nil serverUrl:metadataNet.serverUrl selector:metadataNet.selector message:@"Error photo/video not found, remove from upload" errorCode: k_CCErrorInternalError];
        
        return;
    }
    
    @synchronized (self) {
    
        PHAsset *assetResult = result[0];
        PHAssetMediaType assetMediaType = assetResult.mediaType;
    
        // IMAGE
        if (assetMediaType == PHAssetMediaTypeImage) {
        
            __block PHAsset *asset = result[0];
            __block NSError *error = nil;
            
            PHImageRequestOptions *options = [PHImageRequestOptions new];
            options.networkAccessAllowed = YES; // iCloud
            
            [[PHImageManager defaultManager] requestImageDataForAsset:asset options:options resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
                
                tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountActive];

                if ([dataUTI isEqualToString:@"public.heic"] && tableAccount.autoUploadFormatCompatibility) {
                    
                    UIImage *image = [UIImage imageWithData:imageData];
                    NSData *imageDataJPEG = UIImageJPEGRepresentation(image, 1.0);
                    NSString *fileNameJPEG = [[metadataNet.fileName lastPathComponent] stringByDeletingPathExtension];
                    metadataNet.fileName = [fileNameJPEG stringByAppendingString:@".jpg"];
                    
                    [imageDataJPEG writeToFile:[NSString stringWithFormat:@"%@/%@", _directoryUser, metadataNet.fileName] options:NSDataWritingAtomic error:&error];
                    
                } else {
                    
                    [imageData writeToFile:[NSString stringWithFormat:@"%@/%@", _directoryUser, metadataNet.fileName] options:NSDataWritingAtomic error:&error];
                }
                
                if (error) {
                
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ([delegate respondsToSelector:@selector(uploadFileFailure:fileID:serverUrl:selector:message:errorCode:)])
                            [delegate uploadFileFailure:metadataNet fileID:nil serverUrl:metadataNet.serverUrl selector:metadataNet.selector message:[NSString stringWithFormat:@"Image request failed [%@]", error.description] errorCode:error.code];
                    });
                
                } else {
                    
                    // OOOOOK
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self upload:metadataNet.fileName serverUrl:metadataNet.serverUrl assetLocalIdentifier:metadataNet.assetLocalIdentifier session:metadataNet.session taskStatus:metadataNet.taskStatus selector:metadataNet.selector selectorPost:metadataNet.selectorPost errorCode:metadataNet.errorCode delegate:delegate];
                    });
                }
            }];
        }
    
        // VIDEO
        if (assetMediaType == PHAssetMediaTypeVideo) {
        
            __block PHAsset *asset = result[0];
        
            PHVideoRequestOptions *options = [PHVideoRequestOptions new];
            options.networkAccessAllowed = YES; // iCloud
            
            [[PHImageManager defaultManager] requestPlayerItemForVideo:asset options:options resultHandler:^(AVPlayerItem * _Nullable playerItem, NSDictionary * _Nullable info) {
                
                if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, metadataNet.fileName]])
                    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, metadataNet.fileName] error:nil];
                
                AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:playerItem.asset presetName:AVAssetExportPresetHighestQuality];
                
                if (exportSession) {
                    
                    exportSession.outputURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, metadataNet.fileName]];
                    exportSession.outputFileType = AVFileTypeQuickTimeMovie;
                    
                    [exportSession exportAsynchronouslyWithCompletionHandler:^{
                        
                        if (AVAssetExportSessionStatusCompleted == exportSession.status) {
                            
                            // OOOOOOK
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self upload:metadataNet.fileName serverUrl:metadataNet.serverUrl assetLocalIdentifier:metadataNet.assetLocalIdentifier session:metadataNet.session taskStatus:metadataNet.taskStatus selector:metadataNet.selector selectorPost:metadataNet.selectorPost errorCode:metadataNet.errorCode delegate:delegate];
                            });
                            
                        } else  {
                        
                            dispatch_async(dispatch_get_main_queue(), ^{
                                if ([delegate respondsToSelector:@selector(uploadFileFailure:fileID:serverUrl:selector:message:errorCode:)])
                                    [delegate uploadFileFailure:metadataNet fileID:nil serverUrl:metadataNet.serverUrl selector:metadataNet.selector message:[NSString stringWithFormat:@"Video export failed [%@]", exportSession.error.description] errorCode:exportSession.error.code];
                            });
                        }
                    }];
                    
                } else {
                
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ([delegate respondsToSelector:@selector(uploadFileFailure:fileID:serverUrl:selector:message:errorCode:)])
                            [delegate uploadFileFailure:metadataNet fileID:nil serverUrl:metadataNet.serverUrl selector:metadataNet.selector message:@"Create Video session failed [Internal error]" errorCode:k_CCErrorInternalError];
                    });
                }
            }];
        }
    }
}

- (void)uploadFile:(NSString *)fileName serverUrl:(NSString *)serverUrl session:(NSString *)session taskStatus:(NSInteger)taskStatus selector:(NSString *)selector selectorPost:(NSString *)selectorPost errorCode:(NSInteger)errorCode delegate:(id)delegate
{
    [self upload:fileName serverUrl:serverUrl assetLocalIdentifier:nil session:session taskStatus:taskStatus selector:selector selectorPost:selectorPost errorCode:errorCode delegate:delegate];
}

- (void)upload:(NSString *)fileName serverUrl:(NSString *)serverUrl assetLocalIdentifier:(NSString *)assetLocalIdentifier session:(NSString *)session taskStatus:(NSInteger)taskStatus selector:(NSString *)selector selectorPost:(NSString *)selectorPost errorCode:(NSInteger)errorCode delegate:(id)delegate
{
    NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:serverUrl];
    if (!directoryID) return;
    
    // create Metadata
    NSString *autoUploadFileName = [[NCManageDatabase sharedInstance] getAccountAutoUploadFileName];
    NSString *autoUploadDirectory = [[NCManageDatabase sharedInstance] getAccountAutoUploadDirectory:_activeUrl];
    
    __block tableMetadata *metadata = [CCUtility insertFileSystemInMetadata:fileName directory:_directoryUser activeAccount:_activeAccount autoUploadFileName:autoUploadFileName autoUploadDirectory:autoUploadDirectory];
    
    //fileID
    NSString *uploadID =  [k_uploadSessionID stringByAppendingString:[CCUtility createRandomString:16]];
    
    //add delegate
    if (delegate)
        [_delegates setObject:delegate forKey:uploadID];
    
    
    metadata.date = [NSDate new];
    metadata.fileID = uploadID;
    metadata.directoryID = directoryID;
    metadata.fileName = fileName;
    metadata.assetLocalIdentifier = assetLocalIdentifier;
    metadata.session = session;
    metadata.sessionID = uploadID;
    metadata.sessionSelector = selector;
    metadata.sessionSelectorPost = selectorPost;
        
    // File exists ???
    if (errorCode == 403) {
            
        dispatch_async(dispatch_get_main_queue(), ^{
                
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:fileName message:NSLocalizedString(@"_file_already_exists_", nil) preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                
                // Activity
                [[NCManageDatabase sharedInstance] addActivityClient:fileName fileID:uploadID action:k_activityDebugActionUpload selector:selector note:NSLocalizedString(@"_file_already_exists_", nil) type:k_activityTypeFailure verbose:k_activityVerboseDefault activeUrl:_activeUrl];
                
                // Error for uploadFileFailure
                if ([[self getDelegate:uploadID] respondsToSelector:@selector(uploadFileFailure:fileID:serverUrl:selector:message:errorCode:)])
                    [[self getDelegate:uploadID] uploadFileFailure:nil fileID:nil serverUrl:serverUrl selector:selector message:NSLocalizedString(@"_file_already_exists_", nil) errorCode:403];
                
                return;
            }];
            
            UIAlertAction *overwriteAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_overwrite_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                
                // -- remove record --
                tableMetadata *metadataDelete = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND fileName = %@ AND directoryID = %@", _activeAccount, fileName, directoryID]];
                
                [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, metadataDelete.fileID] error:nil];
                [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@.ico", _directoryUser, metadataDelete.fileID] error:nil];
                
                if (metadataDelete.directory && serverUrl) {
                    
                    NSString *dirForDelete = [CCUtility stringAppendServerUrl:serverUrl addFileName:metadataDelete.fileName];
                    
                    [[NCManageDatabase sharedInstance] deleteDirectoryAndSubDirectoryWithServerUrl:dirForDelete];
                }
                
                [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", metadataDelete.fileID] clearDateReadDirectoryID:nil];
                [[NCManageDatabase sharedInstance] deleteLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", metadataDelete.fileID]];

                // -- Go to Upload --
                [CCGraphics createNewImageFrom:metadata.fileName directoryUser:_directoryUser fileNameTo:metadata.fileID extension:[metadata.fileName pathExtension] size:@"m" imageForUpload:YES typeFile:metadata.typeFile writePreview:YES optimizedFileName:NO];
                
                metadata = [[NCManageDatabase sharedInstance] addMetadata:metadata];
                
                if (metadata) {
                        
                    [self uploadURLSession:fileName serverUrl:serverUrl sessionID:uploadID session:metadata.session taskStatus:taskStatus assetLocalIdentifier:assetLocalIdentifier selector:selector];
                }
            }];
            
            [alertController addAction:cancelAction];
            [alertController addAction:overwriteAction];
        
            UIWindow *alertWindow = [[UIWindow alloc]initWithFrame:[UIScreen mainScreen].bounds];
            alertWindow.rootViewController = [[UIViewController alloc] init];
            alertWindow.windowLevel = UIWindowLevelAlert + 1;
        
            [alertWindow makeKeyAndVisible];
            
            [alertWindow.rootViewController presentViewController:alertController animated:YES completion:nil];
        });
            
    } else {
            
        // -- Go to upload --
            
#ifndef EXTENSION
        [CCGraphics createNewImageFrom:metadata.fileName directoryUser:_directoryUser fileNameTo:metadata.fileID extension:[metadata.fileName pathExtension] size:@"m" imageForUpload:YES typeFile:metadata.typeFile writePreview:YES optimizedFileName:NO];
#endif
        metadata = [[NCManageDatabase sharedInstance] addMetadata:metadata];
            
        if (metadata) {
                
            [self uploadURLSession:fileName serverUrl:serverUrl sessionID:uploadID session:metadata.session taskStatus:taskStatus assetLocalIdentifier:assetLocalIdentifier selector:selector];
        }
    }
}

- (void)uploadFileMetadata:(tableMetadata *)metadata taskStatus:(NSInteger)taskStatus
{
    BOOL reSend = NO;
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
    if (!serverUrl) return;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, metadata.sessionID]]) {
            
        reSend = YES;
            
        NSLog(@"[LOG] Re-upload File : %@ - fileID : %@", metadata.fileName, metadata.fileID);
            
        [[NCManageDatabase sharedInstance] setMetadataSession:nil sessionError:@"" sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:k_taskIdentifierNULL predicate:[NSPredicate predicateWithFormat:@"sessionID = %@ AND account = %@", metadata.sessionID, _activeAccount]];
            
        [self uploadURLSession:metadata.fileName serverUrl:serverUrl sessionID:metadata.sessionID session:metadata.session taskStatus:taskStatus assetLocalIdentifier:metadata.assetLocalIdentifier selector:metadata.sessionSelector];
    }
    
    if (!reSend) {
        
        NSLog(@"[LOG] Error reUploadBackground, file not found.");
        
#ifndef EXTENSION
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_error_", nil) message:NSLocalizedString(@"_no_reuploadfile_", nil) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
        
        [alertController addAction:okAction];
        [[[[[UIApplication sharedApplication] delegate] window] rootViewController] presentViewController:alertController animated:YES completion:nil];
        return;
#endif
    }
}

- (void)uploadURLSession:(NSString *)fileName serverUrl:(NSString *)serverUrl sessionID:(NSString*)sessionID session:(NSString *)session taskStatus:(NSInteger)taskStatus assetLocalIdentifier:(NSString *)assetLocalIdentifier selector:(NSString *)selector
{
    NSURLSession *sessionUpload;
    NSURL *url;
    NSMutableURLRequest *request;
    PHAsset *asset;
    
    NSString *fileNamePath = [[NSString stringWithFormat:@"%@/%@", serverUrl, fileName] encodeString:NSUTF8StringEncoding];
        
    url = [NSURL URLWithString:fileNamePath];
    request = [NSMutableURLRequest requestWithURL:url];
        
    NSData *authData = [[NSString stringWithFormat:@"%@:%@", _activeUser, _activePassword] dataUsingEncoding:NSUTF8StringEncoding];
    NSString *authValue = [NSString stringWithFormat: @"Basic %@",[authData base64EncodedStringWithOptions:0]];
    [request setHTTPMethod:@"PUT"];
    [request setValue:authValue forHTTPHeaderField:@"Authorization"];
    
    // Change date file upload with header : X-OC-Mtime (ctime assetLocalIdentifier)
    if (assetLocalIdentifier) {
        PHFetchResult *result = [PHAsset fetchAssetsWithLocalIdentifiers:@[assetLocalIdentifier] options:nil];
        if (result.count) {
            asset = result[0];
            long dateFileCreation = [asset.creationDate timeIntervalSince1970];
            [request setValue:[NSString stringWithFormat:@"%ld", dateFileCreation] forHTTPHeaderField:@"X-OC-Mtime"];
        }
    }
    
    // Rename with the SessionID
    NSString *fileNameForUpload = sessionID;
    
    [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, fileName] toPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, fileNameForUpload] error:nil];
    
    // file NOT exists
    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, fileNameForUpload]] == NO) {
        
        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:fileName fileID:sessionID action:k_activityDebugActionUpload selector:selector note:NSLocalizedString(@"_file_not_present_", nil) type:k_activityTypeFailure verbose:k_activityVerboseDefault activeUrl:_activeUrl];
        
        // Delete record : Metadata
        [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"sessionID = %@ AND account = %@", sessionID, _activeAccount] clearDateReadDirectoryID:nil];
        
        // Delete record : Table Auto Upload
        [[NCManageDatabase sharedInstance] deleteQueueUploadWithAssetLocalIdentifier:assetLocalIdentifier selector:selector];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // Error for uploadFileFailure
            if ([[self getDelegate:sessionID] respondsToSelector:@selector(uploadFileFailure:fileID:serverUrl:selector:message:errorCode:)])
                [[self getDelegate:sessionID] uploadFileFailure:nil fileID:sessionID serverUrl:serverUrl selector:selector message:NSLocalizedString(@"_file_not_present_", nil) errorCode:404];
        });
        
        return;
    }
    
    if ([session isEqualToString:k_upload_session]) sessionUpload = [self sessionUpload];
    else if ([session isEqualToString:k_upload_session_foreground]) sessionUpload = [self sessionUploadForeground];
    else if ([session isEqualToString:k_upload_session_wwan]) sessionUpload = [self sessionWWanUpload];

    NSURLSessionUploadTask *uploadTask = [sessionUpload uploadTaskWithRequest:request fromFile:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, fileNameForUpload]]];
    
    // Error
    if (uploadTask == nil) {
        
        [[NCManageDatabase sharedInstance] addActivityClient:fileName fileID:assetLocalIdentifier action:k_activityDebugActionUpload selector:selector note:@"Upload task not available" type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:_activeUrl];
        
        [[NCManageDatabase sharedInstance] setMetadataSession:session sessionError:[NSString stringWithFormat:@"%@", @k_CCErrorTaskNil] sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:k_taskIdentifierError predicate:[NSPredicate predicateWithFormat:@"sessionID = %@ AND account = %@", sessionID, _activeAccount]];
        
        NSLog(@"[LOG] Upload file TaskIdentifier [error CCErrorTaskNil] - %@", fileName);
        
    } else {
        
        [[NCManageDatabase sharedInstance] setMetadataSession:session sessionError:@"" sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:uploadTask.taskIdentifier predicate:[NSPredicate predicateWithFormat:@"sessionID = %@ AND account = %@", sessionID, _activeAccount]];
        
        // OOOOOOKKKK remove record on Table Auto Upload
        [[NCManageDatabase sharedInstance] deleteQueueUploadWithAssetLocalIdentifier:assetLocalIdentifier selector:selector];
        
        // Manage uploadTask cancel,suspend,resume
        if (taskStatus == k_taskStatusCancel) [uploadTask cancel];
        else if (taskStatus == k_taskStatusSuspend) [uploadTask suspend];
        else if (taskStatus == k_taskStatusResume) [uploadTask resume];
        
        NSLog(@"[LOG] Upload file %@ TaskIdentifier %lu", fileName, (unsigned long)uploadTask.taskIdentifier);
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        // refresh main
        if ([self.delegate respondsToSelector:@selector(reloadDatasource:)])
            [self.delegate reloadDatasource:serverUrl];
        
#ifndef EXTENSION
        [app updateApplicationIconBadgeNumber];
#endif
    });
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)dataTask.response;
    
    if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        
        NSNumber *taskIdentifier = [NSNumber numberWithLong:dataTask.taskIdentifier];
        
        if (data)
            [_taskData setObject:[data copy] forKey:taskIdentifier];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    NSString *url = [[[task currentRequest].URL absoluteString] stringByRemovingPercentEncoding];
    NSString *fileName = [url lastPathComponent];
    NSString *serverUrl = [self getServerUrlFromUrl:url];
    if (!serverUrl) return;
    NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:serverUrl];
    if (!directoryID) return;
    
    float progress = (float) totalBytesSent / (float)totalBytesExpectedToSend;

    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataFromFileName:fileName directoryID:directoryID];
    
    if (metadata) {
            
        NSDictionary* userInfo = @{@"fileID": (metadata.fileID), @"serverUrl": (serverUrl), @"progress": ([NSNumber numberWithFloat:progress])};
                
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"NotificationProgressTask" object:nil userInfo:userInfo];
    }
}

- (void)uploadFileSuccessFailure:(tableMetadata *)metadata fileName:(NSString *)fileName fileID:(NSString *)fileID etag:(NSString *)etag date:(NSDate *)date serverUrl:(NSString *)serverUrl errorCode:(NSInteger)errorCode
{
    NSString *sessionID = metadata.sessionID;
    
    // Progress Task
    NSDictionary* userInfo = @{@"fileID": (fileID), @"serverUrl": (serverUrl), @"progress": ([NSNumber numberWithFloat:0.0])};
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"NotificationProgressTask" object:nil userInfo:userInfo];
    
    // ERRORE
    if (errorCode != 0) {
        
#ifndef EXTENSION
        [app.listProgressMetadata removeObjectForKey:sessionID];
#endif
        
        // Mark error only if not Cancelled Task
        if (errorCode != kCFURLErrorCancelled)  {

            [[NCManageDatabase sharedInstance] setMetadataSession:nil sessionError:[NSString stringWithFormat:@"%@", @(errorCode)] sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:k_taskIdentifierError predicate:[NSPredicate predicateWithFormat:@"sessionID = %@ AND account = %@", metadata.sessionID, _activeAccount]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([[self getDelegate:sessionID] respondsToSelector:@selector(uploadFileFailure:fileID:serverUrl:selector:message:errorCode:)])
                [[self getDelegate:sessionID] uploadFileFailure:nil fileID:fileID serverUrl:serverUrl selector:metadata.sessionSelector message:[CCError manageErrorKCF:errorCode withNumberError:YES] errorCode:errorCode];
        });
        
        return;
    }
    
    // copy ico in new fileID
    [CCUtility copyFileAtPath:[NSString stringWithFormat:@"%@/%@.ico", _directoryUser, sessionID] toPath:[NSString stringWithFormat:@"%@/%@.ico", _directoryUser, fileID]];
        
    metadata.fileID = fileID;
    metadata.etag = etag;
    metadata.date = date;
    metadata.sessionTaskIdentifier = k_taskIdentifierDone;
        
    // Add new metadata
    if (metadata)
        metadata = [[NCManageDatabase sharedInstance] addMetadata:metadata];
        
    if (!metadata) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([[self getDelegate:sessionID] respondsToSelector:@selector(uploadFileFailure:fileID:serverUrl:selector:message:errorCode:)])
                [[self getDelegate:sessionID] uploadFileFailure:nil fileID:fileID serverUrl:serverUrl selector:@"" message:[NSString stringWithFormat:@"Serious error internal upload : metadata not found %@", fileName] errorCode:k_CCErrorInternalError];
        });

        return;
    }
        
    // Delete old ID_UPLOAD_XXXXX metadata
    [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", sessionID] clearDateReadDirectoryID:nil];
    
#ifndef EXTENSION
    [app.listProgressMetadata removeObjectForKey:sessionID];
#endif
        
    NSLog(@"[LOG] Insert new upload : %@ - fileID : %@", metadata.fileName, metadata.fileID);
        
    metadata.session = @"";
    metadata.sessionError = @"";
    metadata.sessionID = @"";
        
    metadata = [[NCManageDatabase sharedInstance] updateMetadata:metadata];
        
    // rename file sessionID -> fileID
    [CCUtility moveFileAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, sessionID]  toPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, metadata.fileID]];
        
    // remove temp icon
    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@.ico", _directoryUser, sessionID] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@.ico", _directoryUser, metadata.fileID] error:nil];
        
    // Local
    if (metadata.directory == NO)
        [[NCManageDatabase sharedInstance] addLocalFileWithMetadata:metadata];
        
    // EXIF
    if ([metadata.typeFile isEqualToString: k_metadataTypeFile_image])
        [[CCExifGeo sharedInstance] setExifLocalTableEtag:metadata directoryUser:_directoryUser activeAccount:_activeAccount];
        
    // Create ICON
    if (metadata.directory == NO)
        [CCGraphics createNewImageFrom:metadata.fileID directoryUser:_directoryUser fileNameTo:metadata.fileID extension:[metadata.fileName pathExtension] size:@"m" imageForUpload:NO typeFile:metadata.typeFile writePreview:YES optimizedFileName:[CCUtility getOptimizedPhoto]];
        
    // Optimization
    if ([CCUtility getUploadAndRemovePhoto] || [metadata.sessionSelectorPost isEqualToString:selectorUploadRemovePhoto])
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, metadata.fileID] error:nil];
        
    // Copy photo or video in the photo album for auto upload
    if ([metadata.assetLocalIdentifier length] > 0 && ([metadata.sessionSelector isEqualToString:selectorUploadAutoUpload] || [metadata.sessionSelector isEqualToString:selectorUploadFile])) {
            
        PHAsset *asset;
        PHFetchResult *result = [PHAsset fetchAssetsWithLocalIdentifiers:@[metadata.assetLocalIdentifier] options:nil];
            
        if(result.count){
            asset = result[0];
                
            [asset saveToAlbum:[NCBrandOptions sharedInstance].brand completionBlock:^(BOOL success) {
                if (success) NSLog(@"[LOG] Insert file %@ in %@", metadata.fileName, [NCBrandOptions sharedInstance].brand);
                else NSLog(@"[LOG] File %@ do not insert in %@", metadata.fileName, [NCBrandOptions sharedInstance].brand);
            }];
        }
    }
        
    // Actvity
    [[NCManageDatabase sharedInstance] addActivityClient:fileName fileID:fileID action:k_activityDebugActionUpload selector:metadata.sessionSelector note:serverUrl type:k_activityTypeSuccess verbose:k_activityVerboseDefault activeUrl:_activeUrl];
        
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([[self getDelegate:sessionID] respondsToSelector:@selector(uploadFileSuccess:fileID:serverUrl:selector:selectorPost:)])
            [[self getDelegate:sessionID] uploadFileSuccess:nil fileID:metadata.fileID serverUrl:serverUrl selector:metadata.sessionSelector selectorPost:metadata.sessionSelectorPost];
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Download Verify =====
#pragma --------------------------------------------------------------------------------------------

- (void)verifyDownloadInProgress
{
    NSArray *dataSourceDownload = [[NCManageDatabase sharedInstance] getTableMetadataDownload];
    NSArray *dataSourceDownloadWWan = [[NCManageDatabase sharedInstance] getTableMetadataDownloadWWan];
    
    NSMutableArray *dataSource = [NSMutableArray new];
    
    [dataSource addObjectsFromArray:dataSourceDownload];
    [dataSource addObjectsFromArray:dataSourceDownloadWWan];
    
    NSLog(@"[LOG] Verify download file in progress n. %lu", (unsigned long)[dataSource count]);
    
    for (tableMetadata *metadata in dataSource) {
                
        NSURLSession *session = [self getSessionfromSessionDescription:metadata.session];
        
        [session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
            
                BOOL findTask = NO;
                BOOL findTaskPlist = NO;
            
                for (NSURLSessionDownloadTask *downloadTask in downloadTasks) {
                
                    NSLog(@"[LOG] Find metadata Tasks [%li] = [%lu] state : %lu", (long)metadata.sessionTaskIdentifier ,(unsigned long)downloadTask.taskIdentifier, (unsigned long)[downloadTask state]);
                
                    if (metadata.sessionTaskIdentifier == downloadTask.taskIdentifier) findTask = YES;
                
                    if (findTask == YES || findTaskPlist == YES) break; // trovati, download ancora in corso
                }
            
                // DATA
                if (findTask == NO && metadata.sessionTaskIdentifier >= 0) {
                
                    NSLog(@"[LOG] NOT Find metadata Task [%li] fileID : %@ - filename : %@", (long)metadata.sessionTaskIdentifier, metadata.fileID, metadata.fileName);
                
                    [[NCManageDatabase sharedInstance] setMetadataSession:nil sessionError:[NSString stringWithFormat:@"%@", @k_CCErrorTaskDownloadNotFound] sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:k_taskIdentifierError predicate:[NSPredicate predicateWithFormat:@"fileID = %@ ", metadata.fileID]];
                
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ([self.delegate respondsToSelector:@selector(reloadDatasource:)])
                            [self.delegate reloadDatasource:[[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID]];
                    });
                }
            });
        }];
    }
}

- (void)verifyDownloadInError:(id)delegate
{
    NSMutableSet *serversUrl = [NSMutableSet new];
    
    NSArray *metadatas = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND session CONTAINS 'download' AND sessionTaskIdentifier = %i", _activeAccount, k_taskIdentifierError] sorted:nil ascending:NO];
    
    NSLog(@"[LOG] Verify re download in error n. %lu", (unsigned long)[metadatas count]);
    
    for (tableMetadata *metadata in metadatas) {
        
        NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
        if (!serverUrl) continue;
        
        if (metadata.sessionTaskIdentifier == k_taskIdentifierError)
            [self downloadFile:metadata.fileID serverUrl:serverUrl selector:metadata.sessionSelector selectorPost:nil session:k_download_session taskStatus: k_taskStatusResume delegate:delegate];
        
        [serversUrl addObject:serverUrl];
        
        NSLog(@"[LOG] Re download file : %@ [%li]", metadata.fileName, (long)metadata.sessionTaskIdentifier);
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        for (NSString *serverUrl in serversUrl)
            if ([self.delegate respondsToSelector:@selector(reloadDatasource:)])
                [self.delegate reloadDatasource:serverUrl];
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Upload Verify =====
#pragma --------------------------------------------------------------------------------------------

- (void)verifyUploadInProgress
{
    NSArray *dataSourceUpload = [[NCManageDatabase sharedInstance] getTableMetadataUpload];
    NSArray *dataSourceUploadWWan = [[NCManageDatabase sharedInstance] getTableMetadataUploadWWan];
    
    NSMutableArray *dataSource = [[NSMutableArray alloc] init];
    
    [dataSource addObjectsFromArray:dataSourceUpload];
    [dataSource addObjectsFromArray:dataSourceUploadWWan];
    
    NSLog(@"[LOG] Verify upload file in progress n. %lu", (unsigned long)[dataSource count]);
    
    for (tableMetadata *metadata in dataSource) {
        
        __block NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
        if (!serverUrl) continue;
        
        NSURLSession *session = [self getSessionfromSessionDescription:metadata.session];
                
        [session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            
            BOOL findTask = NO;
            
            // cerchiamo la corrispondenza dei task
            for (NSURLSessionUploadTask *uploadTask in uploadTasks) {
                
                NSLog(@"[LOG] Find metadata Tasks [%li] = [%lu] state : %lu", (long)metadata.sessionTaskIdentifier, (unsigned long)uploadTask.taskIdentifier, (unsigned long)[uploadTask state]);
                
                if (metadata.sessionTaskIdentifier == uploadTask.taskIdentifier) findTask = YES;
                
                if (findTask == YES) break;
            }
            
            // se non c'è il relativo uploadTask.taskIdentifier allora chiediamolo
            if (findTask == NO) {
                
                NSLog(@"[LOG] Call ReadFileVerifyUpload because this file %@ is in progress but there is no task : [%li]", metadata.fileName, (long)metadata.sessionTaskIdentifier);
                
                if (metadata.sessionTaskIdentifier >= 0) [self readFileVerifyUpload:metadata.fileName serverUrl:serverUrl];
            }
        }];
        
        // Notification change session
        NSArray *object = [[NSArray alloc] initWithObjects:session, metadata, nil];
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_networkingSessionNotification object:object];
    }
}

- (void)verifyUploadInErrorOrWait
{
    NSMutableSet *directoryIDs = [NSMutableSet new];
    
    NSArray *metadatas = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND session CONTAINS 'upload' AND (sessionTaskIdentifier = %i OR sessionTaskIdentifier = %i)", _activeAccount, k_taskIdentifierError, k_taskIdentifierWaitStart] sorted:nil ascending:NO];
    
    NSLog(@"[LOG] Verify re upload in error n. %lu", (unsigned long)[metadatas count]);
    
    for (tableMetadata *metadata in metadatas) {
        
        [self uploadFileMetadata:metadata taskStatus: k_taskStatusResume];
        
        [directoryIDs addObject:metadata.directoryID];
        
        NSLog(@"[LOG] Re upload file : %@", metadata.fileName);
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        for (NSString *directoryID in directoryIDs)
            if ([self.delegate respondsToSelector:@selector(reloadDatasource:)])
                [self.delegate reloadDatasource:[[NCManageDatabase sharedInstance] getServerUrl:directoryID]];
    });
}

- (void)readFileVerifyUpload:(NSString *)fileName serverUrl:(NSString *)serverUrl
{
#ifndef EXTENSION
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:_activeAccount];
    
    metadataNet.action = actionReadFile;
    metadataNet.fileName = fileName;
    metadataNet.serverUrl = serverUrl;
    metadataNet.selector = selectorReadFileVerifyUpload;

    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
#else
    NSLog(@"[LOG] Function not available for extension.");
#endif
}

//
// File exists : selectorReadFileVerifyUpload
//
- (void)readFileSuccess:(CCMetadataNet *)metadataNet metadata:(tableMetadata *)metadata
{
    NSString *fileName = metadataNet.fileName;
    
    NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:metadataNet.serverUrl];
    if (!directoryID)
        [self uploadFileSuccessFailure:metadata fileName:metadataNet.fileName fileID:metadata.fileID etag:metadata.etag date:metadata.date serverUrl:metadataNet.serverUrl errorCode:k_CCErrorFileUploadNotFound];
    
    tableMetadata *metadataTemp = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileName = %@ AND directoryID = %@ AND account = %@", fileName , directoryID, _activeAccount]];
    
    // is completed ?
    if (metadataTemp.sessionTaskIdentifier == k_taskIdentifierDone) {
        
        [CCGraphics createNewImageFrom:metadata.fileID directoryUser:_directoryUser fileNameTo:metadata.fileID extension:[metadata.fileName pathExtension] size:@"m" imageForUpload:NO typeFile:metadata.typeFile writePreview:YES optimizedFileName:[CCUtility getOptimizedPhoto]];
        
        NSLog(@"[LOG] Verify read file success, but files already processed");
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(reloadDatasource:)])
                [self.delegate reloadDatasource:[[NCManageDatabase sharedInstance] getServerUrl:directoryID]];
        });
        
    } else {
        
        [self uploadFileSuccessFailure:metadataTemp fileName:metadataNet.fileName fileID:metadata.fileID etag:metadata.etag date:metadata.date serverUrl:metadataNet.serverUrl errorCode:0];
    }
}

//
// File do not exists : selectorReadFileVerifyUpload
//
- (void)readFileFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    NSString *fileName = metadataNet.fileName;
    
    NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:metadataNet.serverUrl];
    if (!directoryID) return;
    
    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileName = %@ AND directoryID = %@ AND account = %@",fileName , directoryID, _activeAccount]];
    
    NSInteger error;
    if (errorCode == kOCErrorServerPathNotFound)
        error = k_CCErrorFileUploadNotFound;
    else
        error = errorCode;
    
    // fix CCNetworking.m line 1340 2.17.2 (00005)
    if (metadata)
        [self uploadFileSuccessFailure:metadata fileName:metadataNet.fileName fileID:metadata.fileID etag:metadata.etag date:metadata.date serverUrl:metadataNet.serverUrl errorCode:error];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Utility =====
#pragma --------------------------------------------------------------------------------------------

- (id)getDelegate:(NSString *)fileID
{
    id delegate = [_delegates objectForKey:fileID];
    
    if (delegate)
        return delegate;
    else
        return self.delegate;
}

- (NSString *)getServerUrlFromUrl:(NSString *)url
{
    NSString *fileName = [url lastPathComponent];
    
    url = [url stringByReplacingOccurrencesOfString:[@"/" stringByAppendingString:fileName] withString:@""];

    return url;
}

- (NSString *)getTitleFromPlistName:(NSString *)fileName
{
    if ([[fileName lastPathComponent] isEqualToString:@"plist"] == NO)
        fileName = [fileName stringByAppendingString:@".plist"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, fileName]]) return nil;
    
    NSMutableDictionary *data = [[NSMutableDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/%@", _directoryUser, fileName]];
    
    return [data objectForKey:@"title"];
}

@end

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  CCMetadataNet =====
#pragma --------------------------------------------------------------------------------------------


@implementation CCMetadataNet

- (id)init
{
    self = [super init];
    self.priority = NSOperationQueuePriorityNormal;
    return self;
}

- (id)initWithAccount:(NSString *)withAccount
{
    self = [super init];
    
    if (self) {
        
        _account = withAccount;
        _priority = NSOperationQueuePriorityNormal;
    }
    
    return self;
}

- (id)copyWithZone: (NSZone *) zone
{
    CCMetadataNet *metadataNet = [[CCMetadataNet allocWithZone: zone] init];
    
    [metadataNet setAccount: self.account];
    [metadataNet setAction: self.action];
    [metadataNet setAssetLocalIdentifier: self.assetLocalIdentifier];
    [metadataNet setDate: self.date];
    [metadataNet setDelegate: self.delegate];
    [metadataNet setDepth: self.depth];
    [metadataNet setDirectory: self.directory];
    [metadataNet setDirectoryID: self.directoryID];
    [metadataNet setDirectoryIDTo: self.directoryIDTo];
    [metadataNet setErrorCode: self.errorCode];
    [metadataNet setErrorRetry: self.errorRetry];
    [metadataNet setEtag:self.etag];
    [metadataNet setExpirationTime: self.expirationTime];
    [metadataNet setFileID: self.fileID];
    [metadataNet setFileName: self.fileName];
    [metadataNet setFileNameTo: self.fileNameTo];
    [metadataNet setKey: self.key];
    [metadataNet setOptions: self.options];
    [metadataNet setPassword: self.password];
    [metadataNet setPathFolder: self.pathFolder];
    [metadataNet setPriority: self.priority];
    [metadataNet setServerUrl: self.serverUrl];
    [metadataNet setServerUrlTo: self.serverUrlTo];
    [metadataNet setSelector: self.selector];
    [metadataNet setSelectorPost: self.selectorPost];
    [metadataNet setSession: self.session];
    [metadataNet setSessionID: self.sessionID];
    [metadataNet setShare: self.share];
    [metadataNet setShareeType: self.shareeType];
    [metadataNet setSharePermission: self.sharePermission];
    [metadataNet setSize: self.size];
    [metadataNet setTaskStatus: self.taskStatus];
    [metadataNet setToken: self.token];
    
    return metadataNet;
}

@end
