//
//  NCNetworkingEndToEnd.m
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 29/10/17.
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

#import "NCNetworkingEndToEnd.h"
#import "CCUtility.h"
#import "CCCertificate.h"
#import "NCBridgeSwift.h"

/*********************************************************************************
 
 Netwok call synchronous mode, use this only from :
 
 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
 });
 
*********************************************************************************/

@implementation NCNetworkingEndToEnd

+ (NCNetworkingEndToEnd *)sharedManager {
    static NCNetworkingEndToEnd *sharedManager;
    @synchronized(self)
    {
        if (!sharedManager) {
            sharedManager = [NCNetworkingEndToEnd new];
        }
        return sharedManager;
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ============================
#pragma --------------------------------------------------------------------------------------------

- (void)createEndToEndFolder:(NSString *)folderPathName user:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url encrypted:(BOOL)encrypted fileID:(NSString **)fileID error:(NSError **)error
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    __block NSError *returnError = nil;
    __block NSString *returnFileID = nil;

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication readFile:folderPathName onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer) {
        
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        [communication createFolder:folderPathName onCommunication:communication withForbiddenCharactersSupported:YES successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
            
            NSDictionary *fields = [response allHeaderFields];
            returnFileID = [CCUtility removeForbiddenCharactersFileSystem:[fields objectForKey:@"OC-FileId"]];
            
            if (encrypted) {
                
                // MARK
                [communication markEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:returnFileID onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                    
                    [[NCManageDatabase sharedInstance] clearDateReadWithServerUrl:[CCUtility deletingLastPathComponentFromServerUrl:folderPathName] directoryID:nil];
                    dispatch_semaphore_signal(semaphore);
                    
                } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                    
                    returnError = [self getError:response error:error descriptionDefault:@"_e2e_error_mark_folder_"];
                    dispatch_semaphore_signal(semaphore);
                }];
                
            } else {
                
                [[NCManageDatabase sharedInstance] clearDateReadWithServerUrl:[CCUtility deletingLastPathComponentFromServerUrl:folderPathName] directoryID:nil];
                dispatch_semaphore_signal(semaphore);
            }
            
        } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
            
            returnError = [self getError:response error:error descriptionDefault:@"_error_"];
            dispatch_semaphore_signal(semaphore);
            
        } errorBeforeRequest:^(NSError *error) {
            
            returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:response.statusCode userInfo:[NSDictionary dictionaryWithObject:response.description forKey:NSLocalizedDescriptionKey]];
            dispatch_semaphore_signal(semaphore);

        }];
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    *fileID = returnFileID;
    *error = returnError;
}
#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== E2EE End-to-End Encryption =====
#pragma --------------------------------------------------------------------------------------------
// E2EE

- (NSError *)markEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    __block NSError *returnError = nil;

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    tableE2eEncryptionLock *tableLock = [[NCManageDatabase sharedInstance] getE2ETokenLockWithServerUrl:serverUrl];

    // Read Folder
    [communication readFolder:serverUrl depth:@"1" withUserSessionToken:nil onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer, NSString *tokenReadFolder) {
    
        if (items.count > 1) {
            
            returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:999 userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"_e2e_error_directory_not_empty_", nil) forKey:NSLocalizedDescriptionKey]];
            dispatch_semaphore_signal(semaphore);
            return;
        }
        
        // LOCK
        [communication lockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:tableLock.token onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *token, NSString *redirectedServer) {
        
            [[NCManageDatabase sharedInstance] setE2ETokenLockWithServerUrl:serverUrl fileID:fileID token:token];
            
            // REMOVE METADATA
            [communication deleteEndToEndMetadata:[url stringByAppendingString:@"/"] fileID:fileID onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                NSLog(@"[LOG] Found metadata and delete");
            } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                NSLog(@"[LOG] %@", [NSString stringWithFormat:@"Remove metadata error %d", (int)response.statusCode]);
            }];
        
            // MARK
            [communication markEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
            
                // UNLOCK
                [communication unlockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:token onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                    [[NCManageDatabase sharedInstance] deteleE2ETokenLockWithServerUrl:serverUrl];
                    dispatch_semaphore_signal(semaphore);
                } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                    returnError = [self getError:response error:error descriptionDefault:@"_e2e_error_unlock_"];
                    dispatch_semaphore_signal(semaphore);
                }];
            
            } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
            
                returnError = [self getError:response error:error descriptionDefault:@"_e2e_error_mark_folder_"];

                // UNLOCK
                [communication unlockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:token onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                    [[NCManageDatabase sharedInstance] deteleE2ETokenLockWithServerUrl:serverUrl];
                    dispatch_semaphore_signal(semaphore);
                } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                    returnError = [self getError:response error:error descriptionDefault:@"_e2e_error_unlock_"];
                    dispatch_semaphore_signal(semaphore);
                }];
            }];
        
        } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
            returnError = [self getError:response error:error descriptionDefault:@"_e2e_error_lock_"];
            dispatch_semaphore_signal(semaphore);
        }];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *token, NSString *redirectedServer) {
        
        returnError = [self getError:response error:error descriptionDefault:@"_error_"];
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    return returnError;
}

- (NSError *)deletemarkEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    __block NSError *returnError = nil;

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    tableE2eEncryptionLock *tableLock = [[NCManageDatabase sharedInstance] getE2ETokenLockWithServerUrl:serverUrl];

    // Read Folder
    [communication readFolder:serverUrl depth:@"1" withUserSessionToken:nil onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer, NSString *tokenReadFolder) {
        
        if (items.count > 1) {
            
            returnError = [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:999 userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"_e2e_error_directory_not_empty_", nil) forKey:NSLocalizedDescriptionKey]];
            dispatch_semaphore_signal(semaphore);
            return;
        }
        
        // LOCK
        [communication lockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:tableLock.token onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *token, NSString *redirectedServer) {
        
            [[NCManageDatabase sharedInstance] setE2ETokenLockWithServerUrl:serverUrl fileID:fileID token:token];
            
            // DELETE METADATA
            [communication deleteEndToEndMetadata:[url stringByAppendingString:@"/"] fileID:fileID onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                NSLog(@"[LOG] Found metadata and delete");
            } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                NSLog(@"[LOG] %@", [NSString stringWithFormat:@"Remove metadata error %d", (int)response.statusCode]);
            }];
        
            // DELETE MARK
            [communication deletemarkEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
            
                // UNLOCK
                [communication unlockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:token onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                    [[NCManageDatabase sharedInstance] deteleE2ETokenLockWithServerUrl:serverUrl];
                    dispatch_semaphore_signal(semaphore);
                } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                    returnError = [self getError:response error:error descriptionDefault:@"_e2e_error_unlock_"];
                    dispatch_semaphore_signal(semaphore);
                }];
            
            } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
            
                returnError = [self getError:response error:error descriptionDefault:@"_e2e_error_delete_mark_folder_"];

                // UNLOCK
                [communication unlockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:token onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                    [[NCManageDatabase sharedInstance] deteleE2ETokenLockWithServerUrl:serverUrl];
                    dispatch_semaphore_signal(semaphore);
                } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                    returnError = [self getError:response error:error descriptionDefault:@"_e2e_error_unlock_"];
                    dispatch_semaphore_signal(semaphore);
                }];
            }];
        
        } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
            returnError = [self getError:response error:error descriptionDefault:@"_e2e_error_lock_"];
            dispatch_semaphore_signal(semaphore);
        }];
    
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *token, NSString *redirectedServer) {
        
        returnError = [self getError:response error:error descriptionDefault:@"_error_"];
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
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
        
        returnError = [self getError:response error:error descriptionDefault:@"_e2e_error_get_metadata_"];
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    *metadata = returnMetadata;
    return returnError;
}

- (NSError *)deleteEndToEndMetadata:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url serverUrl:(NSString *)serverUrl fileID:(NSString *)fileID unlock:(BOOL)unlock
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    __block NSError *returnError = nil;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    tableE2eEncryptionLock *tableLock = [[NCManageDatabase sharedInstance] getE2ETokenLockWithServerUrl:serverUrl];

    // LOCK
    [communication lockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:tableLock.token onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *token, NSString *redirectedServer) {
            
        [[NCManageDatabase sharedInstance] setE2ETokenLockWithServerUrl:serverUrl fileID:fileID token:token];
            
        // DELETE METADATA
        [communication deleteEndToEndMetadata:[url stringByAppendingString:@"/"] fileID:fileID onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                
            // UNLOCK
            if (unlock) {
                [communication unlockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:token onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                    [[NCManageDatabase sharedInstance] deteleE2ETokenLockWithServerUrl:serverUrl];
                    dispatch_semaphore_signal(semaphore);
                } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                    returnError = [self getError:response error:error descriptionDefault:@"_e2e_error_unlock_"];
                    dispatch_semaphore_signal(semaphore);
                }];
            } else {
                dispatch_semaphore_signal(semaphore);
            }
                
        } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                
            returnError = [self getError:response error:error descriptionDefault:@"_e2e_error_delete_metadata_"];

            // UNLOCK
            [communication unlockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:token onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                [[NCManageDatabase sharedInstance] deteleE2ETokenLockWithServerUrl:serverUrl];
                dispatch_semaphore_signal(semaphore);
            } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                returnError = [self getError:response error:error descriptionDefault:@"_e2e_error_unlock_"];
                dispatch_semaphore_signal(semaphore);
            }];
        }];
            
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        returnError = [self getError:response error:error descriptionDefault:@"_e2e_error_lock_"];
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    return returnError;
}

- (NSError *)storeEndToEndMetadata:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url serverUrl:(NSString *)serverUrl fileID:(NSString *)fileID metadata:(NSString *)metadata unlock:(BOOL)unlock
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    __block NSError *returnError = nil;

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    tableE2eEncryptionLock *tableLock = [[NCManageDatabase sharedInstance] getE2ETokenLockWithServerUrl:serverUrl];

    // LOCK
    [communication lockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:tableLock.token onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *token, NSString *redirectedServer) {
        
        [[NCManageDatabase sharedInstance] setE2ETokenLockWithServerUrl:serverUrl fileID:fileID token:token];
        
        // STORE METADATA
        [communication storeEndToEndMetadata:[url stringByAppendingString:@"/"] fileID:fileID encryptedMetadata:metadata onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *encryptedMetadata, NSString *redirectedServer) {
            
            // UNLOCK
            if (unlock) {
                [communication unlockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:token onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                    [[NCManageDatabase sharedInstance] deteleE2ETokenLockWithServerUrl:serverUrl];
                    dispatch_semaphore_signal(semaphore);
                } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                    returnError = [self getError:response error:error descriptionDefault:@"_e2e_error_unlock_"];
                    dispatch_semaphore_signal(semaphore);
                }];
            } else {
                dispatch_semaphore_signal(semaphore);
            }
                
        } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
            
            returnError = [self getError:response error:error descriptionDefault:@"_e2e_error_store_metadata_"];

            // UNLOCK
            [communication unlockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:token onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                [[NCManageDatabase sharedInstance] deteleE2ETokenLockWithServerUrl:serverUrl];
                dispatch_semaphore_signal(semaphore);
            } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                returnError = [self getError:response error:error descriptionDefault:@"_e2e_error_unlock_"];
                dispatch_semaphore_signal(semaphore);
            }];
        }];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        returnError = [self getError:response error:error descriptionDefault:@"_e2e_error_lock_"];
        dispatch_semaphore_signal(semaphore);
    }];

    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    return returnError;
}

- (NSError *)updateEndToEndMetadata:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url serverUrl:(NSString *)serverUrl fileID:(NSString *)fileID metadata:(NSString *)metadata unlock:(BOOL)unlock
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    __block NSError *returnError = nil;

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    tableE2eEncryptionLock *tableLock = [[NCManageDatabase sharedInstance] getE2ETokenLockWithServerUrl:serverUrl];

    // LOCK
    [communication lockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:tableLock.token onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *token, NSString *redirectedServer) {
        
        [[NCManageDatabase sharedInstance] setE2ETokenLockWithServerUrl:serverUrl fileID:fileID token:token];
        
        // UPDATA METADATA
        [communication updateEndToEndMetadata:[url stringByAppendingString:@"/"] fileID:fileID encryptedMetadata:metadata token:token onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *encryptedMetadata, NSString *redirectedServer) {
            
            // UNLOCK
            if (unlock) {
                [communication unlockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:token onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                    [[NCManageDatabase sharedInstance] deteleE2ETokenLockWithServerUrl:serverUrl];
                    dispatch_semaphore_signal(semaphore);
                } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                    returnError = [self getError:response error:error descriptionDefault:@"_e2e_error_unlock_"];
                    dispatch_semaphore_signal(semaphore);
                }];
            } else {
                dispatch_semaphore_signal(semaphore);
            }
                
        } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
            returnError = [self getError:response error:error descriptionDefault:@"_e2e_error_update_metadata_"];

            // UNLOCK
            [communication unlockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:token onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                [[NCManageDatabase sharedInstance] deteleE2ETokenLockWithServerUrl:serverUrl];
                dispatch_semaphore_signal(semaphore);
            } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                returnError = [self getError:response error:error descriptionDefault:@"_e2e_error_unlock_"];
                dispatch_semaphore_signal(semaphore);
            }];
        }];
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        returnError = [self getError:response error:error descriptionDefault:@"_e2e_error_lock_"];
        dispatch_semaphore_signal(semaphore);
    }];

    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    return returnError;
}

- (NSError *)lockEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url serverUrl:(NSString *)serverUrl fileID:(NSString *)fileID
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    __block NSError *returnError = nil;

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    tableE2eEncryptionLock *tableLock = [[NCManageDatabase sharedInstance] getE2ETokenLockWithServerUrl:serverUrl];
    
    // LOCK
    [communication lockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:tableLock.token onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *token, NSString *redirectedServer) {
        
        [[NCManageDatabase sharedInstance] setE2ETokenLockWithServerUrl:serverUrl fileID:fileID token:token];
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        returnError = [self getError:response error:error descriptionDefault:@"_e2e_error_lock_"];
        dispatch_semaphore_signal(semaphore);
    }];

    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    return returnError;
}

- (NSError *)unlockEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url serverUrl:(NSString *)serverUrl fileID:(NSString *)fileID token:(NSString  *)token
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    
    __block NSError *returnError = nil;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    // UNLOCK
    [communication unlockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:token onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        [[NCManageDatabase sharedInstance] deteleE2ETokenLockWithServerUrl:serverUrl];
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        returnError = [self getError:response error:error descriptionDefault:@"_e2e_error_unlock_"];
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    return returnError;
}

- (NSError *)sendEndToEndMetadataOnServerUrl:(NSString *)serverUrl account:(NSString *)account user:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileNameRename:(NSString *)fileName fileNameNewRename:(NSString *)fileNameNew
{
    tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND serverUrl = %@", account, serverUrl]];
    
    NSString *metadata;
    NSError *error;
    
    // Enabled E2E
    if ([CCUtility isEndToEndEnabled:account] == NO)
        return [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:k_CCErrorInternalError userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"_e2e_error_not_enabled_", nil) forKey:NSLocalizedDescriptionKey]];
    
    // get Metadata for select updateEndToEndMetadata or storeEndToEndMetadata
    error = [self getEndToEndMetadata:user userID:userID password:password url:url fileID:directory.fileID metadata:&metadata];
    if (error.code != 404 && error != nil) {
        return error;
    }
    
    // Rename
    if (fileName && fileNameNew)
        [[NCManageDatabase sharedInstance] renameFileE2eEncryptionWithServerUrl:serverUrl fileNameIdentifier:fileName newFileName:fileNameNew newFileNamePath:[CCUtility returnFileNamePathFromFileName:fileNameNew serverUrl:serverUrl activeUrl:url]];

    NSArray *tableE2eEncryption = [[NCManageDatabase sharedInstance] getE2eEncryptionsWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND serverUrl = %@", account, serverUrl]];
    if (!tableE2eEncryption)
        return [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:k_CCErrorInternalError userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"_e2e_error_record_not_found_", nil) forKey:NSLocalizedDescriptionKey]];
    
    NSString *e2eMetadataJSON = [[NCEndToEndMetadata sharedInstance] encoderMetadata:tableE2eEncryption privateKey:[CCUtility getEndToEndPrivateKey:account] serverUrl:serverUrl];
    if (!e2eMetadataJSON)
        return [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:k_CCErrorInternalError userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"_e2e_error_encode_metadata_", nil) forKey:NSLocalizedDescriptionKey]];
    
    // send Metadata
    if (error == nil)
        error = [self updateEndToEndMetadata:user userID:userID password:password url:url serverUrl:serverUrl fileID:directory.fileID metadata:e2eMetadataJSON unlock:NO];
    else if (error.code == 404)
        error = [self storeEndToEndMetadata:user userID:userID password:password url:url serverUrl:serverUrl fileID:directory.fileID metadata:e2eMetadataJSON unlock:NO];
    
    return error;
}

- (NSError *)rebuildAndSendEndToEndMetadataOnServerUrl:(NSString *)serverUrl account:(NSString *)account user:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url
{
    NSError *error;
    NSString *e2eMetadataJSON;
    
    tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND serverUrl = %@", account, serverUrl]];
    if (directory.e2eEncrypted == NO)
        return nil;
    
    NSArray *tableE2eEncryption = [[NCManageDatabase sharedInstance] getE2eEncryptionsWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND serverUrl = %@", account, serverUrl]];
    if (tableE2eEncryption) {
        
        e2eMetadataJSON = [[NCEndToEndMetadata sharedInstance] encoderMetadata:tableE2eEncryption privateKey:[CCUtility getEndToEndPrivateKey:account] serverUrl:serverUrl];
        if (!e2eMetadataJSON)
            return [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:k_CCErrorInternalError userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"_e2e_error_encode_metadata_", nil) forKey:NSLocalizedDescriptionKey]];
        
        error = [self updateEndToEndMetadata:user userID:userID password:password url:url serverUrl:serverUrl fileID:directory.fileID metadata:e2eMetadataJSON unlock:YES];
    
    } else {
    
        [self deleteEndToEndMetadata:user userID:userID password:password url:url serverUrl:serverUrl fileID:directory.fileID unlock:YES];
    }
    
    return error;
}

- (NSError *)getError:(NSHTTPURLResponse *)response error:(NSError *)error descriptionDefault:(NSString *)descriptionDefault
{
    NSInteger errorCode = response.statusCode;
    NSString *errorDescription = response.description;
    
    if (errorDescription == nil || errorCode == 0) {
        errorCode = error.code;
        errorDescription = error.description;
        if (errorDescription == nil) errorDescription = NSLocalizedString(descriptionDefault, @"");
    }
    
    errorDescription = [NSString stringWithFormat:@"%@ [%ld] - %@", NSLocalizedString(descriptionDefault, @""), (long)errorCode, errorDescription];

    if (errorDescription.length >= 250) {
        errorDescription = [errorDescription substringToIndex:250];
        errorDescription = [errorDescription stringByAppendingString:@" ..."];
    }
    
    return [NSError errorWithDomain:@"com.nextcloud.nextcloud" code:errorCode userInfo:[NSDictionary dictionaryWithObject:errorDescription forKey:NSLocalizedDescriptionKey]];
}

@end
