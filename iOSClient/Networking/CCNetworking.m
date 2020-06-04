//
//  CCNetworking.m
//  Nextcloud
//
//  Created by Marino Faggiana on 01/06/15.
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

#import "CCNetworking.h"
#import "NCEndToEndEncryption.h"
#import "AppDelegate.h"
#import "NSDate+ISO8601.h"
#import "NSString+Encode.h"
#import "NCBridgeSwift.h"

@interface CCNetworking ()
{
    
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
    
    // Initialization Sessions
    

    [self sessionUpload];
    [self sessionWWanUpload];
    [self sessionUploadForeground];
    
    return self;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Session =====
#pragma --------------------------------------------------------------------------------------------


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

- (NSURLSession *)getSessionfromSessionDescription:(NSString *)sessionDescription
{
    if ([sessionDescription isEqualToString:k_upload_session]) return [self sessionUpload];
    if ([sessionDescription isEqualToString:k_upload_session_wwan]) return [self sessionWWanUpload];
    if ([sessionDescription isEqualToString:k_upload_session_foreground]) return [self sessionUploadForeground];
    
    return nil;
}

- (void)invalidateAndCancelAllSession
{
 
    [[self sessionUpload] invalidateAndCancel];
    [[self sessionWWanUpload] invalidateAndCancel];
    [[self sessionUploadForeground] invalidateAndCancel];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== URLSession download/upload =====
#pragma --------------------------------------------------------------------------------------------

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
    // The pinnning check
    if ([[NCNetworking shared] checkTrustedChallengeWithChallenge:challenge directoryCertificate:[CCUtility getDirectoryCerificates]]) {
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

    // ------------------------ UPLOAD -----------------------
    
    if ([task isKindOfClass:[NSURLSessionUploadTask class]]) {
        
        tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataInSessionFromFileName:fileName serverUrl:serverUrl taskIdentifier:task.taskIdentifier];
        if (metadata) {
            
            NSDictionary *fields = [httpResponse allHeaderFields];
            NSString *ocId = metadata.ocId;
            NSString *etag = metadata.etag;
            
            if (errorCode == 0) {
            
                if ([CCUtility removeForbiddenCharactersFileSystem:[fields objectForKey:@"OC-FileId"]] != nil) {
                    ocId = [CCUtility removeForbiddenCharactersFileSystem:[fields objectForKey:@"OC-FileId"]];
                } else if ([CCUtility removeForbiddenCharactersFileSystem:[fields objectForKey:@"FileId"]] != nil) {
                    ocId = [CCUtility removeForbiddenCharactersFileSystem:[fields objectForKey:@"FileId"]];
                }
                
                if ([CCUtility removeForbiddenCharactersFileSystem:[fields objectForKey:@"OC-ETag"]] != nil) {
                    etag = [CCUtility removeForbiddenCharactersFileSystem:[fields objectForKey:@"OC-ETag"]];
                } else if ([CCUtility removeForbiddenCharactersFileSystem:[fields objectForKey:@"ETag"]] != nil) {
                    etag = [CCUtility removeForbiddenCharactersFileSystem:[fields objectForKey:@"ETag"]];
                }
                
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
                
            if (fileName.length > 0 && ocId.length > 0 && serverUrl.length > 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self uploadFileSuccessFailure:metadata fileName:fileName ocId:ocId etag:etag date:date serverUrl:serverUrl errorCode:errorCode];
                });
            }
        }
    }
}


#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Upload =====
#pragma --------------------------------------------------------------------------------------------

- (void)uploadFile:(tableMetadata *)metadata taskStatus:(NSInteger)taskStatus
{
    // Password nil
    if ([CCUtility getPassword:metadata.account].length == 0) {
                
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_uploadedFile object:nil userInfo:@{@"metadata": metadata, @"errorCode": @(kOCErrorServerUnauthorized), @"errorDescription": @"_bad_username_password_"}];
        return;
        
    } else if ([CCUtility getCertificateError:metadata.account]) {
        
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_uploadedFile object:nil userInfo:@{@"metadata": metadata, @"errorCode": @(NSURLErrorServerCertificateUntrusted), @"errorDescription": @"_ssl_certificate_untrusted_"}];
        return;
    }

    if ([CCUtility fileProviderStorageExists:metadata.ocId fileNameView:metadata.fileNameView] == NO) {
        
        [CCUtility extractImageVideoFromAssetLocalIdentifierForUpload:metadata notification:true completion:^(tableMetadata *newMetadata, NSString *fileNamePath) {
            
            if (newMetadata == nil) {
                
                [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", metadata.ocId]];
                
            } else {
                
                NSString *toPath = [CCUtility getDirectoryProviderStorageOcId:newMetadata.ocId fileNameView:newMetadata.fileNameView];
                [CCUtility moveFileAtPath:fileNamePath toPath:toPath];
                
                tableMetadata *metadataForUpload = [[NCManageDatabase sharedInstance] addMetadata:newMetadata];
                
                if ([CCUtility isFolderEncrypted:metadataForUpload.serverUrl e2eEncrypted:metadataForUpload.e2eEncrypted account:metadataForUpload.account] && [CCUtility isEndToEndEnabled:metadataForUpload.account]) {
                    [self e2eEncryptedFile:metadataForUpload taskStatus:taskStatus];
                } else {
                    [self uploadURLSessionMetadata:metadataForUpload taskStatus:taskStatus];
                }
            }
        }];
        
    } else {
        
        NSDictionary *results = [[NCCommunicationCommon shared] objcGetInternalContenTypeWithFileName:metadata.fileNameView contentType:metadata.contentType directory:metadata.directory];
        metadata.contentType = results[@"contentType"];
        metadata.iconName = results[@"iconName"];
        metadata.typeFile = results[@"typeFile"];

        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[CCUtility getDirectoryProviderStorageOcId:metadata.ocId fileNameView:metadata.fileName] error:nil];
        
        if (attributes[NSFileModificationDate]) {
            metadata.date = attributes[NSFileModificationDate];
        } else {
            metadata.date = [NSDate date];
        }
        metadata.size = [attributes[NSFileSize] longValue];
        
        tableMetadata *metadataForUpload = [[NCManageDatabase sharedInstance] addMetadata:metadata];
        
        if ([CCUtility isFolderEncrypted:metadataForUpload.serverUrl e2eEncrypted:metadataForUpload.e2eEncrypted account:metadataForUpload.account] && [CCUtility isEndToEndEnabled:metadataForUpload.account]) {
            [self e2eEncryptedFile:metadataForUpload taskStatus:taskStatus];
        } else {
            [self uploadURLSessionMetadata:metadataForUpload taskStatus:taskStatus];
        }
    }
}

- (void)e2eEncryptedFile:(tableMetadata *)metadata taskStatus:(NSInteger)taskStatus
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", metadata.account]];
    if (tableAccount == nil) {
        [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", metadata.ocId]];
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_uploadedFile object:nil userInfo:@{@"metadata": metadata, @"errorCode": @(k_CCErrorInternalError), @"errorDescription": @"Upload error, account not found"}];
        return;
    }
           
    NSString *fileNameIdentifier;
    NSString *key;
    NSString *initializationVector;
    NSString *authenticationTag;
    NSString *metadataKey;
    NSInteger metadataKeyIndex;

    // Verify File Size
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[CCUtility getDirectoryProviderStorageOcId:metadata.ocId fileNameView:metadata.fileNameView] error:nil];
    NSNumber *fileSizeNumber = [fileAttributes objectForKey:NSFileSize];
    long long fileSize = [fileSizeNumber longLongValue];

    if (fileSize > k_max_filesize_E2EE) {
        // Error for uploadFileFailure
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_uploadedFile object:nil userInfo:@{@"metadata": metadata, @"errorCode": @(k_CCErrorInternalError), @"errorDescription": @"E2E Error file too big"}];
        return;
    }
        
    // if new file upload create a new encrypted filename
    fileNameIdentifier = [CCUtility generateRandomIdentifier];
    
    /*
    if ([metadata.ocId isEqualToString:[CCUtility createMetadataIDFromAccount:metadata.account serverUrl:metadata.serverUrl fileNameView:metadata.fileNameView directory:false]]) {
        fileNameIdentifier = [CCUtility generateRandomIdentifier];
    } else {
        fileNameIdentifier = metadata.fileName;
    }
    */
    
    [[NCEndToEndEncryption sharedManager] encryptFileName:metadata.fileNameView fileNameIdentifier:fileNameIdentifier directory:[CCUtility getDirectoryProviderStorageOcId:metadata.ocId] key:&key initializationVector:&initializationVector authenticationTag:&authenticationTag];
            
    tableE2eEncryption *object = [[NCManageDatabase sharedInstance] getE2eEncryptionWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", tableAccount.account, metadata.serverUrl]];
    if (object) {
        metadataKey = object.metadataKey;
        metadataKeyIndex = object.metadataKeyIndex;
    } else {
        metadataKey = [[[NCEndToEndEncryption sharedManager] generateKey:16] base64EncodedStringWithOptions:0]; // AES_KEY_128_LENGTH
        metadataKeyIndex = 0;
    }
        
    tableE2eEncryption *addObject = [tableE2eEncryption new];
    
    addObject.account = tableAccount.account;
    addObject.authenticationTag = authenticationTag;
    addObject.fileName = metadata.fileNameView;
    addObject.fileNameIdentifier = fileNameIdentifier;
    addObject.fileNamePath = [CCUtility returnFileNamePathFromFileName:metadata.fileNameView serverUrl:metadata.serverUrl activeUrl:tableAccount.url];
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
    
    addObject.serverUrl = metadata.serverUrl;
    NSString *e2eeApiVersion = [[NCManageDatabase sharedInstance] getCapabilitiesServerStringWithAccount:tableAccount.account elements:NCElementsJSON.shared.capabilitiesE2EEApiVersion];
    addObject.version = [e2eeApiVersion intValue];
    
    // Get the last metadata
    tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", tableAccount.account, metadata.serverUrl]];
        
    [[NCCommunication shared] getE2EEMetadataWithFileId:directory.fileId e2eToken:nil customUserAgent:nil addCustomHeaders:nil completionHandler:^(NSString *account, NSString *e2eMetadata, NSInteger errorCode, NSString *errorDescription) {
        if (errorCode == 0 && e2eMetadata != nil) {
            if ([[NCEndToEndMetadata sharedInstance] decoderMetadata:e2eMetadata privateKey:[CCUtility getEndToEndPrivateKey:tableAccount.account] serverUrl:directory.serverUrl account:tableAccount.account url:tableAccount.url] == false) {
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_uploadedFile object:nil userInfo:@{@"metadata": metadata, @"errorCode": @(k_CCErrorInternalError), @"errorDescription": @"_e2e_error_decode_metadata_"}];
                return;
            }
        }
            
        if([[NCManageDatabase sharedInstance] addE2eEncryption:addObject] == NO) {
            
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_uploadedFile object:nil userInfo:@{@"metadata": metadata, @"errorCode": @(k_CCErrorInternalError), @"errorDescription": @"_e2e_error_create_encrypted_"}];
            return;
        }
        
        // Now the fileName is fileNameIdentifier && flag e2eEncrypted
        metadata.fileName = fileNameIdentifier;
        metadata.e2eEncrypted = YES;
        
        // Update Metadata
        tableMetadata *metadataEncrypted = [[NCManageDatabase sharedInstance] addMetadata:metadata];
        
        [self uploadURLSessionMetadata:metadataEncrypted taskStatus:taskStatus];
        
    }];
}

- (void)uploadURLSessionMetadata:(tableMetadata *)metadata taskStatus:(NSInteger)taskStatus
{
    NSURL *url;
    NSMutableURLRequest *request;
    PHAsset *asset;
    NSError *error;
    
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", metadata.account]];
    if (tableAccount == nil) {
        [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", metadata.ocId]];
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_uploadedFile object:nil userInfo:@{@"metadata": metadata, @"errorCode": @(k_CCErrorInternalError), @"errorDescription": @"Upload error, account not found"}];
        return;
    }
    
    // calculate and store file size
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[CCUtility getDirectoryProviderStorageOcId:metadata.ocId fileNameView:metadata.fileName] error:&error];
    long long fileSize = [[fileAttributes objectForKey:NSFileSize] longLongValue];
    metadata.size = fileSize;
    [[NCManageDatabase sharedInstance] addMetadata:metadata];
    
    url = [NSURL URLWithString:[[NSString stringWithFormat:@"%@/%@", metadata.serverUrl, metadata.fileName] encodeString:NSUTF8StringEncoding]];
    request = [NSMutableURLRequest requestWithURL:url];
        
    NSData *authData = [[NSString stringWithFormat:@"%@:%@", tableAccount.user, [CCUtility getPassword:tableAccount.account]] dataUsingEncoding:NSUTF8StringEncoding];
    NSString *authValue = [NSString stringWithFormat: @"Basic %@",[authData base64EncodedStringWithOptions:0]];
    [request setHTTPMethod:@"PUT"];
    [request setValue:authValue forHTTPHeaderField:@"Authorization"];
    [request setValue:[CCUtility getUserAgent] forHTTPHeaderField:@"User-Agent"];

    // Create Image for Upload (gray scale)
#ifndef EXTENSION
    [CCGraphics createNewImageFrom:metadata.fileNameView ocId:metadata.ocId filterGrayScale:YES typeFile:metadata.typeFile writeImage:YES];
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
         
     // NSURLSession
     NSURLSession *sessionUpload;
     if ([metadata.session isEqualToString:k_upload_session]) sessionUpload = [self sessionUpload];
     else if ([metadata.session isEqualToString:k_upload_session_wwan]) sessionUpload = [self sessionWWanUpload];
     else if ([metadata.session isEqualToString:k_upload_session_foreground]) sessionUpload = [self sessionUploadForeground];
     
     NSURLSessionUploadTask *uploadTask = [sessionUpload uploadTaskWithRequest:request fromFile:[NSURL fileURLWithPath:[CCUtility getDirectoryProviderStorageOcId:metadata.ocId fileNameView:metadata.fileName]]];
     
     // Manage uploadTask cancel,suspend,resume
     if (taskStatus == k_taskStatusCancel) [uploadTask cancel];
     else if (taskStatus == k_taskStatusSuspend) [uploadTask suspend];
     else if (taskStatus == k_taskStatusResume) [uploadTask resume];
     
     // *** PLAIN ***
     [[NCManageDatabase sharedInstance] setMetadataSession:metadata.session sessionError:@"" sessionSelector:nil sessionTaskIdentifier:uploadTask.taskIdentifier status:k_metadataStatusUploading predicate:[NSPredicate predicateWithFormat:@"ocId == %@", metadata.ocId]];
     
     NSLog(@"[LOG] Upload file %@ TaskIdentifier %lu", metadata.fileName, (unsigned long)uploadTask.taskIdentifier);
     
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_uploadFileStart object:nil userInfo:@{@"ocId": metadata.ocId, @"task": uploadTask, @"serverUrl": metadata.serverUrl, @"account": metadata.account}];
    
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_reloadDataSource object:nil userInfo:@{@"ocId": metadata.ocId,@"serverUrl": metadata.serverUrl}];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    NSString *url = [[[task currentRequest].URL absoluteString] stringByRemovingPercentEncoding];
    NSString *fileName = [url lastPathComponent];
    NSString *serverUrl = [self getServerUrlFromUrl:url];
    if (!serverUrl) return;
    
    if (totalBytesExpectedToSend < 1) {
        totalBytesExpectedToSend = totalBytesSent;
    }
    
    float progress = (float) totalBytesSent / (float)totalBytesExpectedToSend;

    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataInSessionFromFileName:fileName serverUrl:serverUrl taskIdentifier:task.taskIdentifier];
    
    if (metadata) {
        NSDictionary *userInfo = @{@"account": (metadata.account), @"ocId": (metadata.ocId), @"serverUrl": (serverUrl), @"status": ([NSNumber numberWithLong:k_metadataStatusInUpload]), @"progress": ([NSNumber numberWithFloat:progress]), @"totalBytes": ([NSNumber numberWithLongLong:totalBytesSent]), @"totalBytesExpected": ([NSNumber numberWithLongLong:totalBytesExpectedToSend])};
        if (userInfo)
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_progressTask object:nil userInfo:userInfo];
    }
}

- (void)uploadFileSuccessFailure:(tableMetadata *)metadata fileName:(NSString *)fileName ocId:(NSString *)ocId etag:(NSString *)etag date:(NSDate *)date serverUrl:(NSString *)serverUrl errorCode:(NSInteger)errorCode
{
    NSString *tempocId = metadata.ocId;
    NSString *errorMessage = @"";

    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", metadata.account]];
    if (tableAccount == nil) {
        [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", tempocId]];

        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_uploadedFile object:nil userInfo:@{@"metadata": metadata, @"errorCode": @(errorCode), @"errorDescription": errorMessage}];
        return;
    }

    // ERRORE
    if (errorCode != 0) {
        
#ifndef EXTENSION
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        [appDelegate.listProgressMetadata removeObjectForKey:metadata.ocId];
#endif
        
        // Mark error only if not Cancelled Task
        if (errorCode == kCFURLErrorCancelled)  {
            
            if (metadata.status == k_metadataStatusUploadForcedStart) {
                
                errorCode = 0;
                
                metadata.session = k_upload_session;
                metadata.sessionError = @"";
                metadata.sessionTaskIdentifier = 0;
                metadata.status = k_metadataStatusInUpload;
                metadata = [[NCManageDatabase sharedInstance] addMetadata:metadata];

                [[CCNetworking sharedNetworking] uploadFile:metadata taskStatus:k_taskStatusResume];
                
            } else {
                
                [[NSFileManager defaultManager] removeItemAtPath:[CCUtility getDirectoryProviderStorageOcId:tempocId] error:nil];
                [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", tempocId]];
                
                errorMessage = [CCError manageErrorKCF:errorCode withNumberError:YES];
            }
            
        } else {

            if (metadata && (errorCode == kOCErrorServerUnauthorized || errorCode == kOCErrorServerForbidden)) {
#ifndef EXTENSION
                [[NCNetworkingCheckRemoteUser shared] checkRemoteUserWithAccount:metadata.account];
#endif
            } else if (metadata && errorCode == NSURLErrorServerCertificateUntrusted) {
                [CCUtility setCertificateError:metadata.account error:YES];
            }
            
            [[NCManageDatabase sharedInstance] setMetadataSession:nil sessionError:[CCError manageErrorKCF:errorCode withNumberError:NO] sessionSelector:nil sessionTaskIdentifier:k_taskIdentifierDone status:k_metadataStatusUploadError predicate:[NSPredicate predicateWithFormat:@"ocId == %@", tempocId]];
            
            errorMessage = [CCError manageErrorKCF:errorCode withNumberError:YES];
        }
        
    } else {
    
        // Delete Asset
        if (tableAccount.autoUploadDeleteAssetLocalIdentifier && ![metadata.assetLocalIdentifier isEqualToString:@""] && [metadata.sessionSelector isEqualToString:selectorUploadAutoUpload]) {
            metadata.deleteAssetLocalIdentifier = true;
        }
        
        // Edited file, remove tempocId and adjust the directory provider storage
        if (metadata.edited) {
            
            // Update metadata tempocId
            [[NCManageDatabase sharedInstance] setMetadataSession:@"" sessionError:@"" sessionSelector:@"" sessionTaskIdentifier:k_taskIdentifierDone status:k_metadataStatusNormal predicate:[NSPredicate predicateWithFormat:@"ocId == %@", tempocId]];
            
            // Add metadata ocId
            metadata.date = date;
            metadata.etag = etag;
            metadata.ocId = ocId;
            metadata.session = @"";
            metadata.sessionError = @"";
            metadata.sessionTaskIdentifier = k_taskIdentifierDone;
            metadata.status = k_metadataStatusNormal;
            
            metadata = [[NCManageDatabase sharedInstance] addMetadata:metadata];
            
            // Copy new version on old version
            if (![tempocId isEqualToString:metadata.ocId]) {
                [CCUtility copyFileAtPath:[NSString stringWithFormat:@"%@/%@", [CCUtility getDirectoryProviderStorage], tempocId] toPath:[NSString stringWithFormat:@"%@/%@", [CCUtility getDirectoryProviderStorage], metadata.ocId]];
                [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", tempocId]];
                // IMI -> Unzip
#if HC
                if ([metadata.typeFile isEqualToString:k_metadataTypeFile_imagemeter]) {
                    (void)[[IMUtility shared] IMUnzipWithMetadata:metadata];
                }
#endif
            }
            
        } else {
            
            // Replace Metadata
            metadata.date = date;
            metadata.etag = etag;
            metadata.ocId = ocId;
            metadata.session = @"";
            metadata.sessionError = @"";
            metadata.sessionTaskIdentifier = k_taskIdentifierDone;
            metadata.status = k_metadataStatusNormal;
            
            [CCUtility moveFileAtPath:[NSString stringWithFormat:@"%@/%@", [CCUtility getDirectoryProviderStorage], tempocId] toPath:[NSString stringWithFormat:@"%@/%@", [CCUtility getDirectoryProviderStorage], metadata.ocId]];
            
            [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND fileName == %@", metadata.account, metadata.serverUrl, metadata.fileName]];
            metadata = [[NCManageDatabase sharedInstance] addMetadata:metadata];
            
            NSLog(@"[LOG] Insert new upload : %@ - ocId : %@", metadata.fileName, ocId);
        }
#ifndef EXTENSION
        
        // EXIF
        if ([metadata.typeFile isEqualToString: k_metadataTypeFile_image])
            [[CCExifGeo sharedInstance] setExifLocalTableEtag:metadata];
        
        // Create preview
        [CCGraphics createNewImageFrom:metadata.fileNameView ocId:metadata.ocId filterGrayScale:NO typeFile:metadata.typeFile writeImage:YES];

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
        
        // Add Local or Remove from cache
        if ([CCUtility getDisableLocalCacheAfterUpload] && !metadata.edited) {
            [[NSFileManager defaultManager] removeItemAtPath:[CCUtility getDirectoryProviderStorageOcId:metadata.ocId] error:nil];
        } else {
            // Add Local
            (void)[[NCManageDatabase sharedInstance] addLocalFileWithMetadata:metadata];
        }
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_uploadedFile object:nil userInfo:@{@"metadata": metadata, @"errorCode": @(errorCode), @"errorDescription": errorMessage}];
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_reloadDataSource object:nil userInfo:@{@"ocId": metadata.ocId,@"serverUrl": metadata.serverUrl}];
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

@end
