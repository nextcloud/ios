//
//  CCNetworking.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 01/06/15.
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

#import "CCNetworking.h"

#import "AppDelegate.h"
#import "CCCertificate.h"
#import "TableAccount.h"

#import "NSDate+ISO8601.h"

@interface CCNetworking ()
{
    NSManagedObjectContext *_context;
    NSMutableDictionary *_taskData;
    CCMetadata *_currentProgressMetadata;
    
    NSString *_activeAccount;
    NSString *_activePassword;
    NSString *_activeUID;
    NSString *_activeAccessToken;
    NSString *_activeUser;
    NSString *_activeUrl;
    NSString *_directoryUser;
    NSString *_typeCloud;
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
    
    _context = [NSManagedObjectContext MR_context];
   
    _taskData = [[NSMutableDictionary alloc] init];
    _currentProgressMetadata = [[CCMetadata alloc] init];
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

- (void)settingDelegate:(id <CCNetworkingDelegate>)delegate
{
    _delegate = delegate;
}

- (void)settingAccount
{
    TableAccount *tableAccount = [CCCoreData getActiveAccount];
    
    _activeAccount = tableAccount.account;
    _activePassword = tableAccount.password;
    _activeUID = tableAccount.uid;
    _activeAccessToken = tableAccount.token;
    _activeUser = tableAccount.user;
    _activeUrl = tableAccount.url;
    _directoryUser = [CCUtility getDirectoryActiveUser:_activeUser activeUrl:_activeUrl];
    _typeCloud = tableAccount.typeCloud;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Session =====
#pragma --------------------------------------------------------------------------------------------

- (NSURLSession *)sessionDownload
{
    static NSURLSession *sessionDownload = nil;
    
    if (sessionDownload == nil) {
        
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:download_session];
        
        configuration.allowsCellularAccess = YES;
        configuration.sessionSendsLaunchEvents = YES;
        configuration.discretionary = NO;
        configuration.HTTPMaximumConnectionsPerHost = 1;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        
        sessionDownload = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
        sessionDownload.sessionDescription = download_session;
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
        sessionDownloadForeground.sessionDescription = download_session_foreground;
    }
    return sessionDownloadForeground;
}

- (NSURLSession *)sessionWWanDownload
{
    static NSURLSession *sessionWWanDownload = nil;
    
    if (sessionWWanDownload == nil) {
        
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:download_session_wwan];
        
        configuration.allowsCellularAccess = NO;
        configuration.sessionSendsLaunchEvents = YES;
        configuration.discretionary = NO;
        configuration.HTTPMaximumConnectionsPerHost = 1;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        
        sessionWWanDownload = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
        sessionWWanDownload.sessionDescription = download_session_wwan;
    }
    return sessionWWanDownload;
}

- (NSURLSession *)sessionUpload
{
    static NSURLSession *sessionUpload = nil;
    
    if (sessionUpload == nil) {
        
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:upload_session];
        
        configuration.allowsCellularAccess = YES;
        configuration.sessionSendsLaunchEvents = YES;
        configuration.discretionary = NO;
        configuration.HTTPMaximumConnectionsPerHost = 1;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        
        sessionUpload = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
        sessionUpload.sessionDescription = upload_session;
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
        sessionUploadForeground.sessionDescription = upload_session_foreground;
    }
    return sessionUploadForeground;
}

- (NSURLSession *)sessionWWanUpload
{
    static NSURLSession *sessionWWanUpload = nil;
    
    if (sessionWWanUpload == nil) {
        
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:upload_session_wwan];
        
        configuration.allowsCellularAccess = NO;
        configuration.sessionSendsLaunchEvents = YES;
        configuration.discretionary = NO;
        configuration.HTTPMaximumConnectionsPerHost = 1;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        
        sessionWWanUpload = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
        sessionWWanUpload.sessionDescription = upload_session_wwan;
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
        configuration.HTTPMaximumConnectionsPerHost = maxConcurrentOperation;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        
        OCURLSessionManager *networkSessionManager = [[OCURLSessionManager alloc] initWithSessionConfiguration:configuration];
        [networkSessionManager.operationQueue setMaxConcurrentOperationCount:maxConcurrentOperation];
        networkSessionManager.responseSerializer = [AFHTTPResponseSerializer serializer];
        
        sharedOCCommunication = [[OCCommunication alloc] initWithUploadSessionManager:nil andDownloadSessionManager:nil andNetworkSessionManager:networkSessionManager];
    }
    
    return sharedOCCommunication;
}

- (NSURLSession *)getSessionfromSessionDescription:(NSString *)sessionDescription
{
    if ([sessionDescription isEqualToString:download_session]) return [self sessionDownload];
    if ([sessionDescription isEqualToString:download_session_foreground]) return [self sessionDownloadForeground];
    if ([sessionDescription isEqualToString:download_session_wwan]) return [self sessionWWanDownload];
    
    if ([sessionDescription isEqualToString:upload_session]) return [self sessionUpload];
    if ([sessionDescription isEqualToString:upload_session_foreground]) return [self sessionUploadForeground];
    if ([sessionDescription isEqualToString:upload_session_wwan]) return [self sessionWWanUpload];
    
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
                if (taskStatus == taskStatusCancel) [task cancel];
                else if (taskStatus == taskStatusSuspend) [task suspend];
                else if (taskStatus == taskStatusResume) [task resume];
        }];
        
        [[self sessionDownloadForeground] getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            for (NSURLSessionTask *task in downloadTasks)
                if (taskStatus == taskStatusCancel) [task cancel];
                else if (taskStatus == taskStatusSuspend) [task suspend];
                else if (taskStatus == taskStatusResume) [task resume];
        }];
        
        [[self sessionWWanDownload] getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            for (NSURLSessionTask *task in downloadTasks)
                if (taskStatus == taskStatusCancel) [task cancel];
                else if (taskStatus == taskStatusSuspend) [task suspend];
                else if (taskStatus == taskStatusResume) [task resume];
        }];
    }
        
    if (upload) {
        
        [[self sessionUpload] getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            for (NSURLSessionTask *task in uploadTasks)
                if (taskStatus == taskStatusCancel) [task cancel];
                else if (taskStatus == taskStatusSuspend) [task suspend];
                else if (taskStatus == taskStatusResume) [task resume];
        }];
        
        [[self sessionUploadForeground] getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            for (NSURLSessionTask *task in uploadTasks)
                if (taskStatus == taskStatusCancel) [task cancel];
                else if (taskStatus == taskStatusSuspend) [task suspend];
                else if (taskStatus == taskStatusResume) [task resume];
        }];
        
        [[self sessionWWanUpload] getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            for (NSURLSessionTask *task in uploadTasks)
                if (taskStatus == taskStatusCancel) [task cancel];
                else if (taskStatus == taskStatusSuspend) [task suspend];
                else if (taskStatus == taskStatusResume) [task resume];
        }];
    }

    // COREDATA FILE SYSTEM
    
    if (download && taskStatus == taskStatusCancel) {
        [CCCoreData setMetadataSession:@"" sessionError:@"" sessionSelector:@"" sessionSelectorPost:@"" sessionTaskIdentifier:taskIdentifierDone sessionTaskIdentifierPlist:taskIdentifierDone predicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (session CONTAINS 'download')", _activeAccount] context:_context];
    }
    
    if (upload && taskStatus == taskStatusCancel) {
        [CCCoreData deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(session CONTAINS 'upload')"]];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [CCUtility removeAllFileID_UPLOAD_ActiveUser:activeUser activeUrl:activeUrl];
        });
    }

#ifndef EXTENSION
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
        [app updateApplicationIconBadgeNumber];
    });
#endif
}

- (void)settingSession:(NSString *)sessionDescription sessionTaskIdentifier:(NSUInteger)sessionTaskIdentifier taskStatus:(NSInteger)taskStatus
{
    NSURLSession *session = [self getSessionfromSessionDescription:sessionDescription];
    
    [session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        
        if ([sessionDescription containsString:@"download"])
            for (NSURLSessionTask *task in downloadTasks)
                if (task.taskIdentifier == sessionTaskIdentifier) {
                    if (taskStatus == taskStatusCancel) [task cancel];
                    else if (taskStatus == taskStatusSuspend) [task suspend];
                    else if (taskStatus == taskStatusResume) [task resume];
                }
        if ([sessionDescription containsString:@"upload"])
            for (NSURLSessionTask *task in uploadTasks)
                if (task.taskIdentifier == sessionTaskIdentifier) {
                    if (taskStatus == taskStatusCancel) [task cancel];
                    else if (taskStatus == taskStatusSuspend) [task suspend];
                    else if (taskStatus == taskStatusResume) [task resume];
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
    NSString *url = [[[task currentRequest].URL absoluteString] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *fileName = [url lastPathComponent];
    NSString *serverUrl = [self getServerUrlFromUrl:url];
    
    CCMetadata *metadata = [CCCoreData getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(session = %@) AND ((sessionTaskIdentifier == %i) OR (sessionTaskIdentifierPlist == %i))",session.sessionDescription, task.taskIdentifier, task.taskIdentifier] context:_context];
    
    NSInteger errorCode;
    NSString *fileID = metadata.fileID;
    NSString *rev = metadata.rev;
    
    NSDate *date = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"EEE, dd MMM y HH:mm:ss zzz"];

    // remove Current Progress Metadata
    _currentProgressMetadata = nil;
    
    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)task.response;
    
    if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        
        errorCode = error.code;
        
    } else {
        
        if (httpResponse.statusCode > 0)
            errorCode = httpResponse.statusCode;
        else
            errorCode = error.code;
        
        // Request trusted certificated
        if (errorCode == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:(UIViewController *)self.delegate delegate:self];
    }

    // ----------------------- DOWNLOAD -----------------------
    
    if ([task isKindOfClass:[NSURLSessionDownloadTask class]]) {
        
        if ([_typeCloud isEqualToString:typeCloudOwnCloud] || [_typeCloud isEqualToString:typeCloudNextcloud]) {
            
            NSDictionary *fields = [httpResponse allHeaderFields];
            
            if (errorCode == 0) {
                rev = [CCUtility removeForbiddenCharacters:[fields objectForKey:@"OC-ETag"] hasServerForbiddenCharactersSupport:NO];
                date = [dateFormatter dateFromString:[fields objectForKey:@"Date"]];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
        
            // Notification change session
            NSArray *object = [[NSArray alloc] initWithObjects:session, metadata, task, nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:networkingSessionNotification object:object];
        
            [self downloadFileSuccessFailure:fileName fileID:metadata.fileID rev:rev date:date serverUrl:serverUrl selector:metadata.sessionSelector selectorPost:metadata.sessionSelectorPost errorCode:errorCode];
        });
    }
    
    // ------------------------ UPLOAD -----------------------
    
    if ([task isKindOfClass:[NSURLSessionUploadTask class]]) {
        
        if ([_typeCloud isEqualToString:typeCloudOwnCloud] || [_typeCloud isEqualToString:typeCloudNextcloud]) {
            
            NSDictionary *fields = [httpResponse allHeaderFields];
            
            if (errorCode == 0) {
                fileID = [CCUtility removeForbiddenCharacters:[fields objectForKey:@"OC-FileId"] hasServerForbiddenCharactersSupport:NO];
                rev = [CCUtility removeForbiddenCharacters:[fields objectForKey:@"OC-ETag"] hasServerForbiddenCharactersSupport:NO];
                date = [dateFormatter dateFromString:[fields objectForKey:@"Date"]];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            // Notification change session
            NSArray *object = [[NSArray alloc] initWithObjects:session, metadata, task, nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:networkingSessionNotification object:object];
            
            [self uploadFileSuccessFailure:metadata fileName:fileName fileID:fileID rev:rev date:date serverUrl:serverUrl errorCode:errorCode];
        });
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Download =====
#pragma --------------------------------------------------------------------------------------------

- (void)downloadFile:(CCMetadata *)metadata serverUrl:(NSString *)serverUrl downloadData:(BOOL)downloadData downloadPlist:(BOOL)downloadPlist selector:(NSString *)selector selectorPost:(NSString *)selectorPost session:(NSString *)session taskStatus:(NSInteger)taskStatus delegate:(id)delegate
{
    // add delegate
    if (delegate)
        [_delegates setObject:delegate forKey:metadata.fileID];
    
    if (downloadData) {
        
        // it's in download
        if ([CCCoreData getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(account == %@) AND (fileID == %@) AND (session CONTAINS 'download') AND (sessionTaskIdentifier >= 0)", _activeAccount, metadata.fileID] context:_context]) {
            
            NSLog(@"[LOG] Download file already in progress %@ - %@", metadata.fileNameData, metadata.fileNamePrint);
            
            return;
        }
        
        // if not a reload, exists ?
        if ([selector isEqualToString:selectorReload] == NO) {
            
            if ([CCCoreData getLocalFileWithFileID:metadata.fileID activeAccount:_activeAccount] && [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, metadata.fileID]]) {
                
                NSLog(@"[LOG] Download file already exists %@ - %@", metadata.fileNameData, metadata.fileNamePrint);
                
                [CCCoreData setMetadataSession:@"" sessionError:@"" sessionSelector:@"" sessionSelectorPost:@"" sessionTaskIdentifier:taskIdentifierDone sessionTaskIdentifierPlist:taskIdentifierDone predicate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", metadata.fileID, _activeAccount] context:_context];
                
                if ([[self getDelegate:metadata.fileID] respondsToSelector:@selector(downloadFileSuccess:serverUrl:selector:selectorPost:)])
                    [[self getDelegate:metadata.fileID] downloadFileSuccess:metadata.fileID serverUrl:serverUrl selector:selector selectorPost:selectorPost];

                return;
            }
        }
        
        // select type of session
        metadata.session = session;
        
        [self downloaURLSession:metadata.fileNameData fileNamePrint:metadata.fileNamePrint serverUrl:serverUrl fileID:metadata.fileID session:metadata.session taskStatus:taskStatus selector:selector];
        
        [CCCoreData setMetadataSession:metadata.session sessionError:@"" sessionSelector:selector sessionSelectorPost:selectorPost sessionTaskIdentifier:taskIdentifierNULL sessionTaskIdentifierPlist:taskIdentifierNULL predicate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)",metadata.fileID, _activeAccount] context:_context];
    }
    
    if (downloadPlist) {
        
        // it's in download
        if ([CCCoreData getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(account == %@) AND (fileID == %@) AND (session CONTAINS 'download') AND (sessionTaskIdentifierPlist >= 0)", _activeAccount, metadata.fileID] context:_context]) {
            
            NSLog(@"[LOG] Download file already in progress %@ - %@", metadata.fileName, metadata.fileNamePrint);
            
            return;
        }
        
        // select tye of session
        metadata.session = session;
        
        [self downloaURLSession:metadata.fileName fileNamePrint:metadata.fileNamePrint serverUrl:serverUrl fileID:metadata.fileID session:metadata.session taskStatus:taskStatus selector:selector];
        
        [CCCoreData setMetadataSession:metadata.session sessionError:@"" sessionSelector:selector sessionSelectorPost:selectorPost sessionTaskIdentifier:taskIdentifierNULL sessionTaskIdentifierPlist:taskIdentifierNULL predicate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)",metadata.fileID, _activeAccount] context:_context];
    }
}

- (void)downloaURLSession:(NSString *)fileName fileNamePrint:(NSString *)fileNamePrint serverUrl:(NSString *)serverUrl fileID:(NSString *)fileID session:(NSString *)session taskStatus:(NSInteger)taskStatus selector:(NSString *)selector
{
    NSURLSession *sessionDownload;
    NSURL *url;
    NSMutableURLRequest *request;
    
    if ([_typeCloud isEqualToString:typeCloudNextcloud] || [_typeCloud isEqualToString:typeCloudOwnCloud]) {
        
        NSString *serverFileUrl = [[NSString stringWithFormat:@"%@/%@", serverUrl, fileName] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        url = [NSURL URLWithString:serverFileUrl];
        request = [NSMutableURLRequest requestWithURL:url];
        
        NSData *authData = [[NSString stringWithFormat:@"%@:%@", _activeUser, _activePassword] dataUsingEncoding:NSUTF8StringEncoding];
        NSString *authValue = [NSString stringWithFormat: @"Basic %@",[authData base64EncodedStringWithOptions:0]];
        [request setValue:authValue forHTTPHeaderField:@"Authorization"];
    }
    
    if ([session isEqualToString:download_session]) sessionDownload = [self sessionDownload];
    else if ([session isEqualToString:download_session_foreground]) sessionDownload = [self sessionDownloadForeground];
    else if ([session isEqualToString:download_session_wwan]) sessionDownload = [self sessionWWanDownload];
    
    NSURLSessionDownloadTask *downloadTask = [sessionDownload downloadTaskWithRequest:request];
    
    if (taskStatus == taskStatusCancel) [downloadTask cancel];
    else if (taskStatus == taskStatusSuspend) [downloadTask suspend];
    else if (taskStatus == taskStatusResume) [downloadTask resume];

    if ([[self getDelegate:fileID] respondsToSelector:@selector(downloadTaskSave:)])
        [[self getDelegate:fileID] downloadTaskSave:downloadTask];
    
    if (downloadTask == nil) {
        
        NSUInteger sessionTaskIdentifier = taskIdentifierNULL;
        NSUInteger sessionTaskIdentifierPlist = taskIdentifierNULL;
        
        if ([CCUtility isFileNotCryptated:fileName] || [CCUtility isCryptoString:fileName]) sessionTaskIdentifier = taskIdentifierError;
        if ([CCUtility isCryptoPlistString:fileName]) sessionTaskIdentifierPlist = taskIdentifierError;
        
        [CCCoreData setMetadataSession:nil sessionError:[NSString stringWithFormat:@"%@", @CCErrorTaskNil] sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:sessionTaskIdentifier sessionTaskIdentifierPlist:sessionTaskIdentifierPlist predicate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", fileID, _activeAccount] context:_context];
        
        NSLog(@"[LOG] downloadFileSession TaskIdentifier [error CCErrorTaskNil] - %@ - %@", fileName, fileNamePrint);
        
    } else {
        
        NSUInteger sessionTaskIdentifier = taskIdentifierNULL;
        NSUInteger sessionTaskIdentifierPlist = taskIdentifierNULL;
        
        if ([CCUtility isCryptoString:fileName] || [CCUtility isFileNotCryptated:fileName]) sessionTaskIdentifier = downloadTask.taskIdentifier;
        if ([CCUtility isCryptoPlistString:fileName]) sessionTaskIdentifierPlist = downloadTask.taskIdentifier;
        
        [CCCoreData setMetadataSession:nil sessionError:@"" sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:sessionTaskIdentifier sessionTaskIdentifierPlist:sessionTaskIdentifierPlist predicate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", fileID, _activeAccount] context:_context];
        
        NSLog(@"[LOG] downloadFileSession %@ - %@ Task [%lu %lu]", fileID, fileNamePrint, (unsigned long)sessionTaskIdentifier, (unsigned long)sessionTaskIdentifierPlist);
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
    
        // Refresh datasource if is not a Plist
        NSString *directoryID = [CCCoreData getDirectoryIDFromServerUrl:serverUrl activeAccount:_activeAccount];
        
        if ([_delegate respondsToSelector:@selector(getDataSourceWithReloadTableView:fileID:selector:)] && [CCUtility isCryptoPlistString:fileName] == NO)
            [_delegate getDataSourceWithReloadTableView:directoryID fileID:fileID selector:selector];
    });
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    NSString *url = [[[downloadTask currentRequest].URL absoluteString] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *fileName = [url lastPathComponent];
    NSString *serverUrl = [self getServerUrlFromUrl:url];
    
    // if plist return
    if ([CCUtility getTypeFileName:fileName] == metadataTypeFilenamePlist)
        return;

    float progress = (float) totalBytesWritten / (float)totalBytesExpectedToWrite;
    
    if ([_currentProgressMetadata.fileName isEqualToString:fileName] == NO && [_currentProgressMetadata.fileNameData isEqualToString:fileName] == NO)
        _currentProgressMetadata = [CCCoreData getMetadataFromFileName:fileName directoryID:[CCCoreData getDirectoryIDFromServerUrl:serverUrl activeAccount:_activeAccount] activeAccount:_activeAccount context:_context];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if (_currentProgressMetadata) {
 
#ifndef EXTENSION
            // Control Center
            [app.controlCenter progressTask:_currentProgressMetadata.fileID serverUrl:serverUrl cryptated:_currentProgressMetadata.cryptated progress:progress];
        
            // Detail
            if (app.activeDetail)
                [app.activeDetail progressTask:_currentProgressMetadata.fileID serverUrl:serverUrl cryptated:_currentProgressMetadata.cryptated progress:progress];
#endif
            if ([self.delegate respondsToSelector:@selector(progressTask:serverUrl:cryptated:progress:)])
                [self.delegate progressTask:_currentProgressMetadata.fileID serverUrl:serverUrl cryptated:_currentProgressMetadata.cryptated progress:progress];
        }
    });
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    NSURLRequest *url = [downloadTask currentRequest];
    NSString *filename = [[url.URL absoluteString] lastPathComponent];
    
    CCMetadata *metadata = metadata = [CCCoreData getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(session = %@) AND ((sessionTaskIdentifier == %i) OR (sessionTaskIdentifierPlist == %i))",session.sessionDescription, downloadTask.taskIdentifier, downloadTask.taskIdentifier] context:_context];
    
    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)downloadTask.response;
    
    if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        
        NSString *destinationFilePath;
        
        if ([CCUtility isCryptoPlistString:filename]) {
            
            destinationFilePath = [NSString stringWithFormat:@"%@/%@", [CCUtility getDirectoryActiveUser:_activeUser activeUrl:_activeUrl], filename];
            
        } else {
            
            if (metadata.cryptated) destinationFilePath = [NSString stringWithFormat:@"%@/%@.crypt", [CCUtility getDirectoryActiveUser:_activeUser activeUrl:_activeUrl], metadata.fileID];
            else destinationFilePath = [NSString stringWithFormat:@"%@/%@", [CCUtility getDirectoryActiveUser:_activeUser activeUrl:_activeUrl], metadata.fileID];
        }
        
        NSURL *destinationURL = [NSURL fileURLWithPath:destinationFilePath];
        
        [[NSFileManager defaultManager] removeItemAtURL:destinationURL error:NULL];
        [[NSFileManager defaultManager] copyItemAtURL:location toURL:destinationURL error:nil];
    }
}

- (void)downloadFileSuccessFailure:(NSString *)fileName fileID:(NSString *)fileID rev:(NSString *)rev date:(NSDate *)date serverUrl:(NSString *)serverUrl selector:(NSString *)selector selectorPost:(NSString *)selectorPost errorCode:(NSInteger)errorCode
{
#ifndef EXTENSION
    if (fileID)
        [app.listProgressMetadata removeObjectForKey:fileID];
#endif
    
    if (errorCode != 0) {
        
        //
        // if cancel or was a xxxxxx.plist delete session
        //
        if (errorCode == kCFURLErrorCancelled || [CCUtility isCryptoPlistString:fileName]) {
            
            [CCCoreData setMetadataSession:@"" sessionError:@"" sessionSelector:@"" sessionSelectorPost:@"" sessionTaskIdentifier:taskIdentifierDone sessionTaskIdentifierPlist:taskIdentifierDone predicate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", fileID, _activeAccount] context:_context];
            
        } else {
            
            [CCCoreData setMetadataSession:nil sessionError:[NSString stringWithFormat:@"%@", @(errorCode)] sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:taskIdentifierError sessionTaskIdentifierPlist:taskIdentifierNULL predicate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", fileID, _activeAccount] context:_context];
        }
        
        // Delegate downloadFileFailure:
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if ([[self getDelegate:fileID] respondsToSelector:@selector(downloadFileFailure:serverUrl:selector:message:errorCode:)])
                [[self getDelegate:fileID] downloadFileFailure:fileID serverUrl:serverUrl selector:selector message:[CCError manageErrorKCF:errorCode withNumberError:YES] errorCode:errorCode];
        });
        
        NSLog(@"[LOG] Download Failure Session Filename : %@ ERROR : %@", fileName, [NSString stringWithFormat:@"%@", @(errorCode)]);
        
    } else {
        
        CCMetadata *metadata = [CCCoreData getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", fileID, _activeAccount] context:_context];
        
        if ([CCUtility isCryptoString:fileName] || [CCUtility isFileNotCryptated:fileName]) metadata.sessionTaskIdentifier = taskIdentifierDone;
        if ([CCUtility isCryptoPlistString:fileName]) metadata.sessionTaskIdentifierPlist = taskIdentifierDone;
        
        if (metadata.sessionTaskIdentifier == taskIdentifierDone && metadata.sessionTaskIdentifierPlist == taskIdentifierDone) {
            
            [CCCoreData setMetadataSession:@"" sessionError:@"" sessionSelector:@"" sessionSelectorPost:@"" sessionTaskIdentifier:metadata.sessionTaskIdentifier sessionTaskIdentifierPlist:metadata.sessionTaskIdentifierPlist predicate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", fileID, _activeAccount] context:_context];
            
        } else {
            
            [CCCoreData setMetadataSession:nil sessionError:nil sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:metadata.sessionTaskIdentifier sessionTaskIdentifierPlist:metadata.sessionTaskIdentifierPlist predicate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", fileID, _activeAccount] context:_context];
        }
        
        // DATA
        if ([CCUtility isCryptoString:fileName] || [CCUtility isFileNotCryptated:fileName]) {
            
            [CCCoreData downloadFile:metadata directoryUser:_directoryUser activeAccount:_activeAccount];
        }
        
        // download File Success
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if ([[self getDelegate:fileID] respondsToSelector:@selector(downloadFileSuccess:serverUrl:selector:selectorPost:)])
                [[self getDelegate:fileID] downloadFileSuccess:fileID serverUrl:serverUrl selector:selector selectorPost:selectorPost];
        });
        
        NSLog(@"[LOG] Download Success Session Metadata : %@ - FileNamePrint : %@ - fileID : %@ - Task : [%i %i]", metadata.fileName, metadata.fileNamePrint, metadata.fileID, metadata.sessionTaskIdentifier, metadata.sessionTaskIdentifierPlist);
    }    
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Upload =====
#pragma --------------------------------------------------------------------------------------------

- (void)uploadFileFromAssetLocalIdentifier:(NSString *)localIdentifier fileName:(NSString *)fileName serverUrl:(NSString *)serverUrl cryptated:(BOOL)cryptated session:(NSString *)session taskStatus:(NSInteger)taskStatus selector:(NSString *)selector selectorPost:(NSString *)selectorPost parentRev:(NSString *)parentRev errorCode:(NSInteger)errorCode delegate:(id)delegate
{
    PHFetchResult *result = [PHAsset fetchAssetsWithLocalIdentifiers:@[localIdentifier] options:nil];
    
    if (!result.count) {
        
        if ([delegate respondsToSelector:@selector(uploadFileFailure:serverUrl:selector:message:errorCode:)])
            [delegate uploadFileFailure:nil serverUrl:serverUrl selector:selector message:@"Internal error" errorCode:CCErrorInternalError];
        return;
    }
    
    PHAsset *asset = result[0];
    PHAssetMediaType assetMediaType = asset.mediaType;
    NSDate *assetDate = asset.creationDate;
    __block NSError *error = nil;
    
    // create fileName
    NSString *assetFileName = [asset valueForKey:@"filename"];
    NSString *fileNamePath = [NSString stringWithFormat:@"%@/%@", _directoryUser, fileName];
    
    //delegate
    if (delegate == nil)
        delegate = self.delegate;
    
    // VIDEO
    if (assetMediaType == PHAssetMediaTypeVideo) {
        
        // Automatic Upload video encrypted ?
        if ([selector isEqualToString:selectorUploadAutomatic] || [selector isEqualToString:selectorUploadAutomaticAll])
            cryptated = [CCCoreData getCameraUploadCryptatedVideoActiveAccount:_activeAccount];
        
        @autoreleasepool {
            
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            
            PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
            options.version = PHVideoRequestOptionsVersionOriginal;
        
            [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:options resultHandler:^(AVAsset *asset, AVAudioMix *audioMix, NSDictionary *info) {
            
                if ([asset isKindOfClass:[AVURLAsset class]]) {

                    NSData *data = [[NSData alloc] initWithContentsOfURL:[(AVURLAsset *)asset URL] options:0 error:&error];
                
                    if (!error || [data length] > 0) {
                        
                        [data writeToFile:fileNamePath options:NSDataWritingAtomic error:&error];
                        
                    } else {
                        
                        if (!error)
                            error = [NSError errorWithDomain:@"it.twsweb.cryptocloud" code:kCFURLErrorFileDoesNotExist userInfo:nil];
                    }
                    
                } else {
                    
                    error = [NSError errorWithDomain:@"it.twsweb.cryptocloud" code:kCFURLErrorFileDoesNotExist userInfo:nil];
                }
                    
                dispatch_semaphore_signal(semaphore);
            }];
            
            while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        }
    }
    
    // IMAGE
    if (assetMediaType == PHAssetMediaTypeImage) {
    
        // Automatic Upload photo encrypted ?
        if ([selector isEqualToString:selectorUploadAutomatic] || [selector isEqualToString:selectorUploadAutomaticAll])
            cryptated = [CCCoreData getCameraUploadCryptatedPhotoActiveAccount:_activeAccount];

        @autoreleasepool {
            
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            
            [[PHImageManager defaultManager] requestImageDataForAsset:asset options:nil resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
            
                [imageData writeToFile:fileNamePath options:NSDataWritingAtomic error:&error];
                
                dispatch_semaphore_signal(semaphore);
            }];
            
            while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];

        }
    }
    
    if (error) {
        
        // Error for uploadFileFailure
        if ([delegate respondsToSelector:@selector(uploadFileFailure:serverUrl:selector:message:errorCode:)])
            [delegate uploadFileFailure:nil serverUrl:serverUrl selector:selector message:@"_read_file_error_" errorCode:error.code];
        
    } else {
        
        [self upload:fileName serverUrl:serverUrl cryptated:cryptated template:NO onlyPlist:NO assetFileName:assetFileName assetDate:assetDate assetMediaType:assetMediaType localIdentifier:localIdentifier session:session taskStatus:taskStatus selector:selector selectorPost:selectorPost parentRev:parentRev errorCode:errorCode delegate:delegate];
    }
}

- (void)uploadFile:(NSString *)fileName serverUrl:(NSString *)serverUrl cryptated:(BOOL)cryptated onlyPlist:(BOOL)onlyPlist session:(NSString *)session taskStatus:(NSInteger)taskStatus selector:(NSString *)selector selectorPost:(NSString *)selectorPost parentRev:(NSString *)parentRev errorCode:(NSInteger)errorCode delegate:(id)delegate
{
    [self upload:fileName serverUrl:serverUrl cryptated:cryptated template:NO onlyPlist:onlyPlist assetFileName:nil assetDate:nil assetMediaType:PHAssetMediaTypeUnknown localIdentifier:nil session:session taskStatus:taskStatus selector:selector selectorPost:selectorPost parentRev:parentRev errorCode:errorCode delegate:delegate];
}

- (void)uploadTemplate:(NSString *)fileNamePrint fileNameCrypto:(NSString *)fileNameCrypto serverUrl:(NSString *)serverUrl session:(NSString *)session taskStatus:(NSInteger)taskStatus selector:(NSString *)selector selectorPost:(NSString *)selectorPost parentRev:(NSString *)parentRev errorCode:(NSInteger)errorCode delegate:(id)delegate
{
    [self upload:fileNameCrypto serverUrl:serverUrl cryptated:YES template:YES onlyPlist:NO assetFileName:fileNamePrint assetDate:nil assetMediaType:PHAssetMediaTypeUnknown localIdentifier:nil session:session taskStatus:taskStatus selector:selector selectorPost:selectorPost parentRev:parentRev errorCode:errorCode delegate:delegate];
}

- (void)upload:(NSString *)fileName serverUrl:(NSString *)serverUrl cryptated:(BOOL)cryptated template:(BOOL)template onlyPlist:(BOOL)onlyPlist assetFileName:(NSString *)assetFileName assetDate:(NSDate *)assetDate assetMediaType:(PHAssetMediaType)assetMediaType localIdentifier:(NSString *)localIdentifier session:(NSString *)session taskStatus:(NSInteger)taskStatus selector:(NSString *)selector selectorPost:(NSString *)selectorPost parentRev:(NSString *)parentRev errorCode:(NSInteger)errorCode delegate:(id)delegate
{
    NSString *directoryID = [CCCoreData getDirectoryIDFromServerUrl:serverUrl activeAccount:_activeAccount];
    NSString *fileNameCrypto;
    CCCrypto *crypto = [[CCCrypto alloc] init];
    
    // create Metadata
    NSString *cameraFolderName = [CCCoreData getCameraUploadFolderNameActiveAccount:_activeAccount];
    NSString *cameraFolderPath = [CCCoreData getCameraUploadFolderPathActiveAccount:_activeAccount activeUrl:_activeUrl typeCloud:_typeCloud];
    
    CCMetadata *metadata = [CCUtility insertFileSystemInMetadata:fileName directory:_directoryUser activeAccount:_activeAccount cameraFolderName:cameraFolderName cameraFolderPath:cameraFolderPath];
    
    //fileID
    NSString *uploadID =  [uploadSessionID stringByAppendingString:[CCUtility createID]];
    
    //add delegate
    if (delegate)
        [_delegates setObject:delegate forKey:uploadID];
    
    if (onlyPlist == YES) {
    
        [CCUtility moveFileAtPath:[NSTemporaryDirectory() stringByAppendingString:fileName] toPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, fileName]];
        
        [CCUtility insertInformationPlist:metadata directoryUser:_directoryUser];
        
        metadata.date = [NSDate new];
        metadata.fileID = uploadID;
        metadata.directoryID = directoryID;
        metadata.fileNameData = [CCUtility trasformedFileNamePlistInCrypto:fileName];
        metadata.localIdentifier = localIdentifier;
        metadata.session = session;
        metadata.sessionID = uploadID;
        metadata.sessionSelector = selector;
        metadata.sessionSelectorPost = selectorPost;
        metadata.typeCloud = _typeCloud;
        metadata.typeFile = metadataTypeFile_unknown;
        
        [CCCoreData addMetadata:metadata activeAccount:_activeAccount activeUrl:_activeUrl typeCloud:_typeCloud context:_context];
        
        [self uploadURLSession:fileName fileNamePrint:metadata.fileNamePrint serverUrl:serverUrl directoryID:metadata.directoryID sessionID:uploadID session:metadata.session taskStatus:taskStatus assetDate:assetDate assetMediaType:assetMediaType cryptated:cryptated onlyPlist:onlyPlist parentRev:parentRev selector:selector];
    }
    
    else if (cryptated == YES) {
        
        if (template == YES) {
        
            // copy from temp to directory user
            [CCUtility moveFileAtPath:[NSTemporaryDirectory() stringByAppendingString:fileName] toPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, fileName]];
            [CCUtility moveFileAtPath:[NSTemporaryDirectory() stringByAppendingString:[fileName stringByAppendingString:@".plist"]] toPath:[NSString stringWithFormat:@"%@/%@.plist", _directoryUser, fileName]];
            
            fileNameCrypto = fileName;  // file Name Crypto
            fileName = assetFileName;   // file Name Print
            
            [CCUtility insertInformationPlist:metadata directoryUser:_directoryUser];
            
            metadata.date = [NSDate new];
            metadata.fileID = uploadID;
            metadata.directoryID = directoryID;
            metadata.fileName = [fileNameCrypto stringByAppendingString:@".plist"];
            metadata.fileNameData = fileNameCrypto;
            metadata.localIdentifier = localIdentifier;
            metadata.session = session;
            metadata.sessionID = uploadID;
            metadata.sessionSelector = selector;
            metadata.sessionSelectorPost = selectorPost;
            metadata.typeCloud = _typeCloud;
            metadata.typeFile = metadataTypeFile_template;
            
            [CCCoreData addMetadata:metadata activeAccount:_activeAccount activeUrl:_activeUrl typeCloud:_typeCloud context:_context];
            
            // DATA
            [self uploadURLSession:fileNameCrypto fileNamePrint:fileName serverUrl:serverUrl directoryID:metadata.directoryID sessionID:uploadID session:metadata.session taskStatus:taskStatus assetDate:assetDate assetMediaType:assetMediaType cryptated:cryptated onlyPlist:onlyPlist parentRev:parentRev selector:selector];
            
            // PLIST
            [self uploadURLSession:[fileNameCrypto stringByAppendingString:@".plist"] fileNamePrint:fileName serverUrl:serverUrl directoryID:metadata.directoryID sessionID:uploadID session:metadata.session taskStatus:taskStatus assetDate:assetDate assetMediaType:assetMediaType cryptated:cryptated onlyPlist:onlyPlist parentRev:parentRev selector:selector];
        }
        
        if (template == NO) {
        
            NSString *passcode = [crypto getKeyPasscode:[CCUtility getUUID]];
        
            fileNameCrypto = [crypto encryptWithCreatePlist:fileName fileNameEncrypted:fileName passcode:passcode directoryUser:_directoryUser];
        
            // Encrypted file error
            if (fileNameCrypto == nil) {
            
                dispatch_async(dispatch_get_main_queue(), ^{
                
                    NSString *msg = [NSString stringWithFormat:NSLocalizedString(@"_encrypt_error_", nil), fileName, @""];
                
                    UIAlertController *alertController= [UIAlertController alertControllerWithTitle:nil message:msg preferredStyle:UIAlertControllerStyleAlert];
                    
                    UIAlertAction* ok = [UIAlertAction actionWithTitle: NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault
                                                               handler:^(UIAlertAction * action) {
                                                                   [alertController dismissViewControllerAnimated:YES completion:nil];
                                                               }];
                    [alertController addAction:ok];
                    
                    UIWindow *alertWindow = [[UIWindow alloc]initWithFrame:[UIScreen mainScreen].bounds];
                    alertWindow.rootViewController = [[UIViewController alloc]init];
                    alertWindow.windowLevel = UIWindowLevelAlert + 1;
                    
                    [alertWindow makeKeyAndVisible];
                    
                    [alertWindow.rootViewController presentViewController:alertController animated:YES completion:nil];
                    
                    // Error for uploadFileFailure
                    if ([[self getDelegate:uploadID] respondsToSelector:@selector(uploadFileFailure:serverUrl:selector:message:errorCode:)])
                        [[self getDelegate:uploadID] uploadFileFailure:nil serverUrl:serverUrl selector:selector message:NSLocalizedString(@"_encrypt_error_", nil) errorCode:0];
                });
            
                return;
            }
        
            metadata.cryptated = YES;
            metadata.date = [NSDate new];
            metadata.fileID = uploadID;
            metadata.directoryID = directoryID;
            metadata.fileName = [fileNameCrypto stringByAppendingString:@".plist"];
            metadata.fileNameData = fileNameCrypto;
            metadata.fileNamePrint = fileName;
            metadata.localIdentifier = localIdentifier;
            metadata.session = session;
            metadata.sessionID = uploadID;
            metadata.sessionSelector = selector;
            metadata.sessionSelectorPost = selectorPost;
            metadata.typeCloud = _typeCloud;
            metadata.title = [self getTitleFromPlistName:fileNameCrypto];
            metadata.type = metadataType_file;
            
            if (errorCode == 403) {
                
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:fileName message:NSLocalizedString(@"_file_already_exists_", nil) preferredStyle:UIAlertControllerStyleAlert];
                
                UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        // Change Asset Data only for automatic upload
                        //if ([selector isEqualToString:selectorUploadAutomatic])
                        //    [CCCoreData setCameraUploadDateAssetType:assetMediaType assetDate:assetDate activeAccount:_activeAccount];
                        
                        // Error for uploadFileFailure
                        if ([[self getDelegate:uploadID] respondsToSelector:@selector(uploadFileFailure:serverUrl:selector:message:errorCode:)])
                            [[self getDelegate:uploadID] uploadFileFailure:nil serverUrl:serverUrl selector:selector message:NSLocalizedString(@"_file_already_exists_", nil) errorCode:403];
                    });
                    
                    return;
                }];
                
                UIAlertAction *overwriteAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_overwrite_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    
                    // -- remove record --
                    CCMetadata *metadataDelete = [CCCoreData getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(account == %@) AND (fileName == %@) AND (directoryID == %@)", _activeAccount, [fileNameCrypto stringByAppendingString:@".plist"], directoryID] context:nil];
                    [CCCoreData deleteFile:metadataDelete serverUrl:serverUrl directoryUser:_directoryUser typeCloud:_typeCloud activeAccount:_activeAccount];
                    
#ifndef EXTENSION
                    [CCGraphics createNewImageFrom:fileName directoryUser:_directoryUser fileNameTo:uploadID fileNamePrint:fileName size:@"m" imageForUpload:YES typeFile:metadata.typeFile writePreview:YES optimizedFileName:NO];
#endif

                    if ([metadata.typeFile isEqualToString:metadataTypeFile_image] || [metadata.typeFile isEqualToString:metadataTypeFile_video])
                        [crypto addPlistImage:[NSString stringWithFormat:@"%@/%@", _directoryUser, [fileNameCrypto stringByAppendingString:@".plist"]] fileNamePathImage:[NSTemporaryDirectory() stringByAppendingString:uploadID]];
                    
                    [CCCoreData addMetadata:metadata activeAccount:_activeAccount activeUrl:_activeUrl typeCloud:_typeCloud context:_context];
                    
                    // DATA
                    [self uploadURLSession:fileNameCrypto fileNamePrint:fileName serverUrl:serverUrl directoryID:metadata.directoryID sessionID:uploadID session:metadata.session taskStatus:taskStatus assetDate:assetDate assetMediaType:assetMediaType cryptated:cryptated onlyPlist:onlyPlist parentRev:parentRev selector:selector];
                    
                    // PLIST
                    [self uploadURLSession:[fileNameCrypto stringByAppendingString:@".plist"] fileNamePrint:fileName serverUrl:serverUrl directoryID:metadata.directoryID sessionID:uploadID session:metadata.session taskStatus:taskStatus assetDate:assetDate assetMediaType:assetMediaType cryptated:cryptated onlyPlist:onlyPlist parentRev:parentRev selector:selector];
                }];

                [alertController addAction:cancelAction];
                [alertController addAction:overwriteAction];
                
                UIWindow *alertWindow = [[UIWindow alloc]initWithFrame:[UIScreen mainScreen].bounds];
                alertWindow.rootViewController = [[UIViewController alloc]init];
                alertWindow.windowLevel = UIWindowLevelAlert + 1;
                
                [alertWindow makeKeyAndVisible];
                
                [alertWindow.rootViewController presentViewController:alertController animated:YES completion:nil];
                
            } else {
                
#ifndef EXTENSION
                [CCGraphics createNewImageFrom:fileName directoryUser:_directoryUser fileNameTo:uploadID fileNamePrint:fileName size:@"m" imageForUpload:YES typeFile:metadata.typeFile writePreview:YES optimizedFileName:NO];
#endif
                
                if ([metadata.typeFile isEqualToString:metadataTypeFile_image] || [metadata.typeFile isEqualToString:metadataTypeFile_video])
                    [crypto addPlistImage:[NSString stringWithFormat:@"%@/%@", _directoryUser, [fileNameCrypto stringByAppendingString:@".plist"]] fileNamePathImage:[NSTemporaryDirectory() stringByAppendingString:uploadID]];
                
                [CCCoreData addMetadata:metadata activeAccount:_activeAccount activeUrl:_activeUrl typeCloud:_typeCloud context:_context];
                
                // DATA
                [self uploadURLSession:fileNameCrypto fileNamePrint:fileName serverUrl:serverUrl directoryID:metadata.directoryID sessionID:uploadID session:metadata.session taskStatus:taskStatus assetDate:assetDate assetMediaType:assetMediaType cryptated:cryptated onlyPlist:onlyPlist parentRev:parentRev selector:selector];
                
                // PLIST
                [self uploadURLSession:[fileNameCrypto stringByAppendingString:@".plist"] fileNamePrint:fileName serverUrl:serverUrl directoryID:metadata.directoryID sessionID:uploadID session:metadata.session taskStatus:taskStatus assetDate:assetDate assetMediaType:assetMediaType cryptated:cryptated onlyPlist:onlyPlist parentRev:parentRev selector:selector];
            }
        }
    }
    
    else if (cryptated == NO) {
        
        metadata.cryptated = NO;
        metadata.date = [NSDate new];
        metadata.fileID = uploadID;
        metadata.directoryID = directoryID;
        metadata.fileName = fileName;
        metadata.fileNameData = fileName;
        metadata.fileNamePrint = fileName;
        metadata.localIdentifier = localIdentifier;
        metadata.session = session;
        metadata.sessionID = uploadID;
        metadata.sessionSelector = selector;
        metadata.sessionSelectorPost = selectorPost;
        metadata.type = metadataType_file;
        metadata.typeCloud = _typeCloud;
        
        // File exists ???
        if (errorCode == 403) {
            
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:fileName message:NSLocalizedString(@"_file_already_exists_", nil) preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    // Change Asset Data only for automatic upload
                    //if ([selector isEqualToString:selectorUploadAutomatic])
                    //    [CCCoreData setCameraUploadDateAssetType:assetMediaType assetDate:assetDate activeAccount:_activeAccount];
                
                    // Error for uploadFileFailure
                    if ([[self getDelegate:uploadID] respondsToSelector:@selector(uploadFileFailure:serverUrl:selector:message:errorCode:)])
                        [[self getDelegate:uploadID] uploadFileFailure:nil serverUrl:serverUrl selector:selector message:NSLocalizedString(@"_file_already_exists_", nil) errorCode:403];
                });
                
                return;
            }];
            
            UIAlertAction *overwriteAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_overwrite_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                
                // -- remove record --
                CCMetadata *metadataDelete = [CCCoreData getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(account == %@) AND (fileName == %@) AND (directoryID == %@)", _activeAccount, fileName, directoryID] context:nil];
                [CCCoreData deleteFile:metadataDelete serverUrl:serverUrl directoryUser:_directoryUser typeCloud:_typeCloud activeAccount:_activeAccount];
                
                // -- Go to Upload --
                [CCGraphics createNewImageFrom:metadata.fileNamePrint directoryUser:_directoryUser fileNameTo:metadata.fileID fileNamePrint:metadata.fileNamePrint size:@"m" imageForUpload:YES typeFile:metadata.typeFile writePreview:YES optimizedFileName:NO];
                
                [CCCoreData addMetadata:metadata activeAccount:_activeAccount activeUrl:_activeUrl typeCloud:_typeCloud context:_context];
                
                [self uploadURLSession:fileName fileNamePrint:fileName serverUrl:serverUrl directoryID:metadata.directoryID sessionID:uploadID session:metadata.session taskStatus:taskStatus assetDate:assetDate assetMediaType:assetMediaType cryptated:cryptated onlyPlist:onlyPlist parentRev:parentRev selector:selector];
            }];
            
            [alertController addAction:cancelAction];
            [alertController addAction:overwriteAction];
            
            UIWindow *alertWindow = [[UIWindow alloc]initWithFrame:[UIScreen mainScreen].bounds];
            alertWindow.rootViewController = [[UIViewController alloc] init];
            alertWindow.windowLevel = UIWindowLevelAlert + 1;
           
            [alertWindow makeKeyAndVisible];
            
            [alertWindow.rootViewController presentViewController:alertController animated:YES completion:nil];
            
        } else {
            
            // -- Go to upload --
            
#ifndef EXTENSION
            [CCGraphics createNewImageFrom:metadata.fileNamePrint directoryUser:_directoryUser fileNameTo:metadata.fileID fileNamePrint:metadata.fileNamePrint size:@"m" imageForUpload:YES typeFile:metadata.typeFile writePreview:YES optimizedFileName:NO];
#endif
            [CCCoreData addMetadata:metadata activeAccount:_activeAccount activeUrl:_activeUrl typeCloud:_typeCloud context:_context];
            
            [self uploadURLSession:fileName fileNamePrint:fileName serverUrl:serverUrl directoryID:metadata.directoryID sessionID:uploadID session:metadata.session taskStatus:taskStatus assetDate:assetDate assetMediaType:assetMediaType cryptated:cryptated onlyPlist:onlyPlist parentRev:parentRev selector:selector];
        }
    }
}

- (void)uploadFileMetadata:(CCMetadata *)metadata taskStatus:(NSInteger)taskStatus
{
    BOOL send = NO;
    
    NSString *serverUrl = [CCCoreData getServerUrlFromDirectoryID:metadata.directoryID activeAccount:_activeAccount];
    
    if (metadata.cryptated) {
        
        // ENCRYPTED
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, metadata.fileNameData]] && [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, metadata.fileName]]) {
        
            send = YES;
            
            [self uploadURLSession:metadata.fileNameData fileNamePrint:metadata.fileNamePrint serverUrl:serverUrl directoryID:metadata.directoryID sessionID:metadata.sessionID session:metadata.session taskStatus:taskStatus assetDate:nil assetMediaType:0 cryptated:YES onlyPlist:NO parentRev:nil selector:metadata.sessionSelector];
            
            [self uploadURLSession:metadata.fileName fileNamePrint:metadata.fileNamePrint serverUrl:serverUrl directoryID:metadata.directoryID sessionID:metadata.sessionID session:metadata.session taskStatus:taskStatus assetDate:nil assetMediaType:PHAssetMediaTypeUnknown cryptated:YES onlyPlist:NO parentRev:nil selector:metadata.sessionSelector];
        }
        
    } else {
        
        // PLAIN
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, metadata.sessionID]]) {
            
            send = YES;
            
            [self uploadURLSession:metadata.fileName fileNamePrint:metadata.fileNamePrint serverUrl:serverUrl directoryID:metadata.directoryID sessionID:metadata.sessionID session:metadata.session taskStatus:taskStatus assetDate:nil assetMediaType:PHAssetMediaTypeUnknown cryptated:NO onlyPlist:NO parentRev:nil selector:metadata.sessionSelector];
        }
    }
    
    if (send) {
        
        NSLog(@"[LOG] Re-upload File : %@ - fileID : %@", metadata.fileNamePrint, metadata.fileID);
        
        // update Coredata
        [CCCoreData setMetadataSession:nil sessionError:@"" sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:taskIdentifierNULL sessionTaskIdentifierPlist:taskIdentifierNULL predicate:[NSPredicate predicateWithFormat:@"(sessionID == %@) AND (account == %@)", metadata.sessionID, _activeAccount] context:_context];
        
    } else {
        
        NSLog(@"[LOG] Error reUploadBackground, file not found.");
        
#ifndef EXTENSION
        UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_error_", nil) message:NSLocalizedString(@"_no_reuploadfile_", nil) delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
        [alertView show];
#endif
    }
}

- (void)uploadURLSession:(NSString *)fileName fileNamePrint:(NSString *)fileNamePrint serverUrl:(NSString *)serverUrl directoryID:(NSString *)directoryID sessionID:(NSString*)sessionID session:(NSString *)session taskStatus:(NSInteger)taskStatus assetDate:(NSDate *)assetDate assetMediaType:(PHAssetMediaType)assetMediaType cryptated:(BOOL)cryptated onlyPlist:(BOOL)onlyPlist parentRev:(NSString *)parentRev selector:(NSString *)selector
{
    NSURLSession *sessionUpload;
    NSURL *url;
    NSMutableURLRequest *request;
    
    if ([_typeCloud isEqualToString:typeCloudNextcloud] || [_typeCloud isEqualToString:typeCloudOwnCloud]) {
        
        NSString *fileNamePath = [[NSString stringWithFormat:@"%@/%@", serverUrl, fileName] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        url = [NSURL URLWithString:fileNamePath];
        request = [NSMutableURLRequest requestWithURL:url];
        
        NSData *authData = [[NSString stringWithFormat:@"%@:%@", _activeUser, _activePassword] dataUsingEncoding:NSUTF8StringEncoding];
        NSString *authValue = [NSString stringWithFormat: @"Basic %@",[authData base64EncodedStringWithOptions:0]];
        [request setHTTPMethod:@"PUT"];
        [request setValue:authValue forHTTPHeaderField:@"Authorization"];
    }
    
    // Rename with the SessionID
    NSString *fileNameForUpload;
    
    if ([CCUtility isFileNotCryptated:fileName]) fileNameForUpload = sessionID;
    else fileNameForUpload = fileName;
    
    if (!onlyPlist) {
    
        if ([CCUtility isFileNotCryptated:fileName])
            [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, fileName] toPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, fileNameForUpload] error:nil];
    
        if ([CCUtility isCryptoPlistString:fileName])
            [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, fileNamePrint] toPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, sessionID] error:nil];
    }
    
    // file exists ?
    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, fileNameForUpload]] == NO) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            // Error for uploadFileFailure
            if ([[self getDelegate:sessionID] respondsToSelector:@selector(uploadFileFailure:serverUrl:selector:message:errorCode:)])
                [[self getDelegate:sessionID] uploadFileFailure:sessionID serverUrl:serverUrl selector:selector message:NSLocalizedString(@"_file_not_present_", nil) errorCode:404];
            
            [CCCoreData deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(sessionID == %@) AND (account == %@)", sessionID, _activeAccount]];
        });

        return;
    }
    
    if ([session isEqualToString:upload_session]) sessionUpload = [self sessionUpload];
    else if ([session isEqualToString:upload_session_foreground]) sessionUpload = [self sessionUploadForeground];
    else if ([session isEqualToString:upload_session_wwan]) sessionUpload = [self sessionWWanUpload];

    NSURLSessionUploadTask *uploadTask = [sessionUpload uploadTaskWithRequest:request fromFile:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, fileNameForUpload]]];
    
    if (taskStatus == taskStatusCancel) [uploadTask cancel];
    else if (taskStatus == taskStatusSuspend) [uploadTask suspend];
    else if (taskStatus == taskStatusResume) [uploadTask resume];
    
    if ([[self getDelegate:sessionID] respondsToSelector:@selector(uploadTaskSave:)])
        [[self getDelegate:sessionID] uploadTaskSave:uploadTask];
    
    // COREDATA
    
    if (uploadTask == nil) {
        
        NSUInteger sessionTaskIdentifier = taskIdentifierNULL;
        NSUInteger sessionTaskIdentifierPlist = taskIdentifierNULL;
        
        if ([CCUtility isFileNotCryptated:fileName] || [CCUtility isCryptoString:fileName]) sessionTaskIdentifier = taskIdentifierError;
        if ([CCUtility isCryptoPlistString:fileName]) sessionTaskIdentifierPlist = taskIdentifierError;
        
        [CCCoreData setMetadataSession:session sessionError:[NSString stringWithFormat:@"%@", @CCErrorTaskNil] sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:sessionTaskIdentifier sessionTaskIdentifierPlist:sessionTaskIdentifierPlist predicate:[NSPredicate predicateWithFormat:@"(sessionID == %@) AND (account == %@)", sessionID, _activeAccount] context:_context];
        
        NSLog(@"[LOG] Upload file TaskIdentifier [error CCErrorTaskNil] - %@ - %@", fileName, fileNamePrint);
        
    } else {
        
        NSUInteger sessionTaskIdentifier = taskIdentifierNULL;
        NSUInteger sessionTaskIdentifierPlist = taskIdentifierNULL;
        
        if ([CCUtility isCryptoString:fileName] || [CCUtility isFileNotCryptated:fileName]) sessionTaskIdentifier = uploadTask.taskIdentifier;
        if ([CCUtility isCryptoPlistString:fileName]) sessionTaskIdentifierPlist = uploadTask.taskIdentifier;
        
        [CCCoreData setMetadataSession:session sessionError:@"" sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:sessionTaskIdentifier sessionTaskIdentifierPlist:sessionTaskIdentifierPlist predicate:[NSPredicate predicateWithFormat:@"(sessionID == %@) AND (account == %@)", sessionID, _activeAccount] context:_context];
        
        // Change Asset Data only for Automatic Upload
        //if ([selector isEqualToString:selectorUploadAutomatic])
        //    [CCCoreData setCameraUploadDateAssetType:assetMediaType assetDate:assetDate activeAccount:_activeAccount];
        
        NSLog(@"[LOG] Upload file %@ - %@ TaskIdentifier %lu", fileName,fileNamePrint, (unsigned long)uploadTask.taskIdentifier);
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        
        // refresh main
        if ([self.delegate respondsToSelector:@selector(getDataSourceWithReloadTableView:fileID:selector:)])
            [self.delegate getDataSourceWithReloadTableView:directoryID fileID:nil selector:selector];
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
    NSString *url = [[[task currentRequest].URL absoluteString] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *fileName = [url lastPathComponent];
    NSString *serverUrl = [self getServerUrlFromUrl:url];
    
    // if plist return
    if ([CCUtility getTypeFileName:fileName] == metadataTypeFilenamePlist)
        return;
    
    float progress = (float) totalBytesSent / (float)totalBytesExpectedToSend;

    if ([_currentProgressMetadata.fileName isEqualToString:fileName] == NO && [_currentProgressMetadata.fileNameData isEqualToString:fileName] == NO)
        _currentProgressMetadata = [CCCoreData getMetadataFromFileName:fileName directoryID:[CCCoreData getDirectoryIDFromServerUrl:serverUrl activeAccount:_activeAccount] activeAccount:_activeAccount context:_context];
    
    //NSLog(@"[LOG] %@ - %f", fileName, progress);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if (_currentProgressMetadata) {
            
#ifndef EXTENSION
            // Control Center
            [app.controlCenter progressTask:_currentProgressMetadata.fileID serverUrl:serverUrl cryptated:_currentProgressMetadata.cryptated progress:progress];
#endif
            
            if ([self.delegate respondsToSelector:@selector(progressTask:serverUrl:cryptated:progress:)])
                [self.delegate progressTask:_currentProgressMetadata.fileID serverUrl:serverUrl cryptated:_currentProgressMetadata.cryptated progress:progress];
        }
    });
}

- (void)uploadFileSuccessFailure:(CCMetadata *)metadata fileName:(NSString *)fileName fileID:(NSString *)fileID rev:(NSString *)rev date:(NSDate *)date serverUrl:(NSString *)serverUrl errorCode:(NSInteger)errorCode
{
    NSString *sessionID = metadata.sessionID;
    
    // ERRORE
    if (errorCode != 0) {
        
#ifndef EXTENSION
        if (sessionID)
            [app.listProgressMetadata removeObjectForKey:sessionID];
#endif
        
        // Mark error only if not Cancelled Task
        if (errorCode != kCFURLErrorCancelled)  {

            NSUInteger sessionTaskIdentifier = taskIdentifierNULL;
            NSUInteger sessionTaskIdentifierPlist = taskIdentifierNULL;
        
            if ([CCUtility isFileNotCryptated:fileName] || [CCUtility isCryptoString:fileName]) sessionTaskIdentifier = taskIdentifierError;
            if ([CCUtility isCryptoPlistString:fileName]) sessionTaskIdentifierPlist = taskIdentifierError;
        
            [CCCoreData setMetadataSession:nil sessionError:[NSString stringWithFormat:@"%@", @(errorCode)] sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:sessionTaskIdentifier sessionTaskIdentifierPlist:sessionTaskIdentifierPlist predicate:[NSPredicate predicateWithFormat:@"(sessionID == %@) AND (account == %@)", metadata.sessionID, _activeAccount] context:_context];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if ([[self getDelegate:sessionID] respondsToSelector:@selector(uploadFileFailure:serverUrl:selector:message:errorCode:)])
                [[self getDelegate:sessionID] uploadFileFailure:fileID serverUrl:serverUrl selector:metadata.sessionSelector message:[CCError manageErrorKCF:errorCode withNumberError:YES] errorCode:errorCode];
        });
        
        return;
    }
    
    // PLAIN or PLIST
    if ([CCUtility isFileNotCryptated:fileName] || [CCUtility isCryptoPlistString:fileName]) {
        
        metadata.fileID = fileID;
        metadata.rev = rev;
        metadata.date = date;
        metadata.sessionTaskIdentifierPlist = taskIdentifierDone;
        
        if ([CCUtility isFileNotCryptated:fileName])
            metadata.sessionTaskIdentifier = taskIdentifierDone;
        
        // copy ico in new fileID
        [CCUtility copyFileAtPath:[NSString stringWithFormat:@"%@/%@.ico", _directoryUser, sessionID] toPath:[NSString stringWithFormat:@"%@/%@.ico", _directoryUser, fileID]];
        
        [CCCoreData updateMetadata:metadata predicate:[NSPredicate predicateWithFormat:@"(sessionID == %@) AND (account == %@)", sessionID, _activeAccount] activeAccount:_activeAccount activeUrl:_activeUrl typeCloud:_typeCloud context:_context];
    }
    
    // CRYPTO
    if ([CCUtility isCryptoString:fileName]) {
        
        metadata.sessionTaskIdentifier = taskIdentifierDone;
        
        [CCCoreData updateMetadata:metadata predicate:[NSPredicate predicateWithFormat:@"(sessionID == %@) AND (account == %@)", sessionID, _activeAccount] activeAccount:_activeAccount activeUrl:_activeUrl typeCloud:_typeCloud context:_context];
    }
    
    // ALL TASK DONE (PLAIN/CRYPTO)
    if (metadata.sessionTaskIdentifier == taskIdentifierDone && metadata.sessionTaskIdentifierPlist == taskIdentifierDone) {
        
#ifndef EXTENSION
        if (sessionID)
            [app.listProgressMetadata removeObjectForKey:sessionID];
#endif
        
        NSLog(@"[LOG] Insert new upload : %@ - FileNamePrint : %@ - fileID : %@", metadata.fileName, metadata.fileNamePrint, metadata.fileID);
        
        metadata.session = @"";
        metadata.sessionError = @"";
        metadata.sessionID = @"";
        
        [CCCoreData updateMetadata:metadata predicate:[NSPredicate predicateWithFormat:@"(sessionID == %@) AND (account == %@)", sessionID, _activeAccount] activeAccount:_activeAccount activeUrl:_activeUrl typeCloud:_typeCloud context:_context];
        
        // rename file sessionID -> fileID
        [CCUtility moveFileAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, sessionID]  toPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, metadata.fileID]];
        
        // remove temp icon
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@.ico", _directoryUser, sessionID] error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@.ico", _directoryUser, metadata.fileID] error:nil];
        
        // if crypto remove filename data
        if (metadata.cryptated)
            [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, metadata.fileNameData] error:nil];
        
        // Local
        if (metadata.directory == NO)
            [CCCoreData addLocalFile:metadata activeAccount:_activeAccount];
        
        // EXIF
        if ([metadata.typeFile isEqualToString:metadataTypeFile_image])
            [CCExifGeo setExifLocalTableFileID:metadata directoryUser:_directoryUser activeAccount:_activeAccount];
        
        // Create ICON
        if (metadata.directory == NO)
            [CCGraphics createNewImageFrom:metadata.fileID directoryUser:_directoryUser fileNameTo:metadata.fileID fileNamePrint:metadata.fileNamePrint size:@"m" imageForUpload:NO typeFile:metadata.typeFile writePreview:YES optimizedFileName:[CCUtility getOptimizedPhoto]];
        
        // Optimization
        if ([CCUtility getUploadAndRemovePhoto] || [metadata.sessionSelectorPost isEqualToString:selectorUploadRemovePhoto])
            [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, metadata.fileID] error:nil];
        
        // Copy photo or video in the photo album for automatic upload
        if ([metadata.localIdentifier length] > 0 && [CCCoreData getCameraUploadSaveAlbumActiveAccount:_activeAccount] && [metadata.sessionSelector isEqualToString:selectorUploadAutomatic]) {
            
            PHAsset *asset;
            PHFetchResult *result = [PHAsset fetchAssetsWithLocalIdentifiers:@[metadata.localIdentifier] options:nil];
            if(result.count){
                asset = result[0];
                
                [asset saveToAlbum:_brand_ completionBlock:^(BOOL success) {
                    if (success) NSLog(@"[LOG] Insert file %@ in %@", metadata.fileNamePrint, _brand_);
                    else NSLog(@"[LOG] File %@ do not insert in %@", metadata.fileNamePrint, _brand_);
                }];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if ([[self getDelegate:sessionID] respondsToSelector:@selector(uploadFileSuccess:serverUrl:selector:selectorPost:)])
                [[self getDelegate:sessionID] uploadFileSuccess:metadata.fileID serverUrl:serverUrl selector:metadata.sessionSelector selectorPost:metadata.sessionSelectorPost];
        });
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Download Verify =====
#pragma --------------------------------------------------------------------------------------------

- (void)verifyDownloadInProgress
{
    NSArray *dataSourceDownload = [CCCoreData getTableMetadataDownloadAccount:_activeAccount];
    NSArray *dataSourceDownloadWWan = [CCCoreData getTableMetadataDownloadWWanAccount:_activeAccount];
    
    NSMutableArray *dataSource = [[NSMutableArray alloc] init];
    
    [dataSource addObjectsFromArray:dataSourceDownload];
    [dataSource addObjectsFromArray:dataSourceDownloadWWan];
    
    NSLog(@"[LOG] Verify download file in progress n. %lu", (unsigned long)[dataSource count]);
    
    for (TableMetadata *record in dataSource) {
        
        __block CCMetadata *metadata = [CCCoreData insertEntityInMetadata:record];
        
        NSURLSession *session = [self getSessionfromSessionDescription:metadata.session];
        
        [session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            
            BOOL findTask = NO;
            BOOL findTaskPlist = NO;
            
            for (NSURLSessionDownloadTask *downloadTask in downloadTasks) {
                
                NSLog(@"[LOG] Find metadata Tasks [%i %i] = [%lu] state : %lu", metadata.sessionTaskIdentifier, metadata.sessionTaskIdentifierPlist ,(unsigned long)downloadTask.taskIdentifier, (unsigned long)[downloadTask state]);
                
                if (metadata.sessionTaskIdentifier == downloadTask.taskIdentifier) findTask = YES;
                if (metadata.sessionTaskIdentifierPlist == downloadTask.taskIdentifier) findTaskPlist = YES;
                
                if (findTask == YES || findTaskPlist == YES) break; // trovati, download ancora in corso
            }
            
            // DATA
            if (findTask == NO && metadata.sessionTaskIdentifier >= 0) {
                
                NSLog(@"[LOG] NOT Find metadata Task [%i] fileID : %@ - filename : %@", metadata.sessionTaskIdentifier, metadata.fileID, metadata.fileNameData);
                
                [CCCoreData setMetadataSession:nil sessionError:[NSString stringWithFormat:@"%@", @CCErrorTaskDownloadNotFound] sessionSelector:nil sessionSelectorPost:nil sessionTaskIdentifier:taskIdentifierError sessionTaskIdentifierPlist:taskIdentifierNULL predicate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", metadata.fileID, _activeAccount] context:_context];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    if ([self.delegate respondsToSelector:@selector(getDataSourceWithReloadTableView:fileID:selector:)])
                        [self.delegate getDataSourceWithReloadTableView:metadata.directoryID fileID:metadata.fileID selector:nil];
                });
                
            }
            
            // PLIST
            if (findTaskPlist == NO && metadata.sessionTaskIdentifierPlist >= 0) {
                
                NSLog(@"[LOG] NOT Find metadata TaskPlist [%i] fileID : %@ - filename : %@", metadata.sessionTaskIdentifierPlist, metadata.fileID, metadata.fileName);
                
                [CCCoreData setMetadataSession:@"" sessionError:@"" sessionSelector:@"" sessionSelectorPost:@"" sessionTaskIdentifier:taskIdentifierNULL sessionTaskIdentifierPlist:taskIdentifierDone predicate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", metadata.fileID, _activeAccount] context:_context];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    if ([self.delegate respondsToSelector:@selector(getDataSourceWithReloadTableView:fileID:selector:)])
                        [self.delegate getDataSourceWithReloadTableView:metadata.directoryID fileID:metadata.fileID selector:nil];
                });
            }
            
        }];
    }
    
    [self automaticDownloadInError];
}

- (void)automaticDownloadInError
{
    NSMutableSet *directoryIDs = [[NSMutableSet alloc] init];
    
    NSArray *records = [CCCoreData getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (session CONTAINS 'download') AND ((sessionTaskIdentifier == %i) OR (sessionTaskIdentifierPlist == %i))", _activeAccount, taskIdentifierError, taskIdentifierError] context:nil];
    
    NSLog(@"[LOG] Verify re download n. %lu", (unsigned long)[records count]);
    
    for (TableMetadata *record in records) {
        
        CCMetadata *metadata = [CCCoreData insertEntityInMetadata:record];
        
        NSString *serverUrl = [CCCoreData getServerUrlFromDirectoryID:metadata.directoryID activeAccount:metadata.account];
            
        if (metadata.sessionTaskIdentifier == taskIdentifierError)
            [self downloadFile:metadata serverUrl:serverUrl downloadData:YES downloadPlist:NO selector:metadata.sessionSelector selectorPost:nil session:download_session taskStatus:taskStatusResume delegate:nil];
            
        if (metadata.sessionTaskIdentifierPlist == taskIdentifierError)
            [self downloadFile:metadata serverUrl:serverUrl downloadData:NO downloadPlist:YES selector:metadata.sessionSelector selectorPost:nil session:download_session taskStatus:taskStatusResume delegate:nil];
            
        [directoryIDs addObject:metadata.directoryID];
            
        NSLog(@"[LOG] Re download file : %@ - %@ [%i %i]", metadata.fileName, metadata.fileNamePrint, metadata.sessionTaskIdentifier, metadata.sessionTaskIdentifierPlist);
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        for (NSString *directoryID in directoryIDs)
            if ([self.delegate respondsToSelector:@selector(getDataSourceWithReloadTableView:fileID:selector:)])
                [self.delegate getDataSourceWithReloadTableView:directoryID fileID:nil selector:nil];
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Upload Verify =====
#pragma --------------------------------------------------------------------------------------------

- (void)verifyUploadInProgress
{
    NSArray *dataSourceUpload = [CCCoreData getTableMetadataUploadAccount:_activeAccount];
    NSArray *dataSourceUploadWWan = [CCCoreData getTableMetadataUploadWWanAccount:_activeAccount];

    NSMutableArray *dataSource = [[NSMutableArray alloc] init];
    
    [dataSource addObjectsFromArray:dataSourceUpload];
    [dataSource addObjectsFromArray:dataSourceUploadWWan];
    
    NSLog(@"[LOG] Verify upload file in progress n. %lu", (unsigned long)[dataSource count]);
    
    for (TableMetadata *record in dataSource) {
        
        __block CCMetadata *metadata = [CCCoreData insertEntityInMetadata:record];
        __block NSString *serverUrl = [CCCoreData getServerUrlFromDirectoryID:metadata.directoryID activeAccount:_activeAccount];
        
        NSURLSession *session = [self getSessionfromSessionDescription:metadata.session];
        
        [session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            
            BOOL findTask = NO;
            BOOL findTaskPlist = NO;
            
            // cerchiamo la corrispondenza dei task
            for (NSURLSessionUploadTask *uploadTask in uploadTasks) {
                
                NSLog(@"[LOG] Find metadata Tasks [%i %i] = [%lu] state : %lu", metadata.sessionTaskIdentifier, metadata.sessionTaskIdentifierPlist , (unsigned long)uploadTask.taskIdentifier, (unsigned long)[uploadTask state]);
                
                if (metadata.sessionTaskIdentifier == uploadTask.taskIdentifier) findTask = YES;
                if (metadata.sessionTaskIdentifierPlist == uploadTask.taskIdentifier) findTaskPlist = YES;
                
                if (findTask == YES || findTaskPlist == YES) break;
            }
            
            // se non c'è (ci sono) il relativo uploadTask.taskIdentifier allora chiediamolo
            if ((metadata.cryptated == YES && findTask == NO && findTaskPlist == NO) || (metadata.cryptated == NO && findTask == NO)) {
                
                NSLog(@"[LOG] Call ReadFileVerifyUpload because this file %@ (criptated %i) is in progress but there is no task : [%i %i]", metadata.fileNamePrint, metadata.cryptated, metadata.sessionTaskIdentifier, metadata.sessionTaskIdentifierPlist);
                
                if (metadata.sessionTaskIdentifier >= 0) [self readFileVerifyUpload:metadata.fileNameData fileNamePrint:metadata.fileNamePrint serverUrl:serverUrl];
                if (metadata.sessionTaskIdentifierPlist >= 0) [self readFileVerifyUpload:metadata.fileName fileNamePrint:metadata.fileNamePrint serverUrl:serverUrl];
            }
        }];
        
        // Notification change session
        dispatch_async(dispatch_get_main_queue(), ^{
            NSArray *object = [[NSArray alloc] initWithObjects:session, metadata, nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:networkingSessionNotification object:object];
        });
    }
    
    [self automaticUploadInError];
}

- (void)automaticUploadInError
{
    NSMutableSet *directoryIDs = [[NSMutableSet alloc] init];
    
    NSArray *records = [CCCoreData getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (session CONTAINS 'upload') AND ((sessionTaskIdentifier == %i) OR (sessionTaskIdentifierPlist == %i))", _activeAccount, taskIdentifierError, taskIdentifierError] context:nil];
    
    NSLog(@"[LOG] Verify re upload n. %lu", (unsigned long)[records count]);
    
    for (TableMetadata *record in records) {
        
        CCMetadata *metadata = [CCCoreData insertEntityInMetadata:record];
        
        [self uploadFileMetadata:metadata taskStatus:taskStatusResume];
            
        [directoryIDs addObject:metadata.directoryID];
            
        NSLog(@"[LOG] Re upload file : %@", metadata.fileName);
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        for (NSString *directoryID in directoryIDs)
            if ([self.delegate respondsToSelector:@selector(getDataSourceWithReloadTableView:fileID:selector:)])
                [self.delegate getDataSourceWithReloadTableView:directoryID fileID:nil selector:nil];
    });
}

- (void)readFileVerifyUpload:(NSString *)fileName fileNamePrint:(NSString *)fileNamePrint serverUrl:(NSString *)serverUrl
{
#ifndef EXTENSION
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:_activeAccount];
    
    metadataNet.action = actionReadFile;
    metadataNet.fileName = fileName;
    metadataNet.fileNamePrint = fileNamePrint;
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
- (void)readFileSuccess:(CCMetadataNet *)metadataNet metadata:(CCMetadata *)metadata
{
    NSString *fileName;
    
    if ([CCUtility isCryptoString:metadata.fileName])
        fileName = [metadata.fileName stringByAppendingString:@".plist"];
    else
        fileName = metadataNet.fileName;
    
    NSString *directoryID = [CCCoreData getDirectoryIDFromServerUrl:metadataNet.serverUrl activeAccount:_activeAccount];
    
    CCMetadata *metadataTemp = [CCCoreData getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(fileName == %@) AND (directoryID == %@) AND (account == %@)", fileName , directoryID, _activeAccount] context:_context];
    
    // is completed ?
    if (metadataTemp.sessionTaskIdentifier == taskIdentifierDone && metadataTemp.sessionTaskIdentifierPlist == taskIdentifierDone) {
        
        [CCGraphics createNewImageFrom:metadata.fileID directoryUser:_directoryUser fileNameTo:metadata.fileID fileNamePrint:metadata.fileNamePrint size:@"m" imageForUpload:NO typeFile:metadata.typeFile writePreview:YES optimizedFileName:[CCUtility getOptimizedPhoto]];
        
        NSLog(@"[LOG] Verify read file success, but files already processed");
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if ([self.delegate respondsToSelector:@selector(getDataSourceWithReloadTableView:fileID:selector:)])
                [self.delegate getDataSourceWithReloadTableView:metadataTemp.directoryID fileID:metadataTemp.fileID selector:metadataNet.selector];
        });
        
    } else {
        
        [self uploadFileSuccessFailure:metadataTemp fileName:metadataNet.fileName fileID:metadata.fileID rev:metadata.rev date:metadata.date serverUrl:metadataNet.serverUrl errorCode:0];
    }
}

//
// File do not exists : selectorReadFileVerifyUpload
//
- (void)readFileFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    NSString *fileName;
    
    if ([CCUtility isCryptoString:metadataNet.fileName])
        fileName = [metadataNet.fileName stringByAppendingString:@".plist"];
    else
        fileName = metadataNet.fileName;
    
    NSString *directoryID = [CCCoreData getDirectoryIDFromServerUrl:metadataNet.serverUrl activeAccount:_activeAccount];
    
    CCMetadata *metadata = [CCCoreData getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(fileName == %@) AND (directoryID == %@) AND (account == %@)",fileName , directoryID, _activeAccount] context:_context];
    
    NSInteger error;
    if (errorCode == kOCErrorServerPathNotFound)
        error = CCErrorFileUploadNotFound;
    else
        error = errorCode;
    
    [self uploadFileSuccessFailure:metadata fileName:metadataNet.fileName fileID:metadata.fileID rev:metadata.rev date:metadata.date serverUrl:metadataNet.serverUrl errorCode:error];    
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
    
    if ([_typeCloud isEqualToString:typeCloudOwnCloud] || [_typeCloud isEqualToString:typeCloudNextcloud]) {
        
        url = [url stringByReplacingOccurrencesOfString:[@"/" stringByAppendingString:fileName] withString:@""];
    }

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
