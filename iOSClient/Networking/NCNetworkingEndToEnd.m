//
//  NCNetworkingEndToEnd.m
//  Nextcloud
//
//  Created by Marino Faggiana on 29/10/17.
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

#import "NCNetworkingEndToEnd.h"
#import "OCNetworking.h"
#import "CCUtility.h"
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
#pragma mark ===== End-to-End Encryption NETWORKING =====
#pragma --------------------------------------------------------------------------------------------

- (void)getEndToEndPublicKeyWithAccount:(NSString *)account completion:(void (^)(NSString *account, NSString *publicKey, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getEndToEndPublicKeys:[tableAccount.url stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *publicKey, NSString *redirectedServer) {
        
        completion(account, publicKey, nil, 0);
        
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

- (void)getEndToEndPrivateKeyCipherWithAccount:(NSString *)account completion:(void (^)(NSString *account, NSString *privateKeyChiper, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getEndToEndPrivateKeyCipher:[tableAccount.url stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *privateKeyChiper, NSString *redirectedServer) {
        
        completion(account, privateKeyChiper, nil, 0);
        
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

- (void)signEndToEndPublicKeyWithAccount:(NSString *)account publicKey:(NSString *)publicKey completion:(void (^)(NSString *account, NSString *publicKey, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication signEndToEndPublicKey:[tableAccount.url stringByAppendingString:@"/"] publicKey:[CCUtility URLEncodeStringFromString:publicKey] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *publicKey, NSString *redirectedServer) {
        
        completion(account, publicKey, nil, 0);
        
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

- (void)storeEndToEndPrivateKeyCipherWithAccount:(NSString *)account privateKeyString:(NSString *)privateKeyString privateKeyChiper:(NSString *)privateKeyChiper completion:(void (^)(NSString *account, NSString *privateKeyString, NSString *privateKey, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication storeEndToEndPrivateKeyCipher:[tableAccount.url stringByAppendingString:@"/"] privateKeyChiper:[CCUtility URLEncodeStringFromString:privateKeyChiper] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *privateKey, NSString *redirectedServer) {
        
        completion(account, privateKeyString, privateKeyChiper, nil, 0);
        
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
        
        completion(account, nil, nil, message, errorCode);
    }];
}

- (void)deleteEndToEndPublicKeyWithAccount:(NSString *)account completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication deleteEndToEndPublicKey:[tableAccount.url stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        completion(account, nil ,0);
        
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

- (void)deleteEndToEndPrivateKeyWithAccount:(NSString *)account completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication deleteEndToEndPrivateKey:[tableAccount.url stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
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

- (void)getEndToEndServerPublicKeyWithAccount:(NSString *)account completion:(void (^)(NSString *account, NSString *publicKey, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getEndToEndServerPublicKey:[tableAccount.url stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *publicKey, NSString *redirectedServer) {
        
        completion(account, publicKey, nil, 0);
        
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

- (void)createEndToEndFolder:(NSString *)folderPathName account:(NSString *)account user:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url encrypted:(BOOL)encrypted ocId:(NSString **)ocId fileId:(NSString **)fileId error:(NSError **)error
{
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    __block NSError *returnError = nil;
    __block NSString *returnFileId = nil;
    __block NSString *returnOcId = nil;

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication readFile:folderPathName onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer) {
        
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        [communication createFolder:folderPathName onCommunication:communication withForbiddenCharactersSupported:YES successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
            
            NSDictionary *fields = [response allHeaderFields];
            returnOcId = [CCUtility removeForbiddenCharactersFileSystem:[fields objectForKey:@"OC-FileId"]];
            NSArray *components = [returnOcId componentsSeparatedByString:@"oc"];
            NSInteger numFileId = [components.firstObject intValue];
            returnFileId = [@(numFileId) stringValue];
            
            if (encrypted) {
                
                // MARK
                [communication markEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileId:returnFileId onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
                    
                    [[NCManageDatabase sharedInstance] clearDateReadWithServerUrl:[CCUtility deletingLastPathComponentFromServerUrl:folderPathName] account:account];
                    dispatch_semaphore_signal(semaphore);
                    
                } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
                    
                    returnError = [self getError:response error:error descriptionDefault:@"_e2e_error_mark_folder_"];
                    dispatch_semaphore_signal(semaphore);
                }];
                
            } else {
                
                [[NCManageDatabase sharedInstance] clearDateReadWithServerUrl:[CCUtility deletingLastPathComponentFromServerUrl:folderPathName] account:account];
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
    
    *ocId = returnOcId;
    *fileId = returnFileId;
    *error = returnError;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== E2EE End-to-End Encryption =====
#pragma --------------------------------------------------------------------------------------------
// E2EE


- (NSError *)getEndToEndMetadata:(NSString **)metadata fileId:(NSString *)fileId user:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url
{
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    __block NSError *returnError = nil;
    __block NSString *returnMetadata = nil;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getEndToEndMetadata:[url stringByAppendingString:@"/"] fileId:fileId onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *encryptedMetadata, NSString *redirectedServer) {
        
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
