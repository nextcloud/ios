//
//  NCPushNotification.h
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

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NCPushNotification : NSObject

+ (instancetype)shared;
@property (nonatomic, strong) NSString *pushKitToken;

- (void)pushNotification;
- (void)applicationdidReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;
- (void)unsubscribingNextcloudServerPushNotification:(NSString *)account urlBase:(NSString *)urlBase user:(NSString *)user withSubscribing:(BOOL)subscribing;
- (void)removeNotificationWithNotificationId:(NSInteger)notificationId usingDecryptionKey:(NSData *)key;
- (void)registerForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;

@end

NS_ASSUME_NONNULL_END
