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
#import "NCEndToEndEncryption.h"
#import "NCNetworkingSync.h"
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
    [self sessionWWanUpload];
    [self sessionUploadForeground];
    
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
    if ([sessionDescription isEqualToString:k_upload_session_wwan]) return [self sessionWWanUpload];
    if ([sessionDescription isEqualToString:k_upload_session_foreground]) return [self sessionUploadForeground];

    return nil;
}

- (void)invalidateAndCancelAllSession
{
    [[self sessionDownload] invalidateAndCancel];
    [[self sessionDownloadForeground] invalidateAndCancel];
    [[self sessionWWanDownload] invalidateAndCancel];
    
    [[self sessionUpload] invalidateAndCancel];
    [[self sessionWWanUpload] invalidateAndCancel];
    [[self sessionUploadForeground] invalidateAndCancel];
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
        
        [[self sessionWWanUpload] getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            for (NSURLSessionTask *task in uploadTasks)
                if (taskStatus == k_taskStatusCancel) [task cancel];
                else if (taskStatus == k_taskStatusSuspend) [task suspend];
                else if (taskStatus == k_taskStatusResume) [task resume];
        }];
        
        [[self sessionUploadForeground] getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
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
                    NSLog(@"[LOG] Date '%@' could not be parsed: %@", dateString, error);
                    date = [NSDate date];
                }
            }
        
            NSArray *object = [[NSArray alloc] initWithObjects:session, fileID, task, nil];
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_networkingSessionNotification object:object];
            
            if (fileName.length > 0 && serverUrl.length > 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self downloadFileSuccessFailure:fileName fileID:metadata.fileID etag:etag date:date serverUrl:serverUrl selector:metadata.sessionSelector selectorPost:metadata.sessionSelectorPost errorCode:errorCode];
                });
            }
            
        } else {
            
            NSLog(@"[LOG] Remove record ? : metadata not found %@", url);

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate downloadFileSuccessFailure:fileName fileID:@"" serverUrl:serverUrl selector:@"" selectorPost:@"" errorMessage:@"Remove record ? : metadata not found" errorCode:k_CCErrorInternalError];
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
                        NSLog(@"[LOG] Date '%@' could not be parsed: %@", dateString, error);
                        date = [NSDate date];
                    }
                } else {
                    date = [NSDate date];
                }
            }
        
            NSArray *object = [[NSArray alloc] initWithObjects:session, fileID, task, nil];
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_networkingSessionNotification object:object];
        
            if (fileName.length > 0 && fileID.length > 0 && serverUrl.length > 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self uploadFileSuccessFailure:metadata fileName:fileName fileID:fileID etag:etag date:date serverUrl:serverUrl errorCode:errorCode];
                });
            }
            
        } else {
            NSLog(@"[LOG] Remove record ? : metadata not found %@", url);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate uploadFileSuccessFailure:fileName fileID:@"" assetLocalIdentifier:@"" serverUrl:serverUrl selector:@"" selectorPost:@"" errorMessage:@"Remove record ? : metadata not found" errorCode:k_CCErrorInternalError];
            });
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Download =====
#pragma --------------------------------------------------------------------------------------------

- (void)downloadFile:(NSString *)fileName fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector selectorPost:(NSString *)selectorPost session:(NSString *)session taskStatus:(NSInteger)taskStatus delegate:(id)delegate
{
    // add delegate
    [_delegates setObject:delegate forKey:fileID];
    
    if (fileID.length == 0) {
        
        [[self getDelegate:fileID] downloadFileSuccessFailure:fileName fileID:fileID serverUrl:serverUrl selector:selector selectorPost:@"" errorMessage:NSLocalizedStringFromTable(@"_file_folder_not_exists_", @"Error", nil) errorCode:kOCErrorServerPathNotFound];
        return;
    }
    
    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
    
    if (!metadata) {
        
        [delegate downloadFileSuccessFailure:fileName fileID:fileID serverUrl:serverUrl selector:selector selectorPost:@"" errorMessage:NSLocalizedStringFromTable(@"_file_folder_not_exists_", @"Error", nil) errorCode:kOCErrorServerPathNotFound];
        return;
    }
    
    // it's in download
    tableMetadata *result = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@ AND session CONTAINS 'download' AND sessionTaskIdentifier >= 0", metadata.fileID]];
        
    if (result) {
            
        [delegate downloadFileSuccessFailure:fileName fileID:fileID serverUrl:serverUrl selector:selector selectorPost:@"" errorMessage:@"File already in download" errorCode:k_CCErrorFileAlreadyInDownload];
        return;
    }
        
    // File exists ?
    tableLocalFile *localfile = [[NCManageDatabase sharedInstance] getTableLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", metadata.fileID]];
        
    if (localfile != nil && [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, metadata.fileID]]) {
            
        [[NCManageDatabase sharedInstance] setMetadataSession:@"" sessionError:@"" sessionSelector:@"" sessionSelectorPost:@"" sessionTaskIdentifier:k_taskIdentifierDone predicate:[NSPredicate predicateWithFormat:@"fileID = %@", metadata.fileID]];
            
        [delegate downloadFileSuccessFailure:metadata.fileName fileID:metadata.fileID serverUrl:serverUrl selector:selector selectorPost:selectorPost errorMessage:@"" errorCode:0];
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
    [request setValue:[CCUtility getUserAgent] forHTTPHeaderField:@"User-Agent"];
    
    if ([session isEqualToString:k_download_session]) sessionDownload = [self sessionDownload];
    else if ([session isEqualToString:k_download_session_foreground]) sessionDownload = [self sessionDownloadForeground];
    else if ([session isEqualToString:k_download_session_wwan]) sessionDownload = [self sessionWWanDownload];
    
    NSURLSessionDownloadTask *downloadTask = [sessionDownload downloadTaskWithRequest:request];
    
    if (downloadTask == nil) {
        
        [[NCManageDatabase sharedInstance] addActivityClient:fileName fileID:fileID action:k_activityDebugActionUpload selector:selector note:@"Serious internal error downloadTask not available" type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:_activeUrl];
        [[NCManageDatabase sharedInstance] setMetadataSession:nil sessionError:@"Serious internal error downloadTask not available" sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:k_taskIdentifierError predicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
        [self.delegate downloadFileSuccessFailure:fileName fileID:fileID serverUrl:serverUrl selector:selector selectorPost:@"" errorMessage:@"Serious internal error downloadTask not available" errorCode:k_CCErrorInternalError];

    } else {
        
        [[NCManageDatabase sharedInstance] setMetadataSession:nil sessionError:nil sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:downloadTask.taskIdentifier predicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
        
        // Manage uploadTask cancel,suspend,resume
        if (taskStatus == k_taskStatusCancel) [downloadTask cancel];
        else if (taskStatus == k_taskStatusSuspend) [downloadTask suspend];
        else if (taskStatus == k_taskStatusResume) [downloadTask resume];
        
        NSLog(@"[LOG] downloadFileSession %@ Task [%lu]", fileID, (unsigned long)downloadTask.taskIdentifier);
    }
    
    // Refresh datasource if is not a Plist
    if ([_delegate respondsToSelector:@selector(reloadDatasource:)])
        [_delegate reloadDatasource:serverUrl];
        
#ifndef EXTENSION
        [(AppDelegate *)[[UIApplication sharedApplication] delegate] updateApplicationIconBadgeNumber];
#endif
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
        NSLog(@"[LOG] metadata not found");
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
            [self.delegate downloadFileSuccessFailure:@"" fileID:@"" serverUrl:serverUrl selector:@"" selectorPost:@"" errorMessage:@"Serious error internal download : metadata not found" errorCode:k_CCErrorInternalError];
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
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate.listProgressMetadata removeObjectForKey:fileID];
#endif
    
    // Progress Task
    NSDictionary* userInfo = @{@"fileID": (fileID), @"serverUrl": (serverUrl), @"progress": ([NSNumber numberWithFloat:0.0])};
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"NotificationProgressTask" object:nil userInfo:userInfo];
        
    if (errorCode != 0) {
        
        if (errorCode != kCFURLErrorCancelled) {
            
            [[NCManageDatabase sharedInstance] setMetadataSession:nil sessionError:[CCError manageErrorKCF:errorCode withNumberError:NO] sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:k_taskIdentifierError predicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
        }
        
        [[self getDelegate:fileID] downloadFileSuccessFailure:fileName fileID:fileID serverUrl:serverUrl selector:selector selectorPost:selectorPost errorMessage:[CCError manageErrorKCF:errorCode withNumberError:YES] errorCode:errorCode];
        
    } else {
        
        tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
        if (!metadata) {
            
            [[NCManageDatabase sharedInstance] addActivityClient:fileName fileID:fileID action:k_activityDebugActionUpload selector:@"" note:[NSString stringWithFormat:@"Serious error internal download : metadata not found %@", fileName] type:k_activityTypeFailure verbose:k_activityVerboseDefault activeUrl:_activeUrl];
            
            NSLog(@"[LOG] Serious error internal download : metadata not found %@ ", fileName);
            
            [[self getDelegate:fileID] downloadFileSuccessFailure:fileName fileID:fileID serverUrl:serverUrl selector:selector selectorPost:selectorPost errorMessage:[NSString stringWithFormat:@"Serious error internal download : metadata not found %@", fileName] errorCode:k_CCErrorInternalError];

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

        // E2EE Decrypted
        tableE2eEncryption *object = [[NCManageDatabase sharedInstance] getE2eEncryptionWithPredicate:[NSPredicate predicateWithFormat:@"fileNameIdentifier = %@ AND serverUrl = %@", fileName, serverUrl]];
        if (object) {
            BOOL result = [[NCEndToEndEncryption sharedManager] decryptFileID:fileID directoryUser:_directoryUser key:object.key initializationVector:object.initializationVector authenticationTag:object.authenticationTag];
            if (!result) {
                
                [[NCManageDatabase sharedInstance] addActivityClient:metadata.fileNameView fileID:fileID action:k_activityDebugActionUpload selector:@"" note:[NSString stringWithFormat:@"Serious error internal download : decrypt error %@", fileName] type:k_activityTypeFailure verbose:k_activityVerboseDefault activeUrl:_activeUrl];
                
                [[self getDelegate:fileID] downloadFileSuccessFailure:fileName fileID:fileID serverUrl:serverUrl selector:selector selectorPost:selectorPost errorMessage:[NSString stringWithFormat:@"Serious error internal download : decrypt error %@", fileName] errorCode:k_CCErrorInternalError];
                
                return;
            }
        }
        
        // Icon
        [CCGraphics createNewImageFrom:metadata.fileID directoryUser:_directoryUser fileNameTo:metadata.fileID extension:[metadata.fileNameView pathExtension] size:@"m" imageForUpload:NO typeFile:metadata.typeFile writePreview:YES optimizedFileName:[CCUtility getOptimizedPhoto]];
                
        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:metadata.fileNameView fileID:metadata.fileID action:k_activityDebugActionDownload selector:metadata.sessionSelector note:serverUrl type:k_activityTypeSuccess verbose:k_activityVerboseDefault activeUrl:_activeUrl];
        
        [[self getDelegate:fileID] downloadFileSuccessFailure:fileName fileID:fileID serverUrl:serverUrl selector:selector selectorPost:selectorPost errorMessage:@"" errorCode:0];
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
        [delegate uploadFileSuccessFailure:metadataNet.fileName fileID:metadataNet.fileID assetLocalIdentifier:metadataNet.assetLocalIdentifier serverUrl:metadataNet.serverUrl selector:metadataNet.selector selectorPost:metadataNet.selectorPost errorMessage:@"Error photo/video not found, remove from upload" errorCode:k_CCErrorInternalError];
        return;
    }
    
    PHAsset *asset= result[0];
    
    // IMAGE
    if (asset.mediaType == PHAssetMediaTypeImage) {
        
        PHImageRequestOptions *options = [PHImageRequestOptions new];
        options.networkAccessAllowed = YES; // iCloud
        options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        options.synchronous = YES;
        options.progressHandler = ^(double progress, NSError *error, BOOL *stop, NSDictionary *info) {
            
            NSLog(@"cacheAsset: %f", progress);
            
            if (error)
                [delegate uploadFileSuccessFailure:metadataNet.fileName fileID:metadataNet.fileID assetLocalIdentifier:metadataNet.assetLocalIdentifier serverUrl:metadataNet.serverUrl selector:metadataNet.selector selectorPost:metadataNet.selectorPost errorMessage:[NSString stringWithFormat:@"Image request iCloud failed [%@]", error.description] errorCode:error.code];
        };
        
        [[PHImageManager defaultManager] requestImageDataForAsset:asset options:options resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
                
            NSError *error = nil;

            if ([dataUTI isEqualToString:@"public.heic"] && [CCUtility getFormatCompatibility]) {
                    
                UIImage *image = [UIImage imageWithData:imageData];
                imageData = UIImageJPEGRepresentation(image, 1.0);
                NSString *fileNameJPEG = [[metadataNet.fileName lastPathComponent] stringByDeletingPathExtension];
                metadataNet.fileName = [fileNameJPEG stringByAppendingString:@".jpg"];
                    
                [imageData writeToFile:[NSString stringWithFormat:@"%@/%@", _directoryUser, metadataNet.fileName] options:NSDataWritingAtomic error:&error];
                    
            } else {
                    
                [imageData writeToFile:[NSString stringWithFormat:@"%@/%@", _directoryUser, metadataNet.fileName] options:NSDataWritingAtomic error:&error];
            }
                
            if (error) {
                [delegate uploadFileSuccessFailure:metadataNet.fileName fileID:metadataNet.fileID assetLocalIdentifier:metadataNet.assetLocalIdentifier serverUrl:metadataNet.serverUrl selector:metadataNet.selector selectorPost:metadataNet.selectorPost errorMessage:[NSString stringWithFormat:@"Image request failed [%@]", error.description] errorCode:error.code];
            } else {
                // OOOOOK
                [self upload:metadataNet.fileName serverUrl:metadataNet.serverUrl assetLocalIdentifier:metadataNet.assetLocalIdentifier session:metadataNet.session taskStatus:metadataNet.taskStatus selector:metadataNet.selector selectorPost:metadataNet.selectorPost errorCode:metadataNet.errorCode delegate:delegate];
            }
        }];
    }
    
    // VIDEO
    if (asset.mediaType == PHAssetMediaTypeVideo) {
        
        PHVideoRequestOptions *options = [PHVideoRequestOptions new];
        options.networkAccessAllowed = YES;
        options.version = PHVideoRequestOptionsVersionOriginal;
        options.progressHandler = ^(double progress, NSError *error, BOOL *stop, NSDictionary *info) {
            
            NSLog(@"cacheAsset: %f", progress);
            
            if (error)
                [delegate uploadFileSuccessFailure:metadataNet.fileName fileID:metadataNet.fileID assetLocalIdentifier:metadataNet.assetLocalIdentifier serverUrl:metadataNet.serverUrl selector:metadataNet.selector selectorPost:metadataNet.selectorPost errorMessage:[NSString stringWithFormat:@"Video request iCloud failed [%@]", error.description] errorCode:error.code];
        };
        
        [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:options resultHandler:^(AVAsset *asset, AVAudioMix *audioMix, NSDictionary *info) {
            
            if ([asset isKindOfClass:[AVURLAsset class]]) {
                
                NSURL *fileURL = [[NSURL alloc] initFileURLWithPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, metadataNet.fileName]];
                NSError *error = nil;

                [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
                [[NSFileManager defaultManager] copyItemAtURL:[(AVURLAsset *)asset URL] toURL:fileURL error:&error];
                    
                if (error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [delegate uploadFileSuccessFailure:metadataNet.fileName fileID:metadataNet.fileID assetLocalIdentifier:metadataNet.assetLocalIdentifier serverUrl:metadataNet.serverUrl selector:metadataNet.selector selectorPost:metadataNet.selectorPost errorMessage:[NSString stringWithFormat:@"Video request failed [%@]", error.description] errorCode:error.code];
                    });
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // OOOOOK
                        [self upload:metadataNet.fileName serverUrl:metadataNet.serverUrl assetLocalIdentifier:metadataNet.assetLocalIdentifier session:metadataNet.session taskStatus:metadataNet.taskStatus selector:metadataNet.selector selectorPost:metadataNet.selectorPost errorCode:metadataNet.errorCode delegate:delegate];
                    });
                }
            }
        }];
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
    
    //fileID
    NSString *uploadID =  [k_uploadSessionID stringByAppendingString:[CCUtility createRandomString:16]];
    
    //add delegate
    if (delegate)
        [_delegates setObject:delegate forKey:uploadID];
    
    // create Metadata for Upload
    tableMetadata *metadata = [CCUtility insertFileSystemInMetadata:fileName fileNameView:fileName directory:_directoryUser activeAccount:_activeAccount];
    
    metadata.date = [NSDate new];
    metadata.e2eEncrypted = NO;
    metadata.fileID = uploadID;
    metadata.directoryID = directoryID;
    metadata.fileName = fileName;
    metadata.fileNameView = fileName;
    metadata.assetLocalIdentifier = assetLocalIdentifier;
    metadata.session = session;
    metadata.sessionID = uploadID;
    metadata.sessionSelector = selector;
    metadata.sessionSelectorPost = selectorPost;
    
    // E2EE : ENCRYPTED FILE
    if ([CCUtility isFolderEncrypted:serverUrl account:_activeAccount] && [CCUtility isEndToEndEnabled:_activeAccount]) {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
            NSString *errorMessage;
            NSString *fileNameIdentifier;
            NSString *e2eMetadata;
        
            [self encryptedE2EFile:fileName serverUrl:serverUrl directoryID:directoryID account:_activeAccount user:_activeUser userID:_activeUserID password:_activePassword url:_activeUrl errorMessage:&errorMessage fileNameIdentifier:&fileNameIdentifier e2eMetadata:&e2eMetadata];

            if (errorMessage != nil || fileNameIdentifier == nil) {
                [[self getDelegate:uploadID] uploadFileSuccessFailure:fileName fileID:uploadID assetLocalIdentifier:assetLocalIdentifier serverUrl:serverUrl selector:selector selectorPost:selectorPost errorMessage:errorMessage errorCode:k_CCErrorInternalError];
                return;
            }
        
            // Now the fileName is fileNameIdentifier && flag e2eEncrypted
            metadata.fileName = fileNameIdentifier;
            metadata.e2eEncrypted = YES;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [CCGraphics createNewImageFrom:metadata.fileNameView directoryUser:_directoryUser fileNameTo:metadata.fileID extension:[metadata.fileNameView pathExtension] size:@"m" imageForUpload:YES typeFile:metadata.typeFile writePreview:YES optimizedFileName:NO];
                [self uploadURLSessionMetadata:[[NCManageDatabase sharedInstance] addMetadata:metadata] serverUrl:serverUrl sessionID:uploadID taskStatus:taskStatus assetLocalIdentifier:assetLocalIdentifier selector:selector];
            });
        });
        
    } else {
    
        [CCGraphics createNewImageFrom:metadata.fileNameView directoryUser:_directoryUser fileNameTo:metadata.fileID extension:[metadata.fileNameView pathExtension] size:@"m" imageForUpload:YES typeFile:metadata.typeFile writePreview:YES optimizedFileName:NO];
        [self uploadURLSessionMetadata:[[NCManageDatabase sharedInstance] addMetadata:metadata] serverUrl:serverUrl sessionID:uploadID taskStatus:taskStatus assetLocalIdentifier:assetLocalIdentifier selector:selector];
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
            
        [self uploadURLSessionMetadata:metadata serverUrl:serverUrl sessionID:metadata.sessionID taskStatus:taskStatus assetLocalIdentifier:metadata.assetLocalIdentifier selector:metadata.sessionSelector];
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

- (void)uploadURLSessionMetadata:(tableMetadata *)metadata serverUrl:(NSString *)serverUrl sessionID:(NSString*)sessionID taskStatus:(NSInteger)taskStatus assetLocalIdentifier:(NSString *)assetLocalIdentifier selector:(NSString *)selector
{
    NSURL *url;
    NSMutableURLRequest *request;
    PHAsset *asset;
    
    NSString *fileNamePath = [[NSString stringWithFormat:@"%@/%@", serverUrl, metadata.fileName] encodeString:NSUTF8StringEncoding];
        
    url = [NSURL URLWithString:fileNamePath];
    request = [NSMutableURLRequest requestWithURL:url];
        
    NSData *authData = [[NSString stringWithFormat:@"%@:%@", _activeUser, _activePassword] dataUsingEncoding:NSUTF8StringEncoding];
    NSString *authValue = [NSString stringWithFormat: @"Basic %@",[authData base64EncodedStringWithOptions:0]];
    [request setHTTPMethod:@"PUT"];
    [request setValue:authValue forHTTPHeaderField:@"Authorization"];
    [request setValue:[CCUtility getUserAgent] forHTTPHeaderField:@"User-Agent"];

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
    
    [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, metadata.fileName] toPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, fileNameForUpload] error:nil];
    
    // file NOT exists
    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, fileNameForUpload]] == NO) {
        
        // Delete record : Metadata
        [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"sessionID = %@ AND account = %@", sessionID, _activeAccount] clearDateReadDirectoryID:nil];
        
        // Error for uploadFileFailure
        [[self getDelegate:sessionID] uploadFileSuccessFailure:metadata.fileName fileID:@"" assetLocalIdentifier:assetLocalIdentifier serverUrl:serverUrl selector:selector selectorPost:@"" errorMessage:NSLocalizedString(@"_file_not_present_", nil) errorCode:404];
        
        return;
    }
    
    NSURLSession *sessionUpload;
    
    // NSURLSession
    if ([metadata.session isEqualToString:k_upload_session]) sessionUpload = [self sessionUpload];
    else if ([metadata.session isEqualToString:k_upload_session_wwan]) sessionUpload = [self sessionWWanUpload];
    else if ([metadata.session isEqualToString:k_upload_session_foreground]) sessionUpload = [self sessionUploadForeground];

    NSURLSessionUploadTask *uploadTask = [sessionUpload uploadTaskWithRequest:request fromFile:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, fileNameForUpload]]];
    
    // Error
    if (uploadTask == nil) {
        
        NSString *messageError = @"Serious internal error uploadTask not available";
        [[NCManageDatabase sharedInstance] setMetadataSession:metadata.session sessionError:messageError sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:k_taskIdentifierError predicate:[NSPredicate predicateWithFormat:@"sessionID = %@ AND account = %@", sessionID, _activeAccount]];
        [[self getDelegate:sessionID] uploadFileSuccessFailure:metadata.fileNameView fileID:@"" assetLocalIdentifier:assetLocalIdentifier serverUrl:serverUrl selector:selector selectorPost:@"" errorMessage:messageError errorCode:k_CCErrorInternalError];
        
    } else {
        
        // E2EE : CREATE AND SEND METADATA
        if ([CCUtility isFolderEncrypted:serverUrl account:_activeAccount] && [CCUtility isEndToEndEnabled:_activeAccount]) {
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                
                // Send Metadata
                NSString *token;
               
                NSError *error = [[NCNetworkingSync sharedManager] sendEndToEndMetadataOnServerUrl:serverUrl account:_activeAccount user:_activeUser userID:_activeUserID password:_activePassword url:_activeUrl fileNameRename:nil fileNameNewRename:nil token:&token];
                
                dispatch_async(dispatch_get_main_queue(), ^{

                    if (error) {
                    
                        [uploadTask cancel];

                        NSString *messageError = [NSString stringWithFormat:@"%@ (%d)", error.localizedDescription, (int)error.code];
                        [[NCManageDatabase sharedInstance] setMetadataSession:metadata.session sessionError:messageError sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:k_taskIdentifierError predicate:[NSPredicate predicateWithFormat:@"sessionID = %@ AND account = %@", sessionID, _activeAccount]];
                        [[self getDelegate:sessionID] uploadFileSuccessFailure:metadata.fileNameView fileID:@"" assetLocalIdentifier:assetLocalIdentifier serverUrl:serverUrl selector:selector selectorPost:@"" errorMessage:messageError errorCode:k_CCErrorInternalError];
                        
                    } else {
                    
                        // *** E2EE ***
                        [[NCManageDatabase sharedInstance] setMetadataSession:metadata.session sessionError:@"" sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:uploadTask.taskIdentifier predicate:[NSPredicate predicateWithFormat:@"sessionID = %@ AND account = %@", sessionID, _activeAccount]];
                        
                        // Manage uploadTask cancel,suspend,resume
                        if (taskStatus == k_taskStatusCancel) [uploadTask cancel];
                        else if (taskStatus == k_taskStatusSuspend) [uploadTask suspend];
                        else if (taskStatus == k_taskStatusResume) [uploadTask resume];
                        
                        NSLog(@"[LOG] Upload file %@ TaskIdentifier %lu", metadata.fileName, (unsigned long)uploadTask.taskIdentifier);
                    }
                });
            });
            
         } else {
    
             // *** PLAIN ***
             [[NCManageDatabase sharedInstance] setMetadataSession:metadata.session sessionError:@"" sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:uploadTask.taskIdentifier predicate:[NSPredicate predicateWithFormat:@"sessionID = %@ AND account = %@", sessionID, _activeAccount]];
             
             // OK remove record on tableQueueUpload
             [[NCManageDatabase sharedInstance] deleteQueueUploadWithAssetLocalIdentifier:assetLocalIdentifier selector:selector];
             
#ifndef EXTENSION
             // Next tableQueueUpload
             [(AppDelegate *)[[UIApplication sharedApplication] delegate] performSelectorOnMainThread:@selector(loadAutoDownloadUpload:) withObject:[NSNumber numberWithInt:k_maxConcurrentOperationDownloadUpload] waitUntilDone:NO];
#endif
             
             // Manage uploadTask cancel,suspend,resume
             if (taskStatus == k_taskStatusCancel) [uploadTask cancel];
             else if (taskStatus == k_taskStatusSuspend) [uploadTask suspend];
             else if (taskStatus == k_taskStatusResume) [uploadTask resume];
             
             NSLog(@"[LOG] Upload file %@ TaskIdentifier %lu", metadata.fileName, (unsigned long)uploadTask.taskIdentifier);
         }
    }

    // refresh main
    if ([self.delegate respondsToSelector:@selector(reloadDatasource:)])
        [self.delegate reloadDatasource:serverUrl];
        
#ifndef EXTENSION
    [(AppDelegate *)[[UIApplication sharedApplication] delegate] updateApplicationIconBadgeNumber];
#endif
    
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
    NSString *errorMessage = @"";
    
    // Progress Task
    NSDictionary* userInfo = @{@"fileID": (fileID), @"serverUrl": (serverUrl), @"progress": ([NSNumber numberWithFloat:0.0])};
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"NotificationProgressTask" object:nil userInfo:userInfo];
    
    // ERRORE
    if (errorCode != 0) {
        
#ifndef EXTENSION
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        [appDelegate.listProgressMetadata removeObjectForKey:sessionID];
#endif
        
        // Mark error only if not Cancelled Task
        if (errorCode != kCFURLErrorCancelled)  {

            [[NCManageDatabase sharedInstance] setMetadataSession:nil sessionError:[CCError manageErrorKCF:errorCode withNumberError:NO] sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:k_taskIdentifierError predicate:[NSPredicate predicateWithFormat:@"sessionID = %@ AND account = %@", metadata.sessionID, _activeAccount]];
        }
        
        errorMessage = [CCError manageErrorKCF:errorCode withNumberError:YES];
        
    } else {
    
        // copy ico in new fileID
        [CCUtility copyFileAtPath:[NSString stringWithFormat:@"%@/%@.ico", _directoryUser, sessionID] toPath:[NSString stringWithFormat:@"%@/%@.ico", _directoryUser, fileID]];
        
        // Add new metadata
        metadata.fileID = fileID;
        metadata.etag = etag;
        metadata.date = date;
        metadata.e2eEncrypted = false;
        metadata.sessionTaskIdentifier = k_taskIdentifierDone;
        metadata = [[NCManageDatabase sharedInstance] addMetadata:metadata];
        
        // Delete old ID_UPLOAD_XXXXX metadata
        [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", sessionID] clearDateReadDirectoryID:nil];
    
#ifndef EXTENSION
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        [appDelegate.listProgressMetadata removeObjectForKey:sessionID];
#endif
        
        metadata.session = @"";
        metadata.sessionError = @"";
        metadata.sessionID = @"";
        metadata = [[NCManageDatabase sharedInstance] updateMetadata:metadata];
    
        NSLog(@"[LOG] Insert new upload : %@ - fileID : %@", metadata.fileName, metadata.fileID);

        if ([CCUtility isFolderEncrypted:serverUrl account:_activeAccount]) {
        
            // rename file fileNameView (original file) -> fileID
            [CCUtility moveFileAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, metadata.fileNameView]  toPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, metadata.fileID]];
            // remove encrypted file
            [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, sessionID] error:nil];
        
        } else {
        
            // rename file sessionID -> fileID
            [CCUtility moveFileAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, sessionID]  toPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, metadata.fileID]];
        }
    
        // Local
        if (metadata.directory == NO)
            [[NCManageDatabase sharedInstance] addLocalFileWithMetadata:metadata];
        
        // EXIF
        if ([metadata.typeFile isEqualToString: k_metadataTypeFile_image])
            [[CCExifGeo sharedInstance] setExifLocalTableEtag:metadata directoryUser:_directoryUser activeAccount:_activeAccount];
        
        // Create ICON
        if (metadata.directory == NO)
            [CCGraphics createNewImageFrom:metadata.fileID directoryUser:_directoryUser fileNameTo:metadata.fileID extension:[metadata.fileNameView pathExtension] size:@"m" imageForUpload:NO typeFile:metadata.typeFile writePreview:YES optimizedFileName:[CCUtility getOptimizedPhoto]];
        
        // Optimization
        if (([CCUtility getUploadAndRemovePhoto] || [metadata.sessionSelectorPost isEqualToString:selectorUploadRemovePhoto]) && [metadata.typeFile isEqualToString:k_metadataTypeFile_document] == NO)
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
        [[NCManageDatabase sharedInstance] addActivityClient:metadata.fileNameView fileID:fileID action:k_activityDebugActionUpload selector:metadata.sessionSelector note:serverUrl type:k_activityTypeSuccess verbose:k_activityVerboseDefault activeUrl:_activeUrl];
    }
    
    // E2EE : UNLOCK
    if ([CCUtility isFolderEncrypted:serverUrl account:_activeAccount] && [CCUtility isEndToEndEnabled:_activeAccount]) {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            
            tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND serverUrl = %@", _activeAccount, serverUrl]];
            if (directory.e2eTokenLock.length > 0 && directory.e2eTokenLock) {
                NSError *error = [[NCNetworkingSync sharedManager] unlockEndToEndFolderEncrypted:_activeUser userID:_activeUserID password:_activePassword url:_activeUrl fileID:directory.fileID token:directory.e2eTokenLock];
                if (error) {
#ifndef EXTENSION
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [(AppDelegate *)[[UIApplication sharedApplication] delegate] messageNotification:@"_error_e2ee_" description:error.localizedDescription visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:error.code];
                    });
#endif
                }
            }
        });
    }
        
    [[self getDelegate:sessionID] uploadFileSuccessFailure:metadata.fileName fileID:metadata.fileID assetLocalIdentifier:metadata.assetLocalIdentifier serverUrl:serverUrl selector:metadata.sessionSelector selectorPost:metadata.sessionSelectorPost errorMessage:errorMessage errorCode:errorCode];
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

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== E2EE End To End Encryption =====
#pragma --------------------------------------------------------------------------------------------
// E2EE

- (void)encryptedE2EFile:(NSString *)fileName serverUrl:(NSString *)serverUrl directoryID:(NSString *)directoryID account:(NSString *)account user:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url errorMessage:(NSString * __autoreleasing *)errorMessage fileNameIdentifier:(NSString **)fileNameIdentifier e2eMetadata:(NSString * __autoreleasing *)e2eMetadata
{
    __block NSError *error;
    NSString *key;
    NSString *initializationVector;
    NSString *authenticationTag;
    NSString *metadataKey;
    NSInteger metadataKeyIndex;
    
    // Verify File Size
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, fileName] error:&error];
    NSNumber *fileSizeNumber = [fileAttributes objectForKey:NSFileSize];
    long long fileSize = [fileSizeNumber longLongValue];
        
    if (fileSize > k_max_filesize_E2E) {
        // Error for uploadFileFailure
        *errorMessage = @"E2E Error file too big";
        return;
    }
        
    // if exists overwrite file else create a new encrypted filename
    tableMetadata *overwriteMetadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND directoryID = %@ AND fileNameView = %@", _activeAccount, directoryID, fileName]];
    if (overwriteMetadata)
        *fileNameIdentifier = overwriteMetadata.fileName;
    else
        *fileNameIdentifier = [CCUtility generateRandomIdentifier];
    
    // Write to DB
    if ([[NCEndToEndEncryption sharedManager] encryptFileName:fileName fileNameIdentifier:*fileNameIdentifier directoryUser: _directoryUser key:&key initializationVector:&initializationVector authenticationTag:&authenticationTag]) {
        
        tableE2eEncryption *object = [[NCManageDatabase sharedInstance] getE2eEncryptionWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND serverUrl = %@", _activeAccount, serverUrl]];
        if (object) {
            metadataKey = object.metadataKey;
            metadataKeyIndex = object.metadataKeyIndex;
        } else {
            metadataKey = [[[NCEndToEndEncryption sharedManager] generateKey:16] base64EncodedStringWithOptions:0]; // AES_KEY_128_LENGTH
            metadataKeyIndex = 0;
        }
        
        tableE2eEncryption *addObject = [tableE2eEncryption new];
        
        addObject.account = _activeAccount;
        addObject.authenticationTag = authenticationTag;
        addObject.fileName = fileName;
        addObject.fileNameIdentifier = *fileNameIdentifier;
        addObject.fileNamePath = [CCUtility returnFileNamePathFromFileName:fileName serverUrl:serverUrl activeUrl:_activeUrl];
        addObject.key = key;
        addObject.initializationVector = initializationVector;
        addObject.metadataKey = metadataKey;
        addObject.metadataKeyIndex = metadataKeyIndex;
        
        CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[fileName pathExtension], NULL);
        CFStringRef mimeTypeRef = UTTypeCopyPreferredTagWithClass (UTI, kUTTagClassMIMEType);
        if (mimeTypeRef) {
            addObject.mimeType = (__bridge NSString *)mimeTypeRef;
        } else {
            addObject.mimeType = @"application/octet-stream";
        }
        
        addObject.serverUrl = serverUrl;
        addObject.version = [[NCManageDatabase sharedInstance] getEndToEndEncryptionVersion];
        
        // Get the last metadata
        NSString *metadata;
        tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND serverUrl = %@", account, serverUrl]];

        error = [[NCNetworkingSync sharedManager] getEndToEndMetadata:user userID:userID password:password url:url fileID:directory.fileID metadata:&metadata];
        if (error == nil) {
            if ([[NCEndToEndMetadata sharedInstance] decoderMetadata:metadata privateKey:[CCUtility getEndToEndPrivateKey:account] serverUrl:serverUrl account:account url:url] == false) {
                *errorMessage = NSLocalizedString(@"_e2e_error_decode_metadata_", nil);
                return;
            }
        }
        *e2eMetadata = metadata;
        
        // write new record e2ee
        if([[NCManageDatabase sharedInstance] addE2eEncryption:addObject] == NO)
            *errorMessage = NSLocalizedString(@"_e2e_error_create_encrypted_", nil);
        
    } else {
        *errorMessage = NSLocalizedString(@"_e2e_error_create_encrypted_", nil);
    }
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
    self = [self init];
    
    if (self) {

        _account = withAccount;
    }
    
    return self;
}

- (id)copyWithZone: (NSZone *) zone
{
    CCMetadataNet *metadataNet = [[CCMetadataNet allocWithZone: zone] init];
    
    [metadataNet setAccount: self.account];
    [metadataNet setAction: self.action];
    [metadataNet setAssetLocalIdentifier: self.assetLocalIdentifier];
    [metadataNet setContentType: self.contentType];
    [metadataNet setDate: self.date];
    [metadataNet setDelegate: self.delegate];
    [metadataNet setDepth: self.depth];
    [metadataNet setDirectory: self.directory];
    [metadataNet setDirectoryID: self.directoryID];
    [metadataNet setDirectoryIDTo: self.directoryIDTo];
    [metadataNet setEncryptedMetadata: self.encryptedMetadata];
    [metadataNet setErrorCode: self.errorCode];
    [metadataNet setErrorRetry: self.errorRetry];
    [metadataNet setEtag:self.etag];
    [metadataNet setExpirationTime: self.expirationTime];
    [metadataNet setFileID: self.fileID];
    [metadataNet setFileName: self.fileName];
    [metadataNet setFileNameTo: self.fileNameTo];
    [metadataNet setFileNameView: self.fileNameView];
    [metadataNet setKey: self.key];
    [metadataNet setKeyCipher: self.keyCipher];
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
    
    return metadataNet;
}

@end
