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

+ (NCNetworkingSync *)sharedNetworking {
    static NCNetworkingSync *sharedNetworking;
    @synchronized(self)
    {
        if (!sharedNetworking) {
            sharedNetworking = [NCNetworkingSync new];
        }
        return sharedNetworking;
    }
}

+ (NSString *)lockEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID token:(NSString *)token delegate:(UIViewController *)delegate
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    __block NSString *returnToken = nil;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication lockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID token:token onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *token, NSString *redirectedServer) {
        
        returnToken = token;
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:delegate delegate:self];
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    return returnToken;
}

+ (NSError *)unlockEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID token:(NSString *)token delegate:(UIViewController *)delegate
{
    OCCommunication *communication = [CCNetworking sharedNetworking].sharedOCCommunication;
    __block NSError *returnError= nil;

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [communication setCredentialsWithUser:user andUserID:userID andPassword:password];
    [communication setUserAgent:[CCUtility getUserAgent]];
    
    [communication unlockEndToEndFolderEncrypted:[url stringByAppendingString:@"/"] fileID:fileID onCommunication:communication successRequest:^(NSHTTPURLResponse *response, NSString *redirectedServer) {
        
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        // Request trusted certificated
        if ([error code] == NSURLErrorServerCertificateUntrusted)
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:delegate delegate:self];
        
        returnError = error;
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    return returnError;
}

@end
