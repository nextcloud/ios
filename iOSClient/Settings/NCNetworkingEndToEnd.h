//
//  NCNetworkingEndToEnd.h
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

#import <Foundation/Foundation.h>
#import "CCNetworking.h"

@interface NCNetworkingEndToEnd : NSObject

+ (NCNetworkingEndToEnd *)sharedManager;

// ===== End-to-End Encryption Networking =====

- (void)getEndToEndPublicKeyWithAccount:(NSString *)account completion:(void (^)(NSString *account, NSString *publicKey, NSString *message, NSInteger errorCode))completion;
- (void)getEndToEndPrivateKeyCipherWithAccount:(NSString *)account completion:(void (^)(NSString *account, NSString *privateKeyChiper, NSString *message, NSInteger errorCode))completion;
- (void)signEndToEndPublicKeyWithAccount:(NSString *)account publicKey:(NSString *)publicKey completion:(void (^)(NSString *account, NSString *publicKey, NSString *message, NSInteger errorCode))completion;
- (void)storeEndToEndPrivateKeyCipherWithAccount:(NSString *)account privateKeyString:(NSString *)privateKeyString privateKeyChiper:(NSString *)privateKeyChiper completion:(void (^)(NSString *account, NSString *privateKeyString, NSString *privateKey, NSString *message, NSInteger errorCode))completion;
- (void)deleteEndToEndPublicKeyWithAccount:(NSString *)account completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion;
- (void)deleteEndToEndPrivateKeyWithAccount:(NSString *)account completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion;
- (void)getEndToEndServerPublicKeyWithAccount:(NSString *)account completion:(void (^)(NSString *account, NSString *publicKey, NSString *message, NSInteger errorCode))completion;


@end
