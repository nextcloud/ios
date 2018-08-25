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
#import "NCNetworkingEndToEnd.h"
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
    
    // Initialization Sessions
    [self sessionDownload];
    [self sessionDownloadForeground];
    [self sessionWWanDownload];

    [self sessionUpload];
    [self sessionWWanUpload];
    [self sessionUploadForeground];
    
    // *** NOT Initialize ONLY for EXTENSION !!!!! ***
    // [self sessionUploadExtension];
    
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
        configuration.HTTPMaximumConnectionsPerHost = k_maxHTTPConnectionsPerHost;
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
        configuration.HTTPMaximumConnectionsPerHost = k_maxHTTPConnectionsPerHost;
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
        configuration.HTTPMaximumConnectionsPerHost = k_maxHTTPConnectionsPerHost;
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
        configuration.HTTPMaximumConnectionsPerHost = k_maxHTTPConnectionsPerHost;
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
        configuration.HTTPMaximumConnectionsPerHost = k_maxHTTPConnectionsPerHost;
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
        configuration.HTTPMaximumConnectionsPerHost = k_maxHTTPConnectionsPerHost;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        
        sessionUploadForeground = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
        sessionUploadForeground.sessionDescription = k_upload_session_foreground;
    }
    return sessionUploadForeground;
}

- (NSURLSession *)sessionUploadExtension
{
    static NSURLSession *sessionUpload = nil;
    
    if (sessionUpload == nil) {
        
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:k_upload_session_extension];
        
        configuration.allowsCellularAccess = YES;
        configuration.sessionSendsLaunchEvents = YES;
        configuration.discretionary = NO;
        configuration.HTTPMaximumConnectionsPerHost = 1;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        configuration.sharedContainerIdentifier = [NCBrandOptions sharedInstance].capabilitiesGroups;
        
        sessionUpload = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
        sessionUpload.sessionDescription = k_upload_session_extension;
    }
    return sessionUpload;
}

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

- (NSArray *)getUploadTasksExtensionSession
{
    __block NSArray *tasks = [NSArray new];
    [[self sessionUploadExtension] getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        tasks =  uploadTasks;
    }];
    
    return tasks;
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
        
        metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"directoryID == %@ AND fileName == %@", directoryID, fileName]];
        if (metadata) {
            
            NSString *etag = metadata.etag;
            //NSString *fileID = metadata.fileID;
            NSDictionary *fields = [httpResponse allHeaderFields];
            
            if (errorCode == 0) {
            
                etag = [CCUtility removeForbiddenCharactersFileSystem:[fields objectForKey:@"OC-ETag"]];
            
                NSString *dateString = [fields objectForKey:@"Date"];
                if (dateString) {
                    if (![dateFormatter getObjectValue:&date forString:dateString range:nil error:&error]) {
                        date = [NSDate date];
                    }
                } else {
                    date = [NSDate date];
                }
            }
            
            if (fileName.length > 0 && serverUrl.length > 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self downloadFileSuccessFailure:fileName fileID:metadata.fileID etag:etag date:date serverUrl:serverUrl selector:metadata.sessionSelector errorCode:errorCode];
                });
            }
            
        } else {
            
            NSLog(@"[LOG] Remove record ? : metadata not found %@", url);

            dispatch_async(dispatch_get_main_queue(), ^{
                
                if ([self.delegate respondsToSelector:@selector(downloadFileSuccessFailure:fileID:serverUrl:selector:errorMessage:errorCode:)]) {
                    [self.delegate downloadFileSuccessFailure:fileName fileID:@"" serverUrl:serverUrl selector:@"" errorMessage:@"" errorCode:k_CCErrorInternalError];
                }
            });
        }
    }
    
    // ------------------------ UPLOAD -----------------------
    
    if ([task isKindOfClass:[NSURLSessionUploadTask class]]) {
        
        metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"directoryID == %@ AND fileName == %@", directoryID, fileName]];
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
                
            if (fileName.length > 0 && fileID.length > 0 && serverUrl.length > 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self uploadFileSuccessFailure:metadata fileName:fileName fileID:fileID etag:etag date:date serverUrl:serverUrl errorCode:errorCode];
                });
            }
            
        } else {
            NSLog(@"[LOG] Remove record ? : metadata not found %@", url);
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(uploadFileSuccessFailure:fileID:assetLocalIdentifier:serverUrl:selector:errorMessage:errorCode:)]) {
                    [self.delegate uploadFileSuccessFailure:fileName fileID:@"" assetLocalIdentifier:@"" serverUrl:serverUrl selector:@"" errorMessage:@"" errorCode:k_CCErrorInternalError];
                }
            });
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Download =====
#pragma --------------------------------------------------------------------------------------------

- (void)downloadFile:(tableMetadata *)metadata taskStatus:(NSInteger)taskStatus
{
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];

    // File exists ?
    tableLocalFile *localfile = [[NCManageDatabase sharedInstance] getTableLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID]];
        
    if (!serverUrl || (localfile != nil && [CCUtility fileProviderStorageExists:metadata.fileID fileNameView:metadata.fileNameView])) {
            
        [[NCManageDatabase sharedInstance] setMetadataSession:@"" sessionError:@"" sessionSelector:@"" sessionTaskIdentifier:k_taskIdentifierDone status:k_metadataStatusNormal predicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID]];
        
        if ([self.delegate respondsToSelector:@selector(downloadFileSuccessFailure:fileID:serverUrl:selector:errorMessage:errorCode:)]) {
            [self.delegate downloadFileSuccessFailure:metadata.fileName fileID:metadata.fileID serverUrl:serverUrl selector:metadata.sessionSelector errorMessage:@"" errorCode:0];
        }
        return;
    }
    
    [self downloaURLSession:metadata serverUrl:serverUrl taskStatus:taskStatus];
}

- (void)downloaURLSession:(tableMetadata *)metadata serverUrl:(NSString *)serverUrl taskStatus:(NSInteger)taskStatus
{
    NSURLSession *sessionDownload;
    NSURL *url;
    NSMutableURLRequest *request;
    
    NSString *serverFileUrl = [[NSString stringWithFormat:@"%@/%@", serverUrl, metadata.fileName] encodeString:NSUTF8StringEncoding];
        
    url = [NSURL URLWithString:serverFileUrl];
    request = [NSMutableURLRequest requestWithURL:url];
        
    NSData *authData = [[NSString stringWithFormat:@"%@:%@", _activeUser, _activePassword] dataUsingEncoding:NSUTF8StringEncoding];
    NSString *authValue = [NSString stringWithFormat: @"Basic %@",[authData base64EncodedStringWithOptions:0]];
    [request setValue:authValue forHTTPHeaderField:@"Authorization"];
    [request setValue:[CCUtility getUserAgent] forHTTPHeaderField:@"User-Agent"];
    
    if ([metadata.session isEqualToString:k_download_session]) sessionDownload = [self sessionDownload];
    else if ([metadata.session isEqualToString:k_download_session_foreground]) sessionDownload = [self sessionDownloadForeground];
    else if ([metadata.session isEqualToString:k_download_session_wwan]) sessionDownload = [self sessionWWanDownload];
    
    NSURLSessionDownloadTask *downloadTask = [sessionDownload downloadTaskWithRequest:request];
    
    if (downloadTask == nil) {
        
        [[NCManageDatabase sharedInstance] addActivityClient:metadata.fileName fileID:metadata.fileID action:k_activityDebugActionUpload selector:metadata.sessionSelector note:@"Serious internal error downloadTask not available" type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:_activeUrl];
        [[NCManageDatabase sharedInstance] setMetadataSession:nil sessionError:@"Serious internal error downloadTask not available" sessionSelector:nil sessionTaskIdentifier:k_taskIdentifierDone status:k_metadataStatusDownloadError predicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID]];
        
        if ([self.delegate respondsToSelector:@selector(downloadFileSuccessFailure:fileID:serverUrl:selector:errorMessage:errorCode:)]) {
            [self.delegate downloadFileSuccessFailure:metadata.fileName fileID:metadata.fileID serverUrl:serverUrl selector:metadata.sessionSelector errorMessage:@"Serious internal error downloadTask not available" errorCode:k_CCErrorInternalError];
        }

    } else {
        
        // Manage uploadTask cancel,suspend,resume
        if (taskStatus == k_taskStatusCancel) [downloadTask cancel];
        else if (taskStatus == k_taskStatusSuspend) [downloadTask suspend];
        else if (taskStatus == k_taskStatusResume) [downloadTask resume];
        
        [[NCManageDatabase sharedInstance] setMetadataSession:nil sessionError:nil sessionSelector:nil sessionTaskIdentifier:downloadTask.taskIdentifier status:k_metadataStatusDownloading predicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID]];
        
        NSLog(@"[LOG] downloadFileSession %@ Task [%lu]", metadata.fileID, (unsigned long)downloadTask.taskIdentifier);
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(downloadStart:account:task:serverUrl:)]) {
            [self.delegate downloadStart:metadata.fileID account:metadata.account task:downloadTask serverUrl:serverUrl];
        }
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
    
    if (totalBytesExpectedToWrite < 1) {
        totalBytesExpectedToWrite = totalBytesWritten;
    }
        
    float progress = (float) totalBytesWritten / (float)totalBytesExpectedToWrite;
    
    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataInSessionFromFileName:fileName directoryID:directoryID];
    
    if (metadata) {
        
        NSDictionary* userInfo = @{@"fileID": (metadata.fileID), @"serverUrl": (serverUrl), @"status": ([NSNumber numberWithLong:k_metadataStatusInDownload]), @"progress": ([NSNumber numberWithFloat:progress]), @"totalBytes": ([NSNumber numberWithLongLong:totalBytesWritten]), @"totalBytesExpected": ([NSNumber numberWithLongLong:totalBytesExpectedToWrite])};
            
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"NotificationProgressTask" object:nil userInfo:userInfo];
    } else {
        NSLog(@"[LOG] metadata not found");
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    NSString *url = [[[downloadTask currentRequest].URL absoluteString] stringByRemovingPercentEncoding];
    if (!url)
        return;

    NSString *fileName = [url lastPathComponent];
    NSString *serverUrl = [self getServerUrlFromUrl:url];
    if (!serverUrl) return;
    NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:serverUrl];
    if (!directoryID) return;
    
    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"directoryID == %@ AND fileName == %@", directoryID, fileName]];
    if (!metadata) {
        
        [[NCManageDatabase sharedInstance] addActivityClient:fileName fileID:@"" action:k_activityDebugActionUpload selector:@"" note:[NSString stringWithFormat:@"Serious error internal download : metadata not found %@", url] type:k_activityTypeFailure verbose:k_activityVerboseDefault activeUrl:_activeUrl];
        
        NSLog(@"[LOG] Serious error internal download : metadata not found %@ ", url);

        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(downloadFileSuccessFailure:fileID:serverUrl:selector:errorMessage:errorCode:)]) {
                [self.delegate downloadFileSuccessFailure:@"" fileID:@"" serverUrl:serverUrl selector:@"" errorMessage:@"Serious error internal download : metadata not found" errorCode:k_CCErrorInternalError];
            }
        });
        
        return;
    }
    
    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)downloadTask.response;
    
    if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        
        NSString *destinationFilePath = [CCUtility getDirectoryProviderStorageFileID:metadata.fileID fileNameView:metadata.fileName];
        NSURL *destinationURL = [NSURL fileURLWithPath:destinationFilePath];
        
        [[NSFileManager defaultManager] removeItemAtURL:destinationURL error:NULL];
        [[NSFileManager defaultManager] copyItemAtURL:location toURL:destinationURL error:nil];
    }
}

- (void)downloadFileSuccessFailure:(NSString *)fileName fileID:(NSString *)fileID etag:(NSString *)etag date:(NSDate *)date serverUrl:(NSString *)serverUrl selector:(NSString *)selector errorCode:(NSInteger)errorCode
{
#ifndef EXTENSION
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate.listProgressMetadata removeObjectForKey:fileID];
#endif
    
    if (errorCode != 0) {
        
        if (errorCode == kCFURLErrorCancelled) {
            
            [[NCManageDatabase sharedInstance] setMetadataSession:@"" sessionError:@"" sessionSelector:@"" sessionTaskIdentifier:k_taskIdentifierDone status:k_metadataStatusNormal predicate:[NSPredicate predicateWithFormat:@"fileID == %@", fileID]];
            
        } else {
            
            [[NCManageDatabase sharedInstance] setMetadataSession:nil sessionError:[CCError manageErrorKCF:errorCode withNumberError:NO] sessionSelector:nil sessionTaskIdentifier:k_taskIdentifierDone status:k_metadataStatusDownloadError predicate:[NSPredicate predicateWithFormat:@"fileID == %@", fileID]];
        }
        
        if ([self.delegate respondsToSelector:@selector(downloadFileSuccessFailure:fileID:serverUrl:selector:errorMessage:errorCode:)]) {
            [self.delegate downloadFileSuccessFailure:fileName fileID:fileID serverUrl:serverUrl selector:selector errorMessage:[CCError manageErrorKCF:errorCode withNumberError:YES] errorCode:errorCode];
        }
        
    } else {
        
        tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", fileID]];
        if (!metadata) {
            
            [[NCManageDatabase sharedInstance] addActivityClient:fileName fileID:fileID action:k_activityDebugActionUpload selector:@"" note:[NSString stringWithFormat:@"Serious error internal download : metadata not found %@", fileName] type:k_activityTypeFailure verbose:k_activityVerboseDefault activeUrl:_activeUrl];
            
            NSLog(@"[LOG] Serious error internal download : metadata not found %@ ", fileName);
            
            if ([self.delegate respondsToSelector:@selector(downloadFileSuccessFailure:fileID:serverUrl:selector:errorMessage:errorCode:)]) {
                [self.delegate downloadFileSuccessFailure:fileName fileID:fileID serverUrl:serverUrl selector:selector errorMessage:[NSString stringWithFormat:@"Serious error internal download : metadata not found %@", fileName] errorCode:k_CCErrorInternalError];
            }

            return;
        }
        
        metadata.session = @"";
        metadata.sessionError = @"";
        metadata.sessionSelector = @"";
        metadata.sessionTaskIdentifier = k_taskIdentifierDone;
        metadata.status = k_metadataStatusNormal;
            
        metadata = [[NCManageDatabase sharedInstance] updateMetadata:metadata];
        [[NCManageDatabase sharedInstance] addLocalFileWithMetadata:metadata];
        
        // E2EE Decrypted
        tableE2eEncryption *object = [[NCManageDatabase sharedInstance] getE2eEncryptionWithPredicate:[NSPredicate predicateWithFormat:@"fileNameIdentifier == %@ AND serverUrl == %@", fileName, serverUrl]];
        if (object) {
            BOOL result = [[NCEndToEndEncryption sharedManager] decryptFileName:metadata.fileName fileNameView:metadata.fileNameView fileID:metadata.fileID key:object.key initializationVector:object.initializationVector authenticationTag:object.authenticationTag];
            if (!result) {
                
                [[NCManageDatabase sharedInstance] addActivityClient:metadata.fileNameView fileID:fileID action:k_activityDebugActionUpload selector:@"" note:[NSString stringWithFormat:@"Serious error internal download : decrypt error %@", fileName] type:k_activityTypeFailure verbose:k_activityVerboseDefault activeUrl:_activeUrl];
                
                if ([self.delegate respondsToSelector:@selector(downloadFileSuccessFailure:fileID:serverUrl:selector:errorMessage:errorCode:)]) {
                    [self.delegate downloadFileSuccessFailure:fileName fileID:fileID serverUrl:serverUrl selector:selector errorMessage:[NSString stringWithFormat:@"Serious error internal download : decrypt error %@", fileName] errorCode:k_CCErrorInternalError];
                }
                
                return;
            }
        }
        
        // Exif
        if ([metadata.typeFile isEqualToString: k_metadataTypeFile_image])
            [[CCExifGeo sharedInstance] setExifLocalTableEtag:metadata];
        
        // Icon
        if ([[NSFileManager defaultManager] fileExistsAtPath:[CCUtility getDirectoryProviderStorageIconFileID:metadata.fileID fileNameView:metadata.fileNameView]] == NO) {
            [CCGraphics createNewImageFrom:metadata.fileNameView fileID:metadata.fileID extension:[metadata.fileNameView pathExtension] filterGrayScale:NO typeFile:metadata.typeFile writeImage:YES];
        }
        
        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:metadata.fileNameView fileID:metadata.fileID action:k_activityDebugActionDownload selector:metadata.sessionSelector note:serverUrl type:k_activityTypeSuccess verbose:k_activityVerboseDefault activeUrl:_activeUrl];
        
        if ([self.delegate respondsToSelector:@selector(downloadFileSuccessFailure:fileID:serverUrl:selector:errorMessage:errorCode:)]) {
            [self.delegate downloadFileSuccessFailure:fileName fileID:fileID serverUrl:serverUrl selector:selector errorMessage:@"" errorCode:0];
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Upload =====
#pragma --------------------------------------------------------------------------------------------

- (void)uploadFile:(tableMetadata *)metadata taskStatus:(NSInteger)taskStatus
{
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
    
    if (!serverUrl || [CCUtility fileProviderStorageExists:metadata.fileID fileNameView:metadata.fileNameView] == NO) {
    
        PHFetchResult *result = [PHAsset fetchAssetsWithLocalIdentifiers:@[metadata.assetLocalIdentifier] options:nil];
        
        if (!result.count) {
            [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID] clearDateReadDirectoryID:metadata.directoryID];
            
            if ([self.delegate respondsToSelector:@selector(uploadFileSuccessFailure:fileID:assetLocalIdentifier:serverUrl:selector:errorMessage:errorCode:)]) {
                [self.delegate uploadFileSuccessFailure:metadata.fileName fileID:metadata.fileID assetLocalIdentifier:metadata.assetLocalIdentifier serverUrl:serverUrl selector:metadata.sessionSelector errorMessage:@"Error photo/video not found, remove from upload" errorCode:k_CCErrorInternalError];
            }
            
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
                
                if (error) {
                    [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID] clearDateReadDirectoryID:metadata.directoryID];
                
                    if ([self.delegate respondsToSelector:@selector(uploadFileSuccessFailure:fileID:assetLocalIdentifier:serverUrl:selector:errorMessage:errorCode:)]) {
                        [self.delegate uploadFileSuccessFailure:metadata.fileName fileID:metadata.fileID assetLocalIdentifier:metadata.assetLocalIdentifier serverUrl:serverUrl selector:metadata.sessionSelector errorMessage:[NSString stringWithFormat:@"Image request iCloud failed [%@]", error.description] errorCode:error.code];
                    }
                }
            };
            
            [[PHImageManager defaultManager] requestImageDataForAsset:asset options:options resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
                
                NSError *error = nil;
                
                if ([dataUTI isEqualToString:@"public.heic"] && [CCUtility getFormatCompatibility]) {
                    
                    UIImage *image = [UIImage imageWithData:imageData];
                    imageData = UIImageJPEGRepresentation(image, 1.0);
                    NSString *fileNameJPEG = [[metadata.fileName lastPathComponent] stringByDeletingPathExtension];
                    metadata.fileName = [fileNameJPEG stringByAppendingString:@".jpg"];
                    metadata.fileNameView = metadata.fileName;
                    
                    // Change Metadata with new fileID, fileName, fileNameView
                    [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID] clearDateReadDirectoryID:metadata.directoryID];
                    metadata.fileID = [metadata.directoryID stringByAppendingString:metadata.fileName];
                }
                
                tableMetadata *metadataForUpload = [[NCManageDatabase sharedInstance] addMetadata:[CCUtility insertFileSystemInMetadata:metadata]];
                [imageData writeToFile:[CCUtility getDirectoryProviderStorageFileID:metadataForUpload.fileID fileNameView:metadataForUpload.fileNameView] options:NSDataWritingAtomic error:&error];

                if (error) {
                    [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadataForUpload.fileID] clearDateReadDirectoryID:metadataForUpload.directoryID];
                    
                    if ([self.delegate respondsToSelector:@selector(uploadFileSuccessFailure:fileID:assetLocalIdentifier:serverUrl:selector:errorMessage:errorCode:)]) {
                        [self.delegate uploadFileSuccessFailure:metadataForUpload.fileName fileID:metadataForUpload.fileID assetLocalIdentifier:metadataForUpload.assetLocalIdentifier serverUrl:serverUrl selector:metadataForUpload.sessionSelector errorMessage:[NSString stringWithFormat:@"Image request failed [%@]", error.description] errorCode:error.code];
                    }
                    
                } else {
                    
                    // OOOOOK
                    if ([CCUtility isFolderEncrypted:serverUrl account:_activeAccount] && [CCUtility isEndToEndEnabled:_activeAccount]) {
                        [self e2eEncryptedFile:metadataForUpload serverUrl:serverUrl taskStatus:taskStatus];
                    } else {
                        [self uploadURLSessionMetadata:metadataForUpload serverUrl:serverUrl taskStatus:taskStatus];
                    }
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
                
                if (error) {
                    [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID] clearDateReadDirectoryID:metadata.directoryID];
                    
                    if ([self.delegate respondsToSelector:@selector(uploadFileSuccessFailure:fileID:assetLocalIdentifier:serverUrl:selector:errorMessage:errorCode:)]) {
                        [self.delegate uploadFileSuccessFailure:metadata.fileName fileID:metadata.fileID assetLocalIdentifier:metadata.assetLocalIdentifier serverUrl:serverUrl selector:metadata.sessionSelector errorMessage:[NSString stringWithFormat:@"Video request iCloud failed [%@]", error.description] errorCode:error.code];
                    }
                }
            };
            
            [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:options resultHandler:^(AVAsset *asset, AVAudioMix *audioMix, NSDictionary *info) {
                
                if ([asset isKindOfClass:[AVURLAsset class]]) {
                    
                    NSURL *fileURL = [[NSURL alloc] initFileURLWithPath:[CCUtility getDirectoryProviderStorageFileID:metadata.fileID fileNameView:metadata.fileNameView]];
                    NSError *error = nil;
                    
                    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
                    [[NSFileManager defaultManager] copyItemAtURL:[(AVURLAsset *)asset URL] toURL:fileURL error:&error];
                    
                    if (error) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID] clearDateReadDirectoryID:metadata.directoryID];
                            
                            if ([self.delegate respondsToSelector:@selector(uploadFileSuccessFailure:fileID:assetLocalIdentifier:serverUrl:selector:errorMessage:errorCode:)]) {
                                [self.delegate uploadFileSuccessFailure:metadata.fileName fileID:metadata.fileID assetLocalIdentifier:metadata.assetLocalIdentifier serverUrl:serverUrl selector:metadata.sessionSelector errorMessage:[NSString stringWithFormat:@"Video request failed [%@]", error.description] errorCode:error.code];
                            }
                        });
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            
                            // create Metadata for Upload
                            tableMetadata *metadataForUpload = [[NCManageDatabase sharedInstance] addMetadata:[CCUtility insertFileSystemInMetadata:metadata]];
                            
                            // OOOOOK
                            if ([CCUtility isFolderEncrypted:serverUrl account:_activeAccount] && [CCUtility isEndToEndEnabled:_activeAccount]) {
                                [self e2eEncryptedFile:metadataForUpload serverUrl:serverUrl taskStatus:taskStatus];
                            } else {
                                [self uploadURLSessionMetadata:metadataForUpload serverUrl:serverUrl taskStatus:taskStatus];
                            }
                        });
                    }
                }
            }];
        }
        
    } else {
        
        // create Metadata for Upload
        tableMetadata *metadataForUpload = [[NCManageDatabase sharedInstance] addMetadata:[CCUtility insertFileSystemInMetadata:metadata]];
        
        // OOOOOK
        if ([CCUtility isFolderEncrypted:serverUrl account:_activeAccount] && [CCUtility isEndToEndEnabled:_activeAccount]) {
            [self e2eEncryptedFile:metadataForUpload serverUrl:serverUrl taskStatus:taskStatus];
        } else {
            [self uploadURLSessionMetadata:metadataForUpload serverUrl:serverUrl taskStatus:taskStatus];
        }
    }
}

- (void)e2eEncryptedFile:(tableMetadata *)metadata serverUrl:(NSString *)serverUrl taskStatus:(NSInteger)taskStatus
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSString *errorMessage;
        NSString *fileNameIdentifier;
        NSString *e2eMetadata;
        
        [self encryptedE2EFile:metadata serverUrl:serverUrl account:_activeAccount user:_activeUser userID:_activeUserID password:_activePassword url:_activeUrl errorMessage:&errorMessage fileNameIdentifier:&fileNameIdentifier e2eMetadata:&e2eMetadata];
        
        if (errorMessage != nil || fileNameIdentifier == nil) {
            
            if ([self.delegate respondsToSelector:@selector(uploadFileSuccessFailure:fileID:assetLocalIdentifier:serverUrl:selector:errorMessage:errorCode:)]) {
                [self.delegate uploadFileSuccessFailure:metadata.fileName fileID:metadata.fileID assetLocalIdentifier:metadata.assetLocalIdentifier serverUrl:serverUrl selector:metadata.sessionSelector errorMessage:errorMessage errorCode:k_CCErrorInternalError];
            }
            
        } else {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                // Now the fileName is fileNameIdentifier && flag e2eEncrypted
                metadata.fileName = fileNameIdentifier;
                metadata.e2eEncrypted = YES;
            
                // Update Metadata
                tableMetadata *metadataEncrypted = [[NCManageDatabase sharedInstance] addMetadata:metadata];
            
                [self uploadURLSessionMetadata:metadataEncrypted serverUrl:serverUrl taskStatus:taskStatus];
            });
        }
    });
}

- (void)uploadURLSessionMetadata:(tableMetadata *)metadata serverUrl:(NSString *)serverUrl taskStatus:(NSInteger)taskStatus
{
    NSURL *url;
    NSMutableURLRequest *request;
    PHAsset *asset;
    NSError *error;
    
    // calculate and store file size
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[CCUtility getDirectoryProviderStorageFileID:metadata.fileID fileNameView:metadata.fileName] error:&error];
    long long fileSize = [[fileAttributes objectForKey:NSFileSize] longLongValue];
    metadata.size = fileSize;
    (void)[[NCManageDatabase sharedInstance] addMetadata:metadata];
    
    url = [NSURL URLWithString:[[NSString stringWithFormat:@"%@/%@", serverUrl, metadata.fileName] encodeString:NSUTF8StringEncoding]];
    request = [NSMutableURLRequest requestWithURL:url];
        
    NSData *authData = [[NSString stringWithFormat:@"%@:%@", _activeUser, _activePassword] dataUsingEncoding:NSUTF8StringEncoding];
    NSString *authValue = [NSString stringWithFormat: @"Basic %@",[authData base64EncodedStringWithOptions:0]];
    [request setHTTPMethod:@"PUT"];
    [request setValue:authValue forHTTPHeaderField:@"Authorization"];
    [request setValue:[CCUtility getUserAgent] forHTTPHeaderField:@"User-Agent"];

    // Create Image for Upload (gray scale)
#ifndef EXTENSION
    [CCGraphics createNewImageFrom:metadata.fileNameView fileID:metadata.fileID extension:[metadata.fileNameView pathExtension] filterGrayScale:YES typeFile:metadata.typeFile writeImage:YES];
#endif
    
    // Change date file upload with header : X-OC-Mtime (ctime assetLocalIdentifier) image/video
    if (metadata.assetLocalIdentifier) {
        PHFetchResult *result = [PHAsset fetchAssetsWithLocalIdentifiers:@[metadata.assetLocalIdentifier] options:nil];
        if (result.count) {
            asset = result[0];
            long dateFileCreation = [asset.creationDate timeIntervalSince1970];
            [request setValue:[NSString stringWithFormat:@"%ld", dateFileCreation] forHTTPHeaderField:@"X-OC-Mtime"];
        }
    }
    
    NSURLSession *sessionUpload;
    
    // NSURLSession
    if ([metadata.session isEqualToString:k_upload_session]) sessionUpload = [self sessionUpload];
    else if ([metadata.session isEqualToString:k_upload_session_wwan]) sessionUpload = [self sessionWWanUpload];
    else if ([metadata.session isEqualToString:k_upload_session_foreground]) sessionUpload = [self sessionUploadForeground];
    else if ([metadata.session isEqualToString:k_upload_session_extension]) sessionUpload = [self sessionUploadExtension];

    NSURLSessionUploadTask *uploadTask = [sessionUpload uploadTaskWithRequest:request fromFile:[NSURL fileURLWithPath:[CCUtility getDirectoryProviderStorageFileID:metadata.fileID fileNameView:metadata.fileName]]];
    
    // Error
    if (uploadTask == nil) {
        
        NSString *messageError = @"Serious internal error uploadTask not available";
        [[NCManageDatabase sharedInstance] setMetadataSession:metadata.session sessionError:messageError sessionSelector:nil sessionTaskIdentifier:k_taskIdentifierDone status:k_metadataStatusUploadError predicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID]];
        
        if ([self.delegate respondsToSelector:@selector(uploadFileSuccessFailure:fileID:assetLocalIdentifier:serverUrl:selector:errorMessage:errorCode:)]) {
            [self.delegate uploadFileSuccessFailure:metadata.fileNameView fileID:metadata.fileID assetLocalIdentifier:metadata.assetLocalIdentifier serverUrl:serverUrl selector:metadata.sessionSelector errorMessage:messageError errorCode:k_CCErrorInternalError];
        }
        
    } else {
        
        // E2EE : CREATE AND SEND METADATA
        if ([CCUtility isFolderEncrypted:serverUrl account:_activeAccount] && [CCUtility isEndToEndEnabled:_activeAccount]) {
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                
                // Send Metadata
                NSError *error = [[NCNetworkingEndToEnd sharedManager] sendEndToEndMetadataOnServerUrl:serverUrl fileNameRename:nil fileNameNewRename:nil account:_activeAccount user:_activeUser userID:_activeUserID password:_activePassword url:_activeUrl];
                
                dispatch_async(dispatch_get_main_queue(), ^{

                    if (error) {
                    
                        [uploadTask cancel];

                        NSString *messageError = [NSString stringWithFormat:@"%@ (%d)", error.localizedDescription, (int)error.code];
                        [[NCManageDatabase sharedInstance] setMetadataSession:metadata.session sessionError:messageError sessionSelector:nil sessionTaskIdentifier:k_taskIdentifierDone status:k_metadataStatusUploadError predicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID]];
                        
                        if ([self.delegate respondsToSelector:@selector(uploadFileSuccessFailure:fileID:assetLocalIdentifier:serverUrl:selector:errorMessage:errorCode:)]) {
                            [self.delegate uploadFileSuccessFailure:metadata.fileNameView fileID:metadata.fileID assetLocalIdentifier:metadata.assetLocalIdentifier serverUrl:serverUrl selector:metadata.sessionSelector errorMessage:messageError errorCode:k_CCErrorInternalError];
                        }
                        
                    } else {
                    
                        // Manage uploadTask cancel,suspend,resume
                        if (taskStatus == k_taskStatusCancel) [uploadTask cancel];
                        else if (taskStatus == k_taskStatusSuspend) [uploadTask suspend];
                        else if (taskStatus == k_taskStatusResume) [uploadTask resume];
                        
                        // *** E2EE ***
                        [[NCManageDatabase sharedInstance] setMetadataSession:metadata.session sessionError:@"" sessionSelector:nil sessionTaskIdentifier:uploadTask.taskIdentifier status:k_metadataStatusUploading predicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID]];
                        
                        NSLog(@"[LOG] Upload file %@ TaskIdentifier %lu", metadata.fileName, (unsigned long)uploadTask.taskIdentifier);
                        
                        NSString *fileID = metadata.fileID;
                        NSString *account = metadata.account;
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if ([self.delegate respondsToSelector:@selector(uploadStart:account:task:serverUrl:)]) {
                                [self.delegate uploadStart:fileID account:account task:uploadTask serverUrl:serverUrl];
                            }
                        });
                    }
                });
            });
            
         } else {
    
             // Manage uploadTask cancel,suspend,resume
             if (taskStatus == k_taskStatusCancel) [uploadTask cancel];
             else if (taskStatus == k_taskStatusSuspend) [uploadTask suspend];
             else if (taskStatus == k_taskStatusResume) [uploadTask resume];
             
             // *** PLAIN ***
             [[NCManageDatabase sharedInstance] setMetadataSession:metadata.session sessionError:@"" sessionSelector:nil sessionTaskIdentifier:uploadTask.taskIdentifier status:k_metadataStatusUploading predicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID]];
             
             NSLog(@"[LOG] Upload file %@ TaskIdentifier %lu", metadata.fileName, (unsigned long)uploadTask.taskIdentifier);
             
             NSString *fileID = metadata.fileID;
             NSString *account = metadata.account;
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 if ([self.delegate respondsToSelector:@selector(uploadStart:account:task:serverUrl:)]) {
                     [self.delegate uploadStart:fileID account:account task:uploadTask serverUrl:serverUrl];
                 }
             });
         }
    }
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
    
    if (totalBytesExpectedToSend < 1) {
        totalBytesExpectedToSend = totalBytesSent;
    }
    
    float progress = (float) totalBytesSent / (float)totalBytesExpectedToSend;

    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataInSessionFromFileName:fileName directoryID:directoryID];
    
    if (metadata) {

        NSDictionary* userInfo = @{@"fileID": (metadata.fileID), @"serverUrl": (serverUrl), @"status": ([NSNumber numberWithLong:k_metadataStatusInUpload]), @"progress": ([NSNumber numberWithFloat:progress]), @"totalBytes": ([NSNumber numberWithLongLong:totalBytesSent]), @"totalBytesExpected": ([NSNumber numberWithLongLong:totalBytesExpectedToSend])};
        
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"NotificationProgressTask" object:nil userInfo:userInfo];
    }
}

- (void)uploadFileSuccessFailure:(tableMetadata *)metadata fileName:(NSString *)fileName fileID:(NSString *)fileID etag:(NSString *)etag date:(NSDate *)date serverUrl:(NSString *)serverUrl errorCode:(NSInteger)errorCode
{
    NSString *tempFileID = metadata.fileID;
    NSString *tempSession = metadata.session;
    NSString *errorMessage = @"";
    BOOL isE2EEDirectory = false;
    
    // E2EE Directory ?
    if ([CCUtility isFolderEncrypted:serverUrl account:_activeAccount] && [CCUtility isEndToEndEnabled:_activeAccount]) {
        isE2EEDirectory = true;
    }
    
    // ERRORE
    if (errorCode != 0) {
        
#ifndef EXTENSION
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        [appDelegate.listProgressMetadata removeObjectForKey:metadata.fileID];
#endif
        
        // Mark error only if not Cancelled Task
        if (errorCode == kCFURLErrorCancelled)  {
            
            [[NSFileManager defaultManager] removeItemAtPath:[CCUtility getDirectoryProviderStorageFileID:tempFileID] error:nil];
            [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", tempFileID] clearDateReadDirectoryID:metadata.directoryID];

        } else {

            [[NCManageDatabase sharedInstance] setMetadataSession:nil sessionError:[CCError manageErrorKCF:errorCode withNumberError:NO] sessionSelector:nil sessionTaskIdentifier:k_taskIdentifierDone status:k_metadataStatusUploadError predicate:[NSPredicate predicateWithFormat:@"fileID == %@", tempFileID]];
        }
        
        errorMessage = [CCError manageErrorKCF:errorCode withNumberError:YES];
        
    } else {
            
        // Replace Metadata
        metadata.date = date;
        if (isE2EEDirectory) {
            metadata.e2eEncrypted = true;
        } else {
            metadata.e2eEncrypted = false;
        }
        metadata.etag = etag;
        metadata.fileID = fileID;
        metadata.session = @"";
        metadata.sessionError = @"";
        metadata.sessionTaskIdentifier = k_taskIdentifierDone;
        metadata.status = k_metadataStatusNormal;
        
        metadata = [[NCManageDatabase sharedInstance] addMetadata:metadata];
        
        NSLog(@"[LOG] Insert new upload : %@ - fileID : %@", metadata.fileName, fileID);

        // remove tempFileID and adjust the directory provider storage
        if ([tempFileID isEqualToString:[metadata.directoryID stringByAppendingString:metadata.fileNameView]]) {
            
            [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", tempFileID] clearDateReadDirectoryID:nil];
            
            // adjust file system Directory Provider Storage
            if ([tempSession isEqualToString:k_upload_session_extension]) {
                // this is for File Provider Extension [Apple Works and ... ?]
                [[NSFileManager defaultManager] copyItemAtPath:[NSString stringWithFormat:@"%@/%@", [CCUtility getDirectoryProviderStorage], tempFileID]  toPath:[NSString stringWithFormat:@"%@/%@", [CCUtility getDirectoryProviderStorage], metadata.fileID] error:nil];
            } else {
                [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/%@", [CCUtility getDirectoryProviderStorage], tempFileID] toPath:[NSString stringWithFormat:@"%@/%@", [CCUtility getDirectoryProviderStorage], metadata.fileID] error:nil];
            }
        }
         
#ifndef EXTENSION
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        [appDelegate.listProgressMetadata removeObjectForKey:metadata.fileID];
        
        // Hardcoded for add new photo/video for tab Media view
        NSString *startDirectoryMediaTabView = [[NCManageDatabase sharedInstance] getAccountStartDirectoryMediaTabView:[CCUtility getHomeServerUrlActiveUrl:appDelegate.activeUrl]];
        if ([serverUrl containsString:startDirectoryMediaTabView] && ([metadata.typeFile isEqualToString:k_metadataTypeFile_image] || [metadata.typeFile isEqualToString:k_metadataTypeFile_video])) {
            [appDelegate.activeMedia.addMetadatasFromUpload addObject:metadata];
        }
#endif
        
        // Add Local
        [[NCManageDatabase sharedInstance] addLocalFileWithMetadata:metadata];
        
#ifndef EXTENSION
        
        // EXIF
        if ([metadata.typeFile isEqualToString: k_metadataTypeFile_image])
            [[CCExifGeo sharedInstance] setExifLocalTableEtag:metadata];
        
        // Remove icon B/N
        [[NSFileManager defaultManager] removeItemAtPath:[CCUtility getDirectoryProviderStorageIconFileID:metadata.fileID fileNameView:metadata.fileNameView] error:nil];
        
        // Optimization
        if (([CCUtility getOptimizedPhoto] || [metadata.sessionSelector isEqualToString:selectorUploadAutoUploadAll]) && ([metadata.typeFile isEqualToString:k_metadataTypeFile_image] || [metadata.typeFile isEqualToString:k_metadataTypeFile_video]) && isE2EEDirectory == NO) {
            
            [[NCManageDatabase sharedInstance] deleteLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID]];

            [[NSFileManager defaultManager] removeItemAtPath:[CCUtility getDirectoryProviderStorageFileID:metadata.fileID fileNameView:metadata.fileNameView] error:nil];
        }
        
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
#endif
        
        // Actvity
        [[NCManageDatabase sharedInstance] addActivityClient:metadata.fileNameView fileID:fileID action:k_activityDebugActionUpload selector:metadata.sessionSelector note:serverUrl type:k_activityTypeSuccess verbose:k_activityVerboseDefault activeUrl:_activeUrl];
    }
    
    // E2EE : UNLOCK
    if (isE2EEDirectory) {
        
        tableE2eEncryptionLock *tableLock = [[NCManageDatabase sharedInstance] getE2ETokenLockWithServerUrl:serverUrl];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            if (tableLock) {
                
                NSError *error = [[NCNetworkingEndToEnd sharedManager] unlockEndToEndFolderEncryptedOnServerUrl:serverUrl fileID:tableLock.fileID token:tableLock.token user:_activeUser userID:_activeUserID password:_activePassword url:_activeUrl];
                if (error) {
#ifndef EXTENSION
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [(AppDelegate *)[[UIApplication sharedApplication] delegate] messageNotification:@"_e2e_error_unlock_" description:error.localizedDescription visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:error.code];
                    });
#endif
                }
            } else {
                NSLog(@"Error unlock not found");
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(uploadFileSuccessFailure:fileID:assetLocalIdentifier:serverUrl:selector:errorMessage:errorCode:)]) {
                    [self.delegate uploadFileSuccessFailure:metadata.fileName fileID:metadata.fileID assetLocalIdentifier:metadata.assetLocalIdentifier serverUrl:serverUrl selector:metadata.sessionSelector errorMessage:errorMessage errorCode:errorCode];
                }
            });
        });
    } else {
        
        if ([self.delegate respondsToSelector:@selector(uploadFileSuccessFailure:fileID:assetLocalIdentifier:serverUrl:selector:errorMessage:errorCode:)]) {
            [self.delegate uploadFileSuccessFailure:metadata.fileName fileID:metadata.fileID assetLocalIdentifier:metadata.assetLocalIdentifier serverUrl:serverUrl selector:metadata.sessionSelector errorMessage:errorMessage errorCode:errorCode];
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Utility =====
#pragma --------------------------------------------------------------------------------------------

- (NSString *)getServerUrlFromUrl:(NSString *)url
{
    NSString *fileName = [url lastPathComponent];
    
    url = [url stringByReplacingOccurrencesOfString:[@"/" stringByAppendingString:fileName] withString:@""];

    return url;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== E2EE End To End Encryption =====
#pragma --------------------------------------------------------------------------------------------
// E2EE

- (void)encryptedE2EFile:(tableMetadata *)metadata serverUrl:(NSString *)serverUrl account:(NSString *)account user:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url errorMessage:(NSString * __autoreleasing *)errorMessage fileNameIdentifier:(NSString **)fileNameIdentifier e2eMetadata:(NSString * __autoreleasing *)e2eMetadata
{
    __block NSError *error;
    NSString *key;
    NSString *initializationVector;
    NSString *authenticationTag;
    NSString *metadataKey;
    NSInteger metadataKeyIndex;
    
    // Verify File Size
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[CCUtility getDirectoryProviderStorageFileID:metadata.fileID fileNameView:metadata.fileNameView] error:&error];
    NSNumber *fileSizeNumber = [fileAttributes objectForKey:NSFileSize];
    long long fileSize = [fileSizeNumber longLongValue];
        
    if (fileSize > k_max_filesize_E2E) {
        // Error for uploadFileFailure
        *errorMessage = @"E2E Error file too big";
        return;
    }
        
    // if new file upload [directoryID + fileName] create a new encrypted filename
    if ([metadata.fileID isEqualToString:[metadata.directoryID stringByAppendingString:metadata.fileNameView]]) {
        *fileNameIdentifier = [CCUtility generateRandomIdentifier];
    } else {
        *fileNameIdentifier = metadata.fileName;
    }
   
    // Write to DB
    if ([[NCEndToEndEncryption sharedManager] encryptFileName:metadata.fileNameView fileNameIdentifier:*fileNameIdentifier directory:[CCUtility getDirectoryProviderStorageFileID:metadata.fileID] key:&key initializationVector:&initializationVector authenticationTag:&authenticationTag]) {
        
        tableE2eEncryption *object = [[NCManageDatabase sharedInstance] getE2eEncryptionWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", _activeAccount, serverUrl]];
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
        addObject.fileName = metadata.fileNameView;
        addObject.fileNameIdentifier = *fileNameIdentifier;
        addObject.fileNamePath = [CCUtility returnFileNamePathFromFileName:metadata.fileNameView serverUrl:serverUrl activeUrl:_activeUrl];
        addObject.key = key;
        addObject.initializationVector = initializationVector;
        addObject.metadataKey = metadataKey;
        addObject.metadataKeyIndex = metadataKeyIndex;
        
        CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[metadata.fileNameView pathExtension], NULL);
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
        tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", account, serverUrl]];

        error = [[NCNetworkingEndToEnd sharedManager] getEndToEndMetadata:&metadata fileID:directory.fileID user:user userID:userID password:password url:url];
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
    [metadataNet setContentType: self.contentType];
    [metadataNet setDate: self.date];
    [metadataNet setDelegate: self.delegate];
    [metadataNet setDepth: self.depth];
    [metadataNet setDirectory: self.directory];
    [metadataNet setDirectoryID: self.directoryID];
    [metadataNet setDirectoryIDTo: self.directoryIDTo];
    [metadataNet setEncryptedMetadata: self.encryptedMetadata];
    [metadataNet setEtag:self.etag];
    [metadataNet setExpirationTime: self.expirationTime];
    [metadataNet setFileID: self.fileID];
    [metadataNet setFileName: self.fileName];
    [metadataNet setFileNameTo: self.fileNameTo];
    [metadataNet setFileNameView: self.fileNameView];
    [metadataNet setKey: self.key];
    [metadataNet setKeyCipher: self.keyCipher];
    [metadataNet setOptionAny: self.optionAny];
    [metadataNet setOptionString: self.optionString];
    [metadataNet setPassword: self.password];
    [metadataNet setPriority: self.priority];
    [metadataNet setServerUrl: self.serverUrl];
    [metadataNet setServerUrlTo: self.serverUrlTo];
    [metadataNet setSelector: self.selector];
    [metadataNet setShare: self.share];
    [metadataNet setShareeType: self.shareeType];
    [metadataNet setSharePermission: self.sharePermission];
    [metadataNet setSize: self.size];
    
    return metadataNet;
}

@end
