//
//  NCPushNotification.m
//  Nextcloud
//
//  Created by Marino Faggiana on 26/12/20.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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

#import <UserNotifications/UserNotifications.h>
#import "NCBridgeSwift.h"
#import "NCPushNotification.h"
#import "NCPushNotificationEncryption.h"
#import "NCEndToEndEncryption.h"
#import "CCUtility.h"

@interface NCPushNotification ()
{
    AppDelegate *appDelegate;
}
@end

@implementation NCPushNotification

+ (instancetype)shared
{
    static NCPushNotification *pushNotification = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pushNotification = [self new];
        pushNotification->appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    });
    return pushNotification;
}

- (void)pushNotification
{
    if (self.pushKitToken.length == 0) { return; }
    
    for (tableAccount *result in [[NCManageDatabase shared] getAllAccount]) {
        
        NSString *token = [[[NCKeychain alloc] init] getPushNotificationTokenWithAccount:result.account];

        if (![token isEqualToString:self.pushKitToken]) {
            if (token != nil) {
                // unsubscribing + subscribing
                [self unsubscribingNextcloudServerPushNotification:result.account urlBase:result.urlBase user:result.user withSubscribing:true];
            } else {
                [self subscribingNextcloudServerPushNotification:result.account urlBase:result.urlBase user:result.user];
            }
        }
    }
}

- (void)applicationdidReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    
    NSString *message = [userInfo objectForKey:@"subject"];
    if (message) {
        NSArray *results = [[NCManageDatabase shared] getAllAccount];
        for (tableAccount *result in results) {
            if ([[[NCKeychain alloc] init] getPushNotificationPrivateKeyWithAccount:result.account]) {
                NSData *decryptionKey = [[[NCKeychain alloc] init] getPushNotificationPrivateKeyWithAccount:result.account];
                NSString *decryptedMessage = [[NCPushNotificationEncryption shared] decryptPushNotification:message withDevicePrivateKey:decryptionKey];
                if (decryptedMessage) {
                    NSData *data = [decryptedMessage dataUsingEncoding:NSUTF8StringEncoding];
                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    NSInteger nid = [[json objectForKey:@"nid"] integerValue];
                    BOOL delete = [[json objectForKey:@"delete"] boolValue];
                    BOOL deleteAll = [[json objectForKey:@"delete-all"] boolValue];
                    if (delete) {
                        [[NCPushNotification shared] removeNotificationWithNotificationId:nid usingDecryptionKey:decryptionKey];
                    } else if (deleteAll) {
                        [[NCPushNotification shared] cleanAllNotifications];
                    }
                }
            }
        }
    }
    
    completionHandler(UIBackgroundFetchResultNoData);
}

- (void)subscribingNextcloudServerPushNotification:(NSString *)account urlBase:(NSString *)urlBase user:(NSString *)user
{
    if (appDelegate.account == nil || appDelegate.account.length == 0 || self.pushKitToken.length == 0) { return; }
    
    [[NCPushNotificationEncryption shared] generatePushNotificationsKeyPair:account];

    NSString *pushTokenHash = [[NCEndToEndEncryption sharedManager] createSHA512:self.pushKitToken];
    NSData *pushPublicKey = [[[NCKeychain alloc] init] getPushNotificationPublicKeyWithAccount:account];
    NSString *pushDevicePublicKey = [[NSString alloc] initWithData:pushPublicKey encoding:NSUTF8StringEncoding];
    NSString *proxyServerPath = [NCBrandOptions shared].pushNotificationServerProxy;
    NKRequestOptions *options = [[NKRequestOptions alloc] initWithEndpoint:nil version:nil customHeader:nil customUserAgent:nil contentType:nil e2eToken:nil timeout:60 queue:dispatch_get_main_queue()];

    [[NextcloudKit shared] subscribingPushNotificationWithServerUrl:urlBase account:account user:user password:[[[NCKeychain alloc] init] getPasswordWithAccount:account] pushTokenHash:pushTokenHash devicePublicKey:pushDevicePublicKey proxyServerUrl:proxyServerPath options:options taskHandler:^(NSURLSessionTask *task) {
    } completion:^(NSString *account, NSString *deviceIdentifier, NSString *signature, NSString *publicKey, NSData *data, NKError *error) {
        if (error == NKError.success) {
            NSString *userAgent = [NSString stringWithFormat:@"%@  (Strict VoIP)", [[NCBrandOptions shared] getUserAgent]];
            NKRequestOptions *options = [[NKRequestOptions alloc] initWithEndpoint:nil version:nil customHeader:nil customUserAgent:userAgent contentType:nil e2eToken:nil timeout:60 queue:dispatch_get_main_queue()];

            [[NextcloudKit shared] subscribingPushProxyWithProxyServerUrl:proxyServerPath pushToken:self.pushKitToken deviceIdentifier:deviceIdentifier signature:signature publicKey:publicKey options:options taskHandler:^(NSURLSessionTask *task) {
            } completion:^(NKError *error) {
                if (error == NKError.success) {

                    [[[NextcloudKit shared] nkCommonInstance] writeLog:@"[INFO] Subscribed to Push Notification server & proxy successfully"];

                    [[[NCKeychain alloc] init] setPushNotificationTokenWithAccount:account token:self.pushKitToken];
                    [[[NCKeychain alloc] init] setPushNotificationDeviceIdentifierWithAccount:account deviceIdentifier:deviceIdentifier];
                    [[[NCKeychain alloc] init] setPushNotificationDeviceIdentifierSignatureWithAccount:account deviceIdentifierSignature:signature];
                    [[[NCKeychain alloc] init] setPushNotificationSubscribingPublicKeyWithAccount:account publicKey:publicKey];
                }
            }];
        }
    }];
}

- (void)unsubscribingNextcloudServerPushNotification:(NSString *)account urlBase:(NSString *)urlBase user:(NSString *)user withSubscribing:(BOOL)subscribing
{
    if (appDelegate.account == nil || appDelegate.account.length == 0) { return; }
    
    NSString *deviceIdentifier = [[[NCKeychain alloc] init] getPushNotificationDeviceIdentifierWithAccount:account];
    NSString *signature = [[[NCKeychain alloc] init] getPushNotificationDeviceIdentifierSignatureWithAccount:account];
    NSString *publicKey = [[[NCKeychain alloc] init] getPushNotificationSubscribingPublicKeyWithAccount:account];
    NKRequestOptions *options = [[NKRequestOptions alloc] initWithEndpoint:nil version:nil customHeader:nil customUserAgent:nil contentType:nil e2eToken:nil timeout:60 queue:dispatch_get_main_queue()];

    [[NextcloudKit shared] unsubscribingPushNotificationWithServerUrl:urlBase account:account user:user password:[[[NCKeychain alloc] init] getPasswordWithAccount:account] options:options taskHandler:^(NSURLSessionTask *task) {
    } completion:^(NSString *account, NKError *error) {
        if (error == NKError.success) {
            NSString *proxyServerPath = [NCBrandOptions shared].pushNotificationServerProxy;
            NSString *userAgent = [NSString stringWithFormat:@"%@  (Strict VoIP)", [[NCBrandOptions shared] getUserAgent]];
            NKRequestOptions *options = [[NKRequestOptions alloc] initWithEndpoint:nil version:nil customHeader:nil customUserAgent:userAgent contentType:nil e2eToken:nil timeout:60 queue:dispatch_get_main_queue()];

            [[NextcloudKit shared] unsubscribingPushProxyWithProxyServerUrl:proxyServerPath deviceIdentifier:deviceIdentifier signature:signature publicKey:publicKey options:options taskHandler:^(NSURLSessionTask *task) {
            } completion:^(NKError *error) {
                if (error == NKError.success) {
                
                    [[[NextcloudKit shared] nkCommonInstance] writeLog:@"[INFO] Unsubscribed to Push Notification server & proxy successfully."];
                    
                    [[[NCKeychain alloc] init] setPushNotificationPublicKeyWithAccount:account data:nil];
                    [[[NCKeychain alloc] init] setPushNotificationSubscribingPublicKeyWithAccount:account publicKey:nil];
                    [[[NCKeychain alloc] init] setPushNotificationPrivateKeyWithAccount:account data:nil];
                    [[[NCKeychain alloc] init] setPushNotificationTokenWithAccount:account token:nil];
                    [[[NCKeychain alloc] init] setPushNotificationDeviceIdentifierWithAccount:account deviceIdentifier:nil];
                    [[[NCKeychain alloc] init] setPushNotificationDeviceIdentifierSignatureWithAccount:account deviceIdentifierSignature:nil];

                    if (self.pushKitToken != nil && subscribing) {
                        [self subscribingNextcloudServerPushNotification:account urlBase:urlBase user:user];
                    }
                }
            }];
        }
    }];
}

- (void)cleanAllNotifications
{
    [[UNUserNotificationCenter currentNotificationCenter] removeAllDeliveredNotifications];
}

- (void)removeNotificationWithNotificationId:(NSInteger)notificationId usingDecryptionKey:(NSData *)key
{
    // Check in pending notifications
    [[UNUserNotificationCenter currentNotificationCenter] getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> * _Nonnull requests) {
        for (UNNotificationRequest *notificationRequest in requests) {
            NSString *message = [notificationRequest.content.userInfo objectForKey:@"subject"];
            NSString *decryptedMessage = [[NCPushNotificationEncryption shared] decryptPushNotification:message withDevicePrivateKey:key];
            if (decryptedMessage) {
                NSData *data = [decryptedMessage dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                NSInteger nid = [[json objectForKey:@"nid"] integerValue];
                if (nid == notificationId) {
                    [[UNUserNotificationCenter currentNotificationCenter] removePendingNotificationRequestsWithIdentifiers:@[notificationRequest.identifier]];
                }
            }
        }
    }];
    // Check in delivered notifications
    [[UNUserNotificationCenter currentNotificationCenter] getDeliveredNotificationsWithCompletionHandler:^(NSArray<UNNotification *> * _Nonnull notifications) {
        for (UNNotification *notification in notifications) {
            NSString *message = [notification.request.content.userInfo objectForKey:@"subject"];
            NSString *decryptedMessage = [[NCPushNotificationEncryption shared] decryptPushNotification:message withDevicePrivateKey:key];
            if (decryptedMessage) {
                NSData *data = [decryptedMessage dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                NSInteger nid = [[json objectForKey:@"nid"] integerValue];
                if (nid == notificationId) {
                    [[UNUserNotificationCenter currentNotificationCenter] removeDeliveredNotificationsWithIdentifiers:@[notification.request.identifier]];
                }
            }
        }
    }];
}

- (void)registerForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    self.pushKitToken = [self stringWithDeviceToken:deviceToken];
    [self pushNotification];
}

- (NSString *)stringWithDeviceToken:(NSData *)deviceToken
{
    const char *data = [deviceToken bytes];
    NSMutableString *token = [NSMutableString string];
    
    for (NSUInteger i = 0; i < [deviceToken length]; i++) {
        [token appendFormat:@"%02.2hhX", data[i]];
    }
    
    return [token copy];
}

@end
