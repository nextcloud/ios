// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

#import <UIKit/UIKit.h>

@interface NCPushKeyPair : NSObject

@property (nonatomic, strong, readonly) NSData *publicKey;
@property (nonatomic, strong, readonly) NSData *privateKey;

- (instancetype)initWithPublicKey:(NSData *)publicKey privateKey:(NSData *)privateKey;

@end

@interface NCPushNotificationEncryption : NSObject

+ (instancetype)shared;
- (NCPushKeyPair *)generatePushNotificationsKeyPair;
- (NSString *)decryptPushNotification:(NSString *)message withDevicePrivateKey:(NSData *)privateKey;
- (NSString *)stringWithDeviceToken:(NSData *)deviceToken;

@end


