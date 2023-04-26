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
        
        NSString *token = [CCUtility getPushNotificationToken:result.account];
        
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
            if ([CCUtility getPushNotificationPrivateKey:result.account]) {
                NSData *decryptionKey = [CCUtility getPushNotificationPrivateKey:result.account];
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
    NSData *pushPublicKey = [CCUtility getPushNotificationPublicKey:account];
    NSString *pushDevicePublicKey = [[NSString alloc] initWithData:pushPublicKey encoding:NSUTF8StringEncoding];
    NSString *proxyServerPath = [NCBrandOptions shared].pushNotificationServerProxy;
    
    [[NextcloudKit shared] subscribingPushNotificationWithServerUrl:urlBase account:account user:user password:[CCUtility getPassword:account] pushTokenHash:pushTokenHash devicePublicKey:pushDevicePublicKey proxyServerUrl:proxyServerPath customUserAgent:nil addCustomHeaders:nil queue:dispatch_get_main_queue() completion:^(NSString *account, NSString *deviceIdentifier, NSString *signature, NSString *publicKey, NSData *data, NKError *error) {
        if (error == NKError.success) {
            NSString *userAgent = [NSString stringWithFormat:@"%@  (Strict VoIP)", [CCUtility getUserAgent]];
            [[NextcloudKit shared] subscribingPushProxyWithProxyServerUrl:proxyServerPath pushToken:self.pushKitToken deviceIdentifier:deviceIdentifier signature:signature publicKey:publicKey userAgent:userAgent queue:dispatch_get_main_queue() completion:^(NKError *error) {
                if (error == NKError.success) {

                    [[[NextcloudKit shared] nkCommonInstance] writeLog:@"[INFO] Subscribed to Push Notification server & proxy successfully"];

                    [CCUtility setPushNotificationToken:account token:self.pushKitToken];
                    [CCUtility setPushNotificationDeviceIdentifier:account deviceIdentifier:deviceIdentifier];
                    [CCUtility setPushNotificationDeviceIdentifierSignature:account deviceIdentifierSignature:signature];
                    [CCUtility setPushNotificationSubscribingPublicKey:account publicKey:publicKey];
                }
            }];
        }
    }];
}

- (void)unsubscribingNextcloudServerPushNotification:(NSString *)account urlBase:(NSString *)urlBase user:(NSString *)user withSubscribing:(BOOL)subscribing
{
    if (appDelegate.account == nil || appDelegate.account.length == 0) { return; }
    
    NSString *deviceIdentifier = [CCUtility getPushNotificationDeviceIdentifier:account];
    NSString *signature = [CCUtility getPushNotificationDeviceIdentifierSignature:account];
    NSString *publicKey = [CCUtility getPushNotificationSubscribingPublicKey:account];

    [[NextcloudKit shared] unsubscribingPushNotificationWithServerUrl:urlBase account:account user:user password:[CCUtility getPassword:account] customUserAgent:nil addCustomHeaders:nil queue:dispatch_get_main_queue() completion:^(NSString *account, NKError *error) {
        if (error == NKError.success) {
            NSString *userAgent = [NSString stringWithFormat:@"%@  (Strict VoIP)", [CCUtility getUserAgent]];
            NSString *proxyServerPath = [NCBrandOptions shared].pushNotificationServerProxy;
            [[NextcloudKit shared] unsubscribingPushProxyWithProxyServerUrl:proxyServerPath deviceIdentifier:deviceIdentifier signature:signature publicKey:publicKey userAgent:userAgent queue:dispatch_get_main_queue() completion:^(NKError *error) {
                if (error == NKError.success) {
                
                    [[[NextcloudKit shared] nkCommonInstance] writeLog:@"[INFO] Unsubscribed to Push Notification server & proxy successfully."];
                    
                    [CCUtility setPushNotificationPublicKey:account data:nil];
                    [CCUtility setPushNotificationSubscribingPublicKey:account publicKey:nil];
                    [CCUtility setPushNotificationPrivateKey:account data:nil];
                    [CCUtility setPushNotificationToken:account token:nil];
                    [CCUtility setPushNotificationDeviceIdentifier:account deviceIdentifier:nil];
                    [CCUtility setPushNotificationDeviceIdentifierSignature:account deviceIdentifierSignature:nil];
                    
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
