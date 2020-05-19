//
//  OCnetworking.m
//  Nextcloud
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
#import "NSString+Encode.h"
#import "NCBridgeSwift.h"
#import "NCXMLGetAppPasswordParser.h"

@implementation OCNetworking

+ (OCNetworking *)sharedManager {
    static OCNetworking *sharedManager;
    @synchronized(self)
    {
        if (!sharedManager) {
            sharedManager = [OCNetworking new];
            sharedManager.checkRemoteUserInProgress = false;
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

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Share =====
#pragma --------------------------------------------------------------------------------------------

- (void)readShareWithAccount:(NSString *)account completion:(void (^)(NSString *account, NSArray *items, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    } else if ([CCUtility getPassword:account].length == 0) {
        completion(account, nil, NSLocalizedString(@"_bad_username_password_", nil), kOCErrorServerUnauthorized);
    } else if ([CCUtility getCertificateError:account]) {
        completion(account, nil, NSLocalizedString(@"_ssl_certificate_untrusted_", nil), NSURLErrorServerCertificateUntrusted);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    [communication readSharedByServer:[tableAccount.url stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer) {
        
        completion(account, items, nil, 0);
        
    } failureRequest :^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message;
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

- (void)readShareWithAccount:(NSString *)account path:(NSString *)path completion:(void (^)(NSString *account, NSArray *items, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    } else if ([CCUtility getPassword:account].length == 0) {
        completion(account, nil, NSLocalizedString(@"_bad_username_password_", nil), kOCErrorServerUnauthorized);
    } else if ([CCUtility getCertificateError:account]) {
        completion(account, nil, NSLocalizedString(@"_ssl_certificate_untrusted_", nil), NSURLErrorServerCertificateUntrusted);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication readSharedByServer:[tableAccount.url stringByAppendingString:@"/"] andPath:path onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *listOfShared, NSString *redirectedServer) {
        
        completion(account, listOfShared, nil, 0);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message;
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
    } else if ([CCUtility getPassword:account].length == 0) {
        completion(account, NSLocalizedString(@"_bad_username_password_", nil), kOCErrorServerUnauthorized);
    } else if ([CCUtility getCertificateError:account]) {
        completion(account, NSLocalizedString(@"_ssl_certificate_untrusted_", nil), NSURLErrorServerCertificateUntrusted);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    [communication shareFileOrFolderByServer:[tableAccount.url stringByAppendingString:@"/"] andFileOrFolderPath:[fileName encodeString:NSUTF8StringEncoding] andPassword:[password encodeString:NSUTF8StringEncoding] andPermission:permission andHideDownload:hideDownload onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *token, NSString *redirectedServer) {
        
        completion(account, nil, 0);
                
    } failureRequest :^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message;
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
    } else if ([CCUtility getPassword:account].length == 0) {
        completion(account, NSLocalizedString(@"_bad_username_password_", nil), kOCErrorServerUnauthorized);
    } else if ([CCUtility getCertificateError:account]) {
        completion(account, NSLocalizedString(@"_ssl_certificate_untrusted_", nil), NSURLErrorServerCertificateUntrusted);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    [communication shareWith:userOrGroup shareeType:shareeType inServer:[tableAccount.url stringByAppendingString:@"/"] andFileOrFolderPath:[fileName encodeString:NSUTF8StringEncoding] andPermissions:permission onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        completion(account, nil, 0);
                
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message;
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

- (void)shareUpdateAccount:(NSString *)account shareID:(NSInteger)shareID password:(NSString *)password note:(NSString *)note permission:(NSInteger)permission expirationTime:(NSString *)expirationTime hideDownload:(BOOL)hideDownload completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    } else if ([CCUtility getPassword:account].length == 0) {
        completion(account, NSLocalizedString(@"_bad_username_password_", nil), kOCErrorServerUnauthorized);
    } else if ([CCUtility getCertificateError:account]) {
        completion(account, NSLocalizedString(@"_ssl_certificate_untrusted_", nil), NSURLErrorServerCertificateUntrusted);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    [communication updateShare:shareID ofServerPath:[tableAccount.url stringByAppendingString:@"/"] withPasswordProtect:[password encodeString:NSUTF8StringEncoding] andNote:note andExpirationTime:expirationTime andPermissions:permission andHideDownload:hideDownload onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        completion(account, nil, 0);
                
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {

        NSString *message;
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
    } else if ([CCUtility getPassword:account].length == 0) {
        completion(account, NSLocalizedString(@"_bad_username_password_", nil), kOCErrorServerUnauthorized);
    } else if ([CCUtility getCertificateError:account]) {
        completion(account, NSLocalizedString(@"_ssl_certificate_untrusted_", nil), NSURLErrorServerCertificateUntrusted);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    [communication unShareFileOrFolderByServer:[tableAccount.url stringByAppendingString:@"/"] andIdRemoteShared:shareID onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        completion(account, nil, 0);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message;
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
    } else if ([CCUtility getPassword:account].length == 0) {
        completion(account, nil, NSLocalizedString(@"_bad_username_password_", nil), kOCErrorServerUnauthorized);
    } else if ([CCUtility getCertificateError:account]) {
        completion(account, nil, NSLocalizedString(@"_ssl_certificate_untrusted_", nil), NSURLErrorServerCertificateUntrusted);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    [communication searchUsersAndGroupsWith:searchString forPage:1 with:50 ofServer:[tableAccount.url stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *itemList, NSString *redirectedServer) {
        
        completion(account, itemList, nil, 0);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message;
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
#pragma mark ===== VAR =====
#pragma --------------------------------------------------------------------------------------------

- (void)getNotificationWithAccount:(NSString *)account completion:(void (^)(NSString *account, NSArray *listOfNotifications, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    } else if ([CCUtility getPassword:account].length == 0) {
        completion(account, nil, NSLocalizedString(@"_bad_username_password_", nil), kOCErrorServerUnauthorized);
    } else if ([CCUtility getCertificateError:account]) {
        completion(account, nil, NSLocalizedString(@"_ssl_certificate_untrusted_", nil), NSURLErrorServerCertificateUntrusted);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    [communication getNotificationServer:[tableAccount.url stringByAppendingString:@"/"] onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *listOfNotifications, NSString *redirectedServer) {
        
        completion(account, listOfNotifications, nil, 0);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message;
        NSInteger errorCode = response.statusCode;
        
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Server Unauthorized
        if (errorCode == kOCErrorServerUnauthorized || errorCode == kOCErrorServerForbidden) {
#ifndef EXTENSION
            [[NCNetworkingCheckRemoteUser shared] checkRemoteUserWithAccount:account];
#endif
        } else if (errorCode == NSURLErrorServerCertificateUntrusted) {
            [CCUtility setCertificateError:account error:YES];
        }
        
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
    } else if ([CCUtility getPassword:account].length == 0) {
        completion(account, NSLocalizedString(@"_bad_username_password_", nil), kOCErrorServerUnauthorized);
    } else if ([CCUtility getCertificateError:account]) {
        completion(account, NSLocalizedString(@"_ssl_certificate_untrusted_", nil), NSURLErrorServerCertificateUntrusted);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    [communication setNotificationServer:serverUrl type:type onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        completion(account, nil, 0);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message;
        NSInteger errorCode = response.statusCode;
        
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Server Unauthorized
        if (errorCode == kOCErrorServerUnauthorized || errorCode == kOCErrorServerForbidden) {
#ifndef EXTENSION
            [[NCNetworkingCheckRemoteUser shared] checkRemoteUserWithAccount:account];
#endif
        } else if (errorCode == NSURLErrorServerCertificateUntrusted) {
            [CCUtility setCertificateError:account error:YES];
        }
        
        // Error
        if (errorCode == 503) {
            message = NSLocalizedString(@"_server_error_retry_", nil);
        } else {
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        }
        
        completion(account, message, errorCode);
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
    } else if ([CCUtility getPassword:account].length == 0) {
        completion(account, nil, nil, nil, NSLocalizedString(@"_bad_username_password_", nil), kOCErrorServerUnauthorized);
    } else if ([CCUtility getCertificateError:account]) {
        completion(account, nil, nil, nil, NSLocalizedString(@"_ssl_certificate_untrusted_", nil), NSURLErrorServerCertificateUntrusted);
    }
    
    devicePublicKey = [CCUtility URLEncodeStringFromString:devicePublicKey];
    NSString *proxyServerPath = [NCBrandOptions sharedInstance].pushNotificationServerProxy;
    NSString *proxyServer = [NCBrandOptions sharedInstance].pushNotificationServerProxy;
    
#ifdef DEBUG
//    proxyServerPath = @"http://127.0.0.1:8088";
//    proxyServer = @"https://10.132.0.37:8443/pushnotifications";
#endif
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    [communication subscribingNextcloudServerPush:url pushTokenHash:pushTokenHash devicePublicKey:devicePublicKey proxyServerPath: proxyServerPath onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *publicKey, NSString *deviceIdentifier, NSString *signature, NSString *redirectedServer) {
        
        deviceIdentifier = [CCUtility URLEncodeStringFromString:deviceIdentifier];
        signature = [CCUtility URLEncodeStringFromString:signature];
        publicKey = [CCUtility URLEncodeStringFromString:publicKey];
        
        [communication subscribingPushProxy:proxyServer pushToken:pushToken deviceIdentifier:deviceIdentifier deviceIdentifierSignature:signature publicKey:publicKey onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
            
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
    } else if ([CCUtility getPassword:account].length == 0) {
        completion(account, NSLocalizedString(@"_bad_username_password_", nil), kOCErrorServerUnauthorized);
    } else if ([CCUtility getCertificateError:account]) {
        completion(account, NSLocalizedString(@"_ssl_certificate_untrusted_", nil), NSURLErrorServerCertificateUntrusted);
    }
    
    NSString *proxyServer = [NCBrandOptions sharedInstance].pushNotificationServerProxy;
    
#ifdef DEBUG
//    proxyServer = @"https://10.132.0.37:8443/pushnotifications";
#endif
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    [communication unsubscribingNextcloudServerPush:url onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {

        [communication unsubscribingPushProxy:proxyServer deviceIdentifier:deviceIdentifier deviceIdentifierSignature:deviceIdentifierSignature publicKey:publicKey onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
            
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

- (void)getServerNotification:(NSString *)serverUrl notificationId:(NSInteger)notificationId completion:(void(^)(NSDictionary*jsongParsed, NSString *message, NSInteger errorCode))completion
{
    NSString *URLString = [NSString stringWithFormat:@"%@/ocs/v2.php/apps/notifications/api/v2/notifications/%ld?format=json", serverUrl, (long)notificationId];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString] cachePolicy:0 timeoutInterval:20.0];
    [request addValue:[CCUtility getUserAgent] forHTTPHeaderField:@"User-Agent"];
    [request addValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];

    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {

        if (error) {
            
            NSString *message;
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
            NSInteger errorCode = httpResponse.statusCode;
            
            if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
                errorCode = error.code;
            
            // Error
            if (errorCode == 503)
                message = NSLocalizedString(@"_server_error_retry_", nil);
            else
                message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
            
            completion(nil, message, errorCode);
            
        } else {
            
            NSDictionary *jsongParsed = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];

            completion(jsongParsed, nil, 0);
        }
    }];
    
    [task resume];
}

- (void)deletingServerNotification:(NSString *)serverUrl notificationId:(NSInteger)notificationId completion:(void(^)(NSString *message, NSInteger errorCode))completion
{
//    NSData *authData = [[NSString stringWithFormat:@"%@:%@", tableAccount.user, [CCUtility getPassword:tableAccount.account]] dataUsingEncoding:NSUTF8StringEncoding];
//    NSString *authValue = [NSString stringWithFormat: @"Basic %@",[authData base64EncodedStringWithOptions:0]];

    // Delete
    NSString *URLString = [NSString stringWithFormat:@"%@/ocs/v2.php/apps/notifications/api/v2/notifications/%ld", serverUrl, (long)notificationId];
    
    // Delete-all
    if (notificationId == 0) {
        URLString = [NSString stringWithFormat:@"%@/ocs/v2.php/apps/notifications/api/v2/notifications", serverUrl];
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString] cachePolicy:0 timeoutInterval:20.0];
//    [request setValue:authValue forHTTPHeaderField:@"Authorization"];
    [request addValue:[CCUtility getUserAgent] forHTTPHeaderField:@"User-Agent"];
    [request addValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];
    [request setHTTPMethod: @"DELETE"];

    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
        
        if (error) {
            
            NSString *message;
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
            NSInteger errorCode = httpResponse.statusCode;
            
            if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
                errorCode = error.code;
            
            // Error
            if (errorCode == 503)
                message = NSLocalizedString(@"_server_error_retry_", nil);
            else
                message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
            
            completion(message, errorCode);
            
        } else {
            
            completion(nil, 0);
        }
    }];
    
    [task resume];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Trash =====
#pragma --------------------------------------------------------------------------------------------

- (void)listingTrashWithAccount:(NSString *)account path:(NSString *)path serverUrl:(NSString *)serverUrl depth:(NSString *)depth completion:(void (^)(NSString *account, NSArray *items, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    } else if ([CCUtility getPassword:account].length == 0) {
        completion(account, nil, NSLocalizedString(@"_bad_username_password_", nil), kOCErrorServerUnauthorized);
    } else if ([CCUtility getCertificateError:account]) {
        completion(account, nil, NSLocalizedString(@"_ssl_certificate_untrusted_", nil), NSURLErrorServerCertificateUntrusted);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    [communication listingTrash:[serverUrl stringByAppendingString:path] depth:depth onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer) {
        
        // Check items > 0
        if ([items count] == 0) {
                
            [[NCContentPresenter shared] messageNotification:@"Server error" description:@"Read Folder WebDAV : [items NULL] please fix" delay:k_dismissAfterSecond type:messageTypeError errorCode:k_CCErrorInternalError];
            completion(account, nil, NSLocalizedString(@"Read Folder WebDAV : [items NULL] please fix", nil), k_CCErrorInternalError);
                
        } else {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSMutableArray *listTrash = [NSMutableArray new];
                
                //OCFileDto *itemDtoFolder = [items objectAtIndex:0];

                if ([items count] > 1) {
                    for (NSUInteger i=1; i < [items count]; i++) {
                        
                        OCFileDto *itemDto = [items objectAtIndex:i];
                        tableTrash *trash = [tableTrash new];
                        
                        trash.account = account;
                        trash.date = [NSDate dateWithTimeIntervalSince1970:itemDto.date];
                        trash.directory = itemDto.isDirectory;
                        trash.fileId = itemDto.fileId;
                        trash.fileName = itemDto.fileName;
                        NSArray *array = [itemDto.filePath componentsSeparatedByString:path];
                        long len = [[array objectAtIndex:0] length];
                        trash.filePath = [itemDto.filePath substringFromIndex:len];
                        trash.hasPreview = itemDto.hasPreview;
                        trash.size = itemDto.size;
                        trash.trashbinFileName = itemDto.trashbinFileName;
                        trash.trashbinOriginalLocation = itemDto.trashbinOriginalLocation;
                        trash.trashbinDeletionTime = [NSDate dateWithTimeIntervalSince1970:itemDto.trashbinDeletionTime];

                        NSDictionary *results = [[NCCommunicationCommon shared] objcGetInternalContenTypeWithFileName:trash.trashbinFileName contentType:@"" directory:itemDto.isDirectory];
                        
                        trash.contentType = results[@"contentType"];
                        trash.iconName = results[@"iconName"];
                        trash.typeFile = results[@"typeFile"];
                        
                        [listTrash addObject:trash];
                    }
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(account, listTrash, nil, 0);
                });
            });
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
    } else if ([CCUtility getPassword:account].length == 0) {
        completion(account, NSLocalizedString(@"_bad_username_password_", nil), kOCErrorServerUnauthorized);
    } else if ([CCUtility getCertificateError:account]) {
        completion(account, NSLocalizedString(@"_ssl_certificate_untrusted_", nil), NSURLErrorServerCertificateUntrusted);
    }
    
    NSString *path = [NSString stringWithFormat:@"%@%@/trashbin/%@/trash", tableAccount.url, k_dav, tableAccount.userID];

    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
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

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Comments =====
#pragma --------------------------------------------------------------------------------------------

- (void)getCommentsWithAccount:(NSString *)account fileId:(NSString *)fileId completion:(void (^)(NSString *account, NSArray *items, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    } else if ([CCUtility getPassword:account].length == 0) {
        completion(account, nil, NSLocalizedString(@"_bad_username_password_", nil), kOCErrorServerUnauthorized);
    } else if ([CCUtility getCertificateError:account]) {
        completion(account, nil, NSLocalizedString(@"_ssl_certificate_untrusted_", nil), NSURLErrorServerCertificateUntrusted);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;

    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getComments:[NSString stringWithFormat:@"%@%@", tableAccount.url, k_dav] fileId:fileId onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSArray *list, NSString *redirectedServer) {
        
        completion(account, list, nil, 0);

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

- (void)putCommentsWithAccount:(NSString *)account fileId:(NSString *)fileId message:(NSString *)message  completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    } else if ([CCUtility getPassword:account].length == 0) {
        completion(account, NSLocalizedString(@"_bad_username_password_", nil), kOCErrorServerUnauthorized);
    } else if ([CCUtility getCertificateError:account]) {
        completion(account, NSLocalizedString(@"_ssl_certificate_untrusted_", nil), NSURLErrorServerCertificateUntrusted);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication putComments:[NSString stringWithFormat:@"%@%@", tableAccount.url, k_dav] fileId:fileId message:message onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
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

- (void)updateCommentsWithAccount:(NSString *)account fileId:(NSString *)fileId messageID:(NSString *)messageID message:(NSString *)message  completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    } else if ([CCUtility getPassword:account].length == 0) {
        completion(account, NSLocalizedString(@"_bad_username_password_", nil), kOCErrorServerUnauthorized);
    } else if ([CCUtility getCertificateError:account]) {
        completion(account, NSLocalizedString(@"_ssl_certificate_untrusted_", nil), NSURLErrorServerCertificateUntrusted);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication updateComments:[NSString stringWithFormat:@"%@%@", tableAccount.url, k_dav] fileId:fileId messageID:messageID message:message onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
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

- (void)readMarkCommentsWithAccount:(NSString *)account fileId:(NSString *)fileId completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    } else if ([CCUtility getPassword:account].length == 0) {
        completion(account, NSLocalizedString(@"_bad_username_password_", nil), kOCErrorServerUnauthorized);
    } else if ([CCUtility getCertificateError:account]) {
        completion(account, NSLocalizedString(@"_ssl_certificate_untrusted_", nil), NSURLErrorServerCertificateUntrusted);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication readMarkComments:[NSString stringWithFormat:@"%@%@", tableAccount.url, k_dav] fileId:fileId onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
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

- (void)deleteCommentsWithAccount:(NSString *)account fileId:(NSString *)fileId messageID:(NSString *)messageID completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    } else if ([CCUtility getPassword:account].length == 0) {
        completion(account, NSLocalizedString(@"_bad_username_password_", nil), kOCErrorServerUnauthorized);
    } else if ([CCUtility getCertificateError:account]) {
        completion(account, NSLocalizedString(@"_ssl_certificate_untrusted_", nil), NSURLErrorServerCertificateUntrusted);
    }
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication deleteComments:[NSString stringWithFormat:@"%@%@", tableAccount.url, k_dav] fileId:fileId messageID:messageID onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
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

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Third Parts =====
#pragma --------------------------------------------------------------------------------------------

- (void)getHCUserProfileWithAccount:(NSString *)account serverUrl:(NSString *)serverUrl completion:(void (^)(NSString *account, OCUserProfile *userProfile, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    } else if ([CCUtility getPassword:account].length == 0) {
        completion(account, nil, NSLocalizedString(@"_bad_username_password_", nil), kOCErrorServerUnauthorized);
    } else if ([CCUtility getCertificateError:account]) {
        completion(account, nil, NSLocalizedString(@"_ssl_certificate_untrusted_", nil), NSURLErrorServerCertificateUntrusted);
    }
    
    NSString *serverPath = [NSString stringWithFormat:@"%@/ocs/v2.php/apps/handwerkcloud/api/v1/settings/%@", serverUrl, tableAccount.userID];
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication getHCUserProfile:serverPath onCommunication:communication successRequest:^(NSHTTPURLResponse *response, OCUserProfile *userProfile, NSString *redirectedServer) {
        
        completion(account, userProfile, nil, 0);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message;
        NSInteger errorCode = response.statusCode;
        
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Server Unauthorized
        if (errorCode == kOCErrorServerUnauthorized || errorCode == kOCErrorServerForbidden) {
#ifndef EXTENSION
            [[NCNetworkingCheckRemoteUser shared] checkRemoteUserWithAccount:account];
#endif
        } else if (errorCode == NSURLErrorServerCertificateUntrusted) {
            [CCUtility setCertificateError:account error:YES];
        }
        
        // Error
        if (errorCode == 503)
            message = NSLocalizedString(@"_server_error_retry_", nil);
        else
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        
        completion(account, nil,message, errorCode);
    }];
}

- (void)putHCUserProfileWithAccount:(NSString *)account serverUrl:(NSString *)serverUrl address:(NSString *)address businesssize:(NSString *)businesssize businesstype:(NSString *)businesstype city:(NSString *)city company:(NSString *)company  country:(NSString *)country displayname:(NSString *)displayname email:(NSString *)email phone:(NSString *)phone role_:(NSString *)role_ twitter:(NSString *)twitter website:(NSString *)website zip:(NSString *)zip completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    } else if ([CCUtility getPassword:account].length == 0) {
        completion(account, NSLocalizedString(@"_bad_username_password_", nil), kOCErrorServerUnauthorized);
    } else if ([CCUtility getCertificateError:account]) {
        completion(account, NSLocalizedString(@"_ssl_certificate_untrusted_", nil), NSURLErrorServerCertificateUntrusted);
    }
    
    // Create JSON
    NSMutableDictionary *dataDic = [NSMutableDictionary new];
    if (address) [dataDic setValue:address forKey:@"address"];
    if (businesssize) {
        if ([businesssize isEqualToString:@"1-4"]) { [dataDic setValue:[NSNumber numberWithInt:1] forKey:@"businesssize"]; }
        else if ([businesssize isEqualToString:@"5-9"]) { [dataDic setValue:[NSNumber numberWithInt:5] forKey:@"businesssize"]; }
        else if ([businesssize isEqualToString:@"10-19"]) { [dataDic setValue:[NSNumber numberWithInt:10] forKey:@"businesssize"]; }
        else if ([businesssize isEqualToString:@"20-49"]) { [dataDic setValue:[NSNumber numberWithInt:20] forKey:@"businesssize"]; }
        else if ([businesssize isEqualToString:@"50-99"]) { [dataDic setValue:[NSNumber numberWithInt:50] forKey:@"businesssize"]; }
        else if ([businesssize isEqualToString:@"100-249"]) { [dataDic setValue:[NSNumber numberWithInt:100] forKey:@"businesssize"]; }
        else if ([businesssize isEqualToString:@"250-499"]) { [dataDic setValue:[NSNumber numberWithInt:250] forKey:@"businesssize"]; }
        else if ([businesssize isEqualToString:@"500-999"]) { [dataDic setValue:[NSNumber numberWithInt:500] forKey:@"businesssize"]; }
        else if ([businesssize isEqualToString:@"1000+"]) { [dataDic setValue:[NSNumber numberWithInt:1000] forKey:@"businesssize"]; }
    }
    if (businesstype) [dataDic setValue:businesstype forKey:@"businesstype"];
    if (city) [dataDic setValue:city forKey:@"city"];
    if (company) [dataDic setValue:company forKey:@"company"];
    if (country) [dataDic setValue:country forKey:@"country"];
    if (displayname) [dataDic setValue:displayname forKey:@"displayname"];
    if (email) [dataDic setValue:email forKey:@"email"];
    if (phone) [dataDic setValue:phone forKey:@"phone"];
    if (role_) [dataDic setValue:role_ forKey:@"role"];
    if (twitter) [dataDic setValue:twitter forKey:@"twitter"];
    if (website) [dataDic setValue:website forKey:@"website"];
    if (zip) [dataDic setValue:zip forKey:@"zip"];
    NSString *data = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil] encoding:NSUTF8StringEncoding];

    NSString *serverPath = [NSString stringWithFormat:@"%@/ocs/v2.php/apps/handwerkcloud/api/v1/settings/%@", serverUrl, tableAccount.userID];
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication putHCUserProfile:serverPath data:data onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        completion(account, nil, 0);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message;
        NSInteger errorCode = response.statusCode;
        
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Server Unauthorized
        if (errorCode == kOCErrorServerUnauthorized || errorCode == kOCErrorServerForbidden) {
#ifndef EXTENSION
            [[NCNetworkingCheckRemoteUser shared] checkRemoteUserWithAccount:account];
#endif
        } else if (errorCode == NSURLErrorServerCertificateUntrusted) {
            [CCUtility setCertificateError:account error:YES];
        }
        
        // Error
        if (errorCode == 503)
            message = NSLocalizedString(@"_server_error_retry_", nil);
        else
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        
        completion(account, message, errorCode);
    }];
}

- (void)getHCFeaturesWithAccount:(NSString *)account serverUrl:(NSString *)serverUrl completion:(void (^)(NSString *account, HCFeatures *features, NSString *message, NSInteger errorCode))completion
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", account]];
    if (tableAccount == nil) {
        completion(account, nil, NSLocalizedString(@"_error_user_not_available_", nil), k_CCErrorUserNotAvailble);
    } else if ([CCUtility getPassword:account].length == 0) {
        completion(account, nil, NSLocalizedString(@"_bad_username_password_", nil), kOCErrorServerUnauthorized);
    } else if ([CCUtility getCertificateError:account]) {
        completion(account, nil, NSLocalizedString(@"_ssl_certificate_untrusted_", nil), NSURLErrorServerCertificateUntrusted);
    }
    
    NSString *serverPath = [NSString stringWithFormat:@"%@/ocs/v2.php/apps/handwerkcloud/api/v1/features/%@", serverUrl, tableAccount.userID];
    
    OCCommunication *communication = [OCNetworking sharedManager].sharedOCCommunication;
    
    [communication setCredentialsWithUser:tableAccount.user andUserID:tableAccount.userID andPassword:[CCUtility getPassword:account]];
    [communication setUserAgent:[CCUtility getUserAgent]];
        
    [communication getHCFeatures:serverPath onCommunication:communication successRequest:^(NSHTTPURLResponse *response, HCFeatures *features, NSString *redirectedServer) {
        
        completion(account, features, nil, 0);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        NSString *message;
        NSInteger errorCode = response.statusCode;
        
        if (errorCode == 0 || (errorCode >= 200 && errorCode < 300))
            errorCode = error.code;
        
        // Server Unauthorized
        if (errorCode == kOCErrorServerUnauthorized || errorCode == kOCErrorServerForbidden) {
#ifndef EXTENSION
            [[NCNetworkingCheckRemoteUser shared] checkRemoteUserWithAccount:account];
#endif
        } else if (errorCode == NSURLErrorServerCertificateUntrusted) {
            [CCUtility setCertificateError:account error:YES];
        }
        
        // Error
        if (errorCode == 503)
            message = NSLocalizedString(@"_server_error_retry_", nil);
        else
            message = [error.userInfo valueForKey:@"NSLocalizedDescription"];
        
        completion(account, nil,message, errorCode);
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  didReceiveChallenge =====
#pragma --------------------------------------------------------------------------------------------

-(void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler
{
    // The pinnning check
    if ([[NCNetworking sharedInstance] checkTrustedChallengeWithChallenge:challenge directoryCertificate:[CCUtility getDirectoryCerificates]]) {
        completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]);
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

@end

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  OCURLSessionManager =====
#pragma --------------------------------------------------------------------------------------------

@implementation OCURLSessionManager

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
    // The pinnning check
    if ([[NCNetworking sharedInstance] checkTrustedChallengeWithChallenge:challenge directoryCertificate:[CCUtility getDirectoryCerificates]]) {
        completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]);
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

@end

