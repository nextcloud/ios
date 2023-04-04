//
//  NCEndToEndEncryption.h
//  Nextcloud
//
//  Created by Marino Faggiana on 19/09/17.
//  Copyright © 2017 Marino Faggiana. All rights reserved.
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
#import <OpenSSL/OpenSSL.h>

@class tableMetadata;

@interface NCEndToEndEncryption : NSObject

+ (instancetype)sharedManager;

@property (nonatomic, strong) NSString *generatedPublicKey;
@property (nonatomic, strong) NSString *generatedPrivateKey;

// Certificate

- (NSString *)createCSR:(NSString *)userId directory:(NSString *)directory;
- (NSString *)encryptPrivateKey:(NSString *)userId directory: (NSString *)directory passphrase:(NSString *)passphrase privateKey:(NSString **)privateKey;
- (NSData *)decryptPrivateKey:(NSString *)privateKey passphrase:(NSString *)passphrase publicKey:(NSString *)publicKey;

// Encrypt / Decrypt file material

- (NSString *)encryptPayloadFile:(NSString *)encrypted key:(NSString *)key;
- (NSString *)encryptPayloadFile:(NSString *)encrypted key:(NSString *)key initializationVector:(NSString **)initializationVector authenticationTag:(NSString **)authenticationTag;
- (NSData *)decryptPayloadFile:(NSString *)encrypted key:(NSString *)key;
- (NSData *)decryptPayloadFile:(NSString *)encrypted key:(NSString *)key initializationVector:(NSString *)initializationVector authenticationTag:(NSString *)authenticationTag;

// Encrypt/Decrypt asymmetric

- (NSData *)encryptAsymmetricString:(NSString *)plain publicKey:(NSString *)publicKey privateKey:(NSString *)privateKey;
- (NSData *)decryptAsymmetricData:(NSData *)cipherData privateKey:(NSString *)privateKey;

// Encrypt / Decrypt file

- (BOOL)encryptFile:(NSString *)fileName fileNameIdentifier:(NSString *)fileNameIdentifier directory:(NSString *)directory key:(NSString **)key initializationVector:(NSString **)initializationVector authenticationTag:(NSString **)authenticationTag;
- (BOOL)decryptFile:(NSString *)fileName fileNameView:(NSString *)fileNameView ocId:(NSString *)ocId key:(NSString *)key initializationVector:(NSString *)initializationVector authenticationTag:(NSString *)authenticationTag;

// Utility

- (void)Encodedkey:(NSString **)key initializationVector:(NSString **)initializationVector;
- (NSData *)generateKey;
- (NSString *)createSHA512:(NSString *)string;
- (NSString *)createSHA256:(NSString *)string;
- (NSString *)extractPublicKeyFromCertificate:(NSString *)pemCertificate;

@end
