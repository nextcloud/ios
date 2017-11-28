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
#import "NCBridgeSwift.h"

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
        returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:httpResponse.statusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Upload file error %lu", (unsigned long)httpResponse.statusCode] forKey:NSLocalizedDescriptionKey]];
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
        
        returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Check server error %lu", (unsigned long)response.statusCode] forKey:NSLocalizedDescriptionKey]];
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    return returnError;
}

- (NSError *)readFile:(NSString *)filePathName user:(NSString *)user userID:(NSString *)userID password:(NSString *)password items:(NSArray  **)items
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    __block NSError *returnError = nil;
    __block NSArray *returnItems = nil;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser: user andUserID: userID andPassword: password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication readFile:filePathName onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer) {
        
        returnItems = items;
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Read file error %lu", (long) response.statusCode] forKey:NSLocalizedDescriptionKey]];
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    *items = returnItems;
    return returnError;
}

- (NSError *)readFolder:(NSString *)serverUrl user:(NSString *)user userID:(NSString *)userID password:(NSString *)password items:(NSArray  **)items
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;

    __block NSError *returnError = nil;
    __block NSArray *returnItems = nil;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication readFolder:serverUrl depth:0 withUserSessionToken:nil onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer, NSString *token) {
        
        returnItems = items;
        dispatch_semaphore_signal(semaphore);

    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *token, NSString *redirectedServer) {

        returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Read folder error %lu", (unsigned long)response.statusCode] forKey:NSLocalizedDescriptionKey]];
        dispatch_semaphore_signal(semaphore);

    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    *items = returnItems;
    return returnError;
}

- (NSError *)createFolderAutomaticUpload:(NSString *)folderPathName user:(NSString *)user userID:(NSString *)userID password:(NSString *)password
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    __block NSError *returnError = nil;

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication readFile:folderPathName onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer) {
        
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        [communication createFolder:folderPathName onCommunication:communication withForbiddenCharactersSupported:YES successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
            
            [[NCManageDatabase sharedInstance] clearDateReadWithServerUrl:[CCUtility deletingLastPathComponentFromServerUrl:folderPathName] directoryID:nil];
            dispatch_semaphore_signal(semaphore);
            
        } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
            
            returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Read folder error %lu", (unsigned long)response.statusCode] forKey:NSLocalizedDescriptionKey]];
            dispatch_semaphore_signal(semaphore);
            
        } errorBeforeRequest:^(NSError *error) {
            
            returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Read folder error %lu", (unsigned long)response.statusCode] forKey:NSLocalizedDescriptionKey]];
            dispatch_semaphore_signal(semaphore);

        }];
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    return returnError;
}
#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== End-to-End Encryption =====
#pragma --------------------------------------------------------------------------------------------
// E2E

- (NSError *)markEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl token:(NSString  **)token
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    __block NSError *returnError = nil;
    __block NSString *returnToken = *token;

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    // Read Folder
    [communication readFolder:serverUrl depth:@"1" withUserSessionToken:nil onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer, NSString *tokenReadFolder) {
    
        if (items.count > 1) {
            
            returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:999 userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"The directory is not empty", nil) forKey:NSLocalizedDescriptionKey]];
            dispatch_semaphore_signal(semaphore);
            return;
        }
        
        // LOCK
        [communication lockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:returnToken onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *token, NSString *redirectedServer) {
        
            returnToken = token;
            [[NCManageDatabase sharedInstance] setDirectoryE2ETokenLockWithFileID:fileID token:returnToken];

            // REMOVE METADATA
            [communication deleteEndToEndMetadata:[url stringByAppendingString:@"/"] fileID:fileID onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                NSLog(@"Found metadata and delete");
            } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                NSLog(@"%@", [NSString stringWithFormat:@"Remove metadata error %lu", (unsigned long)response.statusCode]);
            }];
        
            // MARK
            [communication markEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
            
                // UNLOCK
                [communication unlockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:returnToken onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                
                    returnToken = nil;
                    [[NCManageDatabase sharedInstance] setDirectoryE2ETokenLockWithFileID:fileID token:@""];
                    dispatch_semaphore_signal(semaphore);
                
                } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                
                    returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Unlock folder error %lu", (unsigned long)response.statusCode] forKey:NSLocalizedDescriptionKey]];
                    dispatch_semaphore_signal(semaphore);
                }];
            
            } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
            
                returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Mark folder as encrypted error %lu", (unsigned long)response.statusCode] forKey:NSLocalizedDescriptionKey]];
                dispatch_semaphore_signal(semaphore);
            }];
        
        } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
            returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Lock folder error %lu", (unsigned long)response.statusCode] forKey:NSLocalizedDescriptionKey]];
            dispatch_semaphore_signal(semaphore);
        }];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *token, NSString *redirectedServer) {
        
        returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Read folder error %lu", (unsigned long)response.statusCode] forKey:NSLocalizedDescriptionKey]];
        dispatch_semaphore_signal(semaphore);
        
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    *token = returnToken;
    return returnError;
}

- (NSError *)deletemarkEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl token:(NSString  **)token
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    __block NSError *returnError = nil;
    __block NSString *returnToken = *token;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    // Read Folder
    [communication readFolder:serverUrl depth:@"1" withUserSessionToken:nil onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer, NSString *tokenReadFolder) {
        
        if (items.count > 1) {
            
            returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:999 userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"The directory is not empty", nil) forKey:NSLocalizedDescriptionKey]];
            dispatch_semaphore_signal(semaphore);
            return;
        }
        
        // LOCK
        [communication lockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:returnToken onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *token, NSString *redirectedServer) {
        
            returnToken = token;
            [[NCManageDatabase sharedInstance] setDirectoryE2ETokenLockWithFileID:fileID token:returnToken];
        
            // DELETE METADATA
            [communication deleteEndToEndMetadata:[url stringByAppendingString:@"/"] fileID:fileID onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                NSLog(@"Found metadata and delete");
            } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                NSLog(@"%@", [NSString stringWithFormat:@"Remove metadata error %lu", (unsigned long)response.statusCode]);
            }];
        
            // DELETE MARK
            [communication deletemarkEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
            
                // UNLOCK
                [communication unlockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:returnToken onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                
                    returnToken = nil;
                    [[NCManageDatabase sharedInstance] setDirectoryE2ETokenLockWithFileID:fileID token:@""];
                    dispatch_semaphore_signal(semaphore);
                
                } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                
                    returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Unlock folder error %lu", (unsigned long)response.statusCode] forKey:NSLocalizedDescriptionKey]];
                    dispatch_semaphore_signal(semaphore);
                }];
            
            } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
            
                returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Delete mark folder as encrypted error %lu", (unsigned long)response.statusCode] forKey:NSLocalizedDescriptionKey]];
                dispatch_semaphore_signal(semaphore);
            }];
        
        
        } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
            returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Lock folder error %lu", (unsigned long)response.statusCode] forKey:NSLocalizedDescriptionKey]];
            dispatch_semaphore_signal(semaphore);
        }];
    
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *token, NSString *redirectedServer) {
    
        returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Read folder error %lu", (unsigned long)response.statusCode] forKey:NSLocalizedDescriptionKey]];
        dispatch_semaphore_signal(semaphore);
    
    }];

    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    *token = returnToken;
    return returnError;
}

- (NSError *)getEndToEndMetadata:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID metadata:(NSString **)metadata
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    __block NSError *returnError = nil;
    __block NSString *returnMetadata = nil;

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getEndToEndMetadata:[url stringByAppendingString:@"/"] fileID:fileID onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *encryptedMetadata, NSString *redirectedServer) {
        
        returnMetadata = encryptedMetadata;
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Get metadata error %lu", (unsigned long)response.statusCode] forKey:NSLocalizedDescriptionKey]];
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    *metadata = returnMetadata;
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
        [[NCManageDatabase sharedInstance] setDirectoryE2ETokenLockWithFileID:fileID token:returnToken];
        
        // STORE METADATA
        [communication storeEndToEndMetadata:[url stringByAppendingString:@"/"] fileID:fileID encryptedMetadata:metadata onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *encryptedMetadata, NSString *redirectedServer) {
            
            // UNLOCK
            [communication unlockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:returnToken onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                
                returnToken = nil;
                [[NCManageDatabase sharedInstance] setDirectoryE2ETokenLockWithFileID:fileID token:@""];
                dispatch_semaphore_signal(semaphore);
                
            } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                
                returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Unlock folder error %lu", (unsigned long)response.statusCode] forKey:NSLocalizedDescriptionKey]];
                dispatch_semaphore_signal(semaphore);
            }];
            
        } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
            
            returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Store metadata error %lu", (unsigned long)response.statusCode] forKey:NSLocalizedDescriptionKey]];
            dispatch_semaphore_signal(semaphore);
        }];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Lock folder error %lu", (unsigned long)response.statusCode] forKey:NSLocalizedDescriptionKey]];
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
        [[NCManageDatabase sharedInstance] setDirectoryE2ETokenLockWithFileID:fileID token:returnToken];
        
        // UPDATA METADATA
        [communication updateEndToEndMetadata:[url stringByAppendingString:@"/"] fileID:fileID encryptedMetadata:metadata token:returnToken onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *encryptedMetadata, NSString *redirectedServer) {
            
            // UNLOCK
            [communication unlockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:returnToken onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                
                returnToken = nil;
                [[NCManageDatabase sharedInstance] setDirectoryE2ETokenLockWithFileID:fileID token:@""];
                dispatch_semaphore_signal(semaphore);
                
            } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                
                returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Unlock folder error %lu", (unsigned long)response.statusCode] forKey:NSLocalizedDescriptionKey]];
                dispatch_semaphore_signal(semaphore);
            }];
            
        } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
            
            returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Update metadata error %lu", (unsigned long)response.statusCode] forKey:NSLocalizedDescriptionKey]];
            dispatch_semaphore_signal(semaphore);
        }];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Lock folder error %lu", (unsigned long)response.statusCode] forKey:NSLocalizedDescriptionKey]];
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    *token = returnToken;
    return returnError;
}

- (NSError *)rebuildEndToEndMetadata:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID metadata:(NSString *)metadata token:(NSString  **)token
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
        [[NCManageDatabase sharedInstance] setDirectoryE2ETokenLockWithFileID:fileID token:returnToken];
        
        // DELETE METADATA
        [communication deleteEndToEndMetadata:[url stringByAppendingString:@"/"] fileID:fileID onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
            
            // STORE METADATA
            [communication storeEndToEndMetadata:[url stringByAppendingString:@"/"] fileID:fileID encryptedMetadata:metadata onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *encryptedMetadata, NSString *redirectedServer) {
                
                // UNLOCK
                [communication unlockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:returnToken onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                    
                    returnToken = nil;
                    [[NCManageDatabase sharedInstance] setDirectoryE2ETokenLockWithFileID:fileID token:@""];
                    dispatch_semaphore_signal(semaphore);
                    
                } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                    
                    returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Unlock folder error %lu", (unsigned long)response.statusCode] forKey:NSLocalizedDescriptionKey]];
                    dispatch_semaphore_signal(semaphore);
                }];
                
            } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                
                returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Store metadata error %lu", (unsigned long)response.statusCode] forKey:NSLocalizedDescriptionKey]];
                dispatch_semaphore_signal(semaphore);
            }];
            
        } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
            
            returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Update metadata error %lu", (unsigned long)response.statusCode] forKey:NSLocalizedDescriptionKey]];
            dispatch_semaphore_signal(semaphore);
        }];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Lock folder error %lu", (unsigned long)response.statusCode] forKey:NSLocalizedDescriptionKey]];
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    return returnError;
}

@end
