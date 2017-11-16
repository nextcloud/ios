//
//  NCNetworkingSync.m
//  Nextcloud
//
//  Created by Marino Faggiana on 29/10/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "NCNetworkingSync.h"
#import "CCUtility.h"
#import "CCCertificate.h"

@implementation NCNetworkingSync

+ (NCNetworkingSync *)sharedManager {
    static NCNetworkingSync *sharedManager;
    @synchronized(self)
    {
        if (!sharedManager) {
            sharedManager = [NCNetworkingSync new];
        }
        return sharedManager;
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ============================
#pragma --------------------------------------------------------------------------------------------

- (NSError *)uploadFile:(NSString *)localFilePathName remoteFilePathName:(NSString *)remoteFilePathName user:(NSString *)user userID:(NSString *)userID password:(NSString *)password
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    __block NSError *returnError = nil;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication uploadFileSession:localFilePathName toDestiny:remoteFilePathName onCommunication:communication progress:^(NSProgress *progress) {
        // Progress
    } successRequest:^(NSURLResponse *response, NSString *redirectedServer) {
        
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSURLResponse *response, NSString *redirectedServer, NSError *error) {
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
        
        returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:httpResponse.statusCode userInfo:[NSDictionary dictionaryWithObject:@"Upload file error" forKey:NSLocalizedDescriptionKey]];
        dispatch_semaphore_signal(semaphore);

    } failureBeforeRequest:^(NSError *error) {
        
        returnError = error;
        dispatch_semaphore_signal(semaphore);

    }];
     
     while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
         [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
     
     return returnError;
}

- (NSError *)checkServer:(NSString *)serverUrl user:(NSString *)user userID:(NSString *)userID password:(NSString *)password
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    __block NSError *returnError = nil;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication checkServer:serverUrl onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:@"Check server error" forKey:NSLocalizedDescriptionKey]];
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    return returnError;
}

- (NSError *)readFile:(NSString *)filePathName user:(NSString *)user userID:(NSString *)userID password:(NSString *)password
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    __block NSError *returnError = nil;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser: user andUserID: userID andPassword: password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication readFile:filePathName onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer) {
        
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:@"Read file error" forKey:NSLocalizedDescriptionKey]];
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    return returnError;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== End-to-End Encryption =====
#pragma --------------------------------------------------------------------------------------------

- (NSError *)markEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID token:(NSString  **)token
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    __block NSError *returnError = nil;
    __block NSString *returnToken = nil;

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    // LOCK
    [communication lockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:*token onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *token, NSString *redirectedServer) {
        
        returnToken = token;

        // MARK
        [communication markEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
            
            // UNLOCK
            [communication unlockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:returnToken onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                
                returnToken = nil;
                dispatch_semaphore_signal(semaphore);
                
            } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                
                returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:@"Unlock folder error" forKey:NSLocalizedDescriptionKey]];
                dispatch_semaphore_signal(semaphore);
            }];
            
        } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
            
            returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:@"Mark folder as encrypted error" forKey:NSLocalizedDescriptionKey]];
            dispatch_semaphore_signal(semaphore);
        }];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:@"Lock folder error" forKey:NSLocalizedDescriptionKey]];
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    *token = returnToken;
    return returnError;
}

- (NSError *)deletemarkEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID token:(NSString  **)token
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    __block NSError *returnError = nil;
    __block NSString *returnToken = nil;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    // LOCK
    [communication lockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:*token onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *token, NSString *redirectedServer) {
        
        returnToken = token;
        
        // DELETE MARK
        [communication deletemarkEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
            
            // UNLOCK
            [communication unlockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:returnToken onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                
                returnToken = nil;
                dispatch_semaphore_signal(semaphore);
                
            } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                
                returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:@"Unlock folder error" forKey:NSLocalizedDescriptionKey]];
                dispatch_semaphore_signal(semaphore);
            }];
            
        } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
            
            returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:@"Mark folder as encrypted error" forKey:NSLocalizedDescriptionKey]];
            dispatch_semaphore_signal(semaphore);
        }];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:@"Lock folder error" forKey:NSLocalizedDescriptionKey]];
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    *token = returnToken;
    return returnError;
}

- (NSError *)storeEndToEndMetadata:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID metadata:(NSString *)metadata token:(NSString  **)token
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    __block NSError *returnError = nil;
    __block NSString *returnToken = nil;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    // LOCK
    [communication lockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:*token onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *token, NSString *redirectedServer) {
        
        returnToken = token;
        
        // STORE METADATA
        [communication storeEndToEndMetadata:[url stringByAppendingString:@"/"] fileID:fileID encryptedMetadata:metadata onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *encryptedMetadata, NSString *redirectedServer) {
            
            // UNLOCK
            [communication unlockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:returnToken onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                
                returnToken = nil;
                dispatch_semaphore_signal(semaphore);
                
            } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                
                returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:@"Unlock folder error" forKey:NSLocalizedDescriptionKey]];
                dispatch_semaphore_signal(semaphore);
            }];
            
        } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
            
            returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:@"Mark folder as encrypted error" forKey:NSLocalizedDescriptionKey]];
            dispatch_semaphore_signal(semaphore);
        }];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:@"Lock folder error" forKey:NSLocalizedDescriptionKey]];
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    *token = returnToken;
    return returnError;
}

- (NSError *)updateEndToEndMetadata:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID metadata:(NSString *)metadata token:(NSString  **)token
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    __block NSError *returnError = nil;
    __block NSString *returnToken = nil;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    // LOCK
    [communication lockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:*token onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *token, NSString *redirectedServer) {
        
        returnToken = token;
        
        // UPDATA METADATA
        [communication updateEndToEndMetadata:[url stringByAppendingString:@"/"] fileID:fileID encryptedMetadata:metadata onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *encryptedMetadata, NSString *redirectedServer) {
            
            // UNLOCK
            [communication unlockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:returnToken onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                
                returnToken = nil;
                dispatch_semaphore_signal(semaphore);
                
            } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                
                returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:@"Unlock folder error" forKey:NSLocalizedDescriptionKey]];
                dispatch_semaphore_signal(semaphore);
            }];
            
        } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
            
            returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:@"Mark folder as encrypted error" forKey:NSLocalizedDescriptionKey]];
            dispatch_semaphore_signal(semaphore);
        }];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:@"Lock folder error" forKey:NSLocalizedDescriptionKey]];
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    *token = returnToken;
    return returnError;
}


- (NSError *)lockEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID token:(NSString  **)token
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    __block NSError *returnError = nil;
    __block NSString *returnToken = nil;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication lockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:*token onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *token, NSString *redirectedServer) {
        
        returnToken = token;
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:@"Lock folder error" forKey:NSLocalizedDescriptionKey]];
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    *token = returnToken;
    return returnError;
}

- (NSError *)unlockEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID token:(NSString *)token
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    __block NSError *returnError= nil;

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication unlockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:token onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:@"Unlock folder error" forKey:NSLocalizedDescriptionKey]];
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    return returnError;
}

@end
