//
//  NCEndToEndEncryption.h
//  Nextcloud
//
//  Created by Marino Faggiana on 19/09/17.
//  Copyright © 2017 TWS. All rights reserved.
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

#import <Foundation/Foundation.h>

@class tableMetadata;

@interface NCEndToEndEncryption : NSObject

+ (instancetype)sharedManager;

- (NSString *)createCSR:(NSString *)userID directoryUser:(NSString *)directoryUser;
- (NSString *)encryptPrivateKey:(NSString *)userID directoryUser: (NSString *)directoryUser passphrase:(NSString *)passphrase privateKey:(NSString **)privateKey;
- (NSString *)decryptPrivateKey:(NSString *)privateKeyCipher passphrase:(NSString *)passphrase publicKey:(NSString *)publicKey;

- (NSData *)encryptAsymmetricString:(NSString *)plain publicKey:(NSString *)publicKey;
- (NSString *)decryptAsymmetricData:(NSData *)cipherData privateKey:(NSString *)privateKey;

- (NSString *)decryptMetadata:(NSString *)encrypted key:(NSString *)key;

- (BOOL)encryptFileName:(NSString *)fileName fileNameIdentifier:(NSString *)fileNameIdentifier directoryUser:(NSString *)directoryUser key:(NSString **)key initializationVector:(NSString **)initializationVector authenticationTag:(NSString **)authenticationTag;
- (BOOL)decryptFileID:(NSString *)fileID directoryUser:(NSString *)directoryUser key:(NSString *)key initializationVector:(NSString *)initializationVector authenticationTag:(NSString *)authenticationTag;

- (NSString *)createSHA512:(NSString *)string;

@end
