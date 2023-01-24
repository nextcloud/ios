//
//  NCPushNotificationEncryption.h
//  Nextcloud
//
//  Created by Marino Faggiana on 25/07/18.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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
//  This code derived from : Nextcloud Talk - NCSettingsController Created by Ivan Sein on 26.06.17. Copyright © 2017 struktur AG. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NCPushNotificationEncryption : NSObject

+ (NCPushNotificationEncryption *)shared;
- (BOOL)generatePushNotificationsKeyPair:(NSString *)account;
- (NSString *)decryptPushNotification:(NSString *)message withDevicePrivateKey:(NSData *)privateKey;

@end
