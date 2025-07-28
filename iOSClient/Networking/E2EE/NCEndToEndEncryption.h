// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2017 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

#import <Foundation/Foundation.h>
#import <OpenSSL/OpenSSL.h>

@class tableMetadata;

@interface NCEndToEndEncryption : NSObject

@property (nonatomic, strong) NSString *generatedPublicKey;
@property (nonatomic, strong) NSString *generatedPrivateKey;

+ (instancetype)shared;

// Certificate

- (NSString *)createCSR:(NSString *)userId directory:(NSString *)directory;
- (NSString *)encryptPrivateKey:(NSString *)userId directory: (NSString *)directory passphrase:(NSString *)passphrase privateKey:(NSString **)privateKey iterationCount:(unsigned int)iterationCount;
- (NSData *)decryptPrivateKey:(NSString *)privateKey passphrase:(NSString *)passphrase;
- (BOOL)isValidPrivateKeyPEM:(NSString *)privateKeyPEM;

// Encrypt / Decrypt file material

- (NSString *)encryptPayloadFile:(NSData *)encrypted key:(NSString *)key;
- (NSString *)encryptPayloadFile:(NSData *)encrypted key:(NSString *)key initializationVector:(NSString **)initializationVector authenticationTag:(NSString **)authenticationTag;
- (NSData *)decryptPayloadFile:(NSString *)encrypted key:(NSString *)key;
- (NSData *)decryptPayloadFile:(NSString *)encrypted key:(NSString *)key initializationVector:(NSString *)initializationVector authenticationTag:(NSString *)authenticationTag;

// Encrypt/Decrypt asymmetric

- (NSData *)encryptAsymmetricData:(NSData *)plainData certificate:(NSString *)certificate;
- (NSData *)encryptAsymmetricData:(NSData *)plainData  privateKey:(NSString *)privateKey;
- (NSData *)decryptAsymmetricData:(NSData *)cipherData privateKey:(NSString *)privateKey;

// Encrypt / Decrypt file

- (BOOL)encryptFile:(NSString *)fileName fileNameIdentifier:(NSString *)fileNameIdentifier directory:(NSString *)directory key:(NSString **)key initializationVector:(NSString **)initializationVector authenticationTag:(NSString **)authenticationTag;
- (BOOL)decryptFile:(NSString *)fileName fileNameView:(NSString *)fileNameView ocId:(NSString *)ocId userId:(NSString *)userId urlBase:(NSString *)urlBase key:(NSString *)key initializationVector:(NSString *)initializationVector authenticationTag:(NSString *)authenticationTag;

// Signature CMS

- (NSData *)generateSignatureCMS:(NSData *)data certificate:(NSString *)certificate privateKey:(NSString *)privateKey userId:(NSString *)userId;
// - (BOOL)verifySignatureCMS:(NSData *)cmsContent data:(NSData *)data publicKey:(NSString *)publicKey userId:(NSString *)userId;
- (BOOL)verifySignatureCMS:(NSData *)cmsContent data:(NSData *)data certificates:(NSArray*)certificates;

// Utility

- (void)Encodedkey:(NSString **)key initializationVector:(NSString **)initializationVector;
- (NSData *)generateKey;
- (NSString *)createSHA512:(NSString *)string;
- (NSString *)createSHA256:(NSData *)data;
- (NSString *)extractPublicKeyFromCertificate:(NSString *)pemCertificate;

@end
