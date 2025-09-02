// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

#import "NCPushNotificationEncryption.h"
#import "NCBridgeSwift.h"
#import <OpenSSL/OpenSSL.h>
#import <CommonCrypto/CommonDigest.h>
#import "NCEndToEndEncryption.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation NCPushKeyPair

- (instancetype)initWithPublicKey:(NSData *)publicKey privateKey:(NSData *)privateKey {
    self = [super init];
    if (self) {
        _publicKey = publicKey;
        _privateKey = privateKey;
    }
    return self;
}

@end

@implementation NCPushNotificationEncryption

//Singleton
+ (instancetype)shared {
    static dispatch_once_t once;
    static NCPushNotificationEncryption *shared;
    dispatch_once(&once, ^{
        shared = [self new];
    });
    return shared;
}

- (NCPushKeyPair *)generatePushNotificationsKeyPair
{
    EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new_id(EVP_PKEY_RSA, NULL);
    if (!ctx) {
        return FALSE;
    }

    // Generate an new RSA KEY
    if (EVP_PKEY_keygen_init(ctx) <= 0) {
        EVP_PKEY_CTX_free(ctx);
        return FALSE;
    }

    if (EVP_PKEY_CTX_set_rsa_keygen_bits(ctx, 2048) <= 0) {
        EVP_PKEY_CTX_free(ctx);
        return FALSE;
    }

    EVP_PKEY *pkey = NULL;
    if (EVP_PKEY_keygen(ctx, &pkey) <= 0) {
        EVP_PKEY_CTX_free(ctx);
        return FALSE;
    }

    // PublicKey
    BIO *publicKeyBIO = BIO_new(BIO_s_mem());
    PEM_write_bio_PUBKEY(publicKeyBIO, pkey);
    
    int len = BIO_pending(publicKeyBIO);
    char *keyBytes = malloc(len);

    BIO_read(publicKeyBIO, keyBytes, len);
    NSData *publicKey = [NSData dataWithBytes:keyBytes length:len];
    NSLog(@"Push Notifications public Key generated: \n%@", [[NSString alloc] initWithData:publicKey encoding:NSUTF8StringEncoding]);

    // PrivateKey
    BIO *privateKeyBIO = BIO_new(BIO_s_mem());
    PEM_write_bio_PKCS8PrivateKey(privateKeyBIO, pkey, NULL, NULL, 0, NULL, NULL);
    
    len = BIO_pending(privateKeyBIO);
    keyBytes = malloc(len);
    
    BIO_read(privateKeyBIO, keyBytes, len);
    NSData *privateKey = [NSData dataWithBytes:keyBytes length:len];
    NSLog(@"Push Notifications private Key generated: \n%@", [[NSString alloc] initWithData:privateKey encoding:NSUTF8StringEncoding]);

    EVP_PKEY_free(pkey);
    EVP_PKEY_CTX_free(ctx);
    BIO_free(publicKeyBIO);
    BIO_free(privateKeyBIO);

    return [[NCPushKeyPair alloc] initWithPublicKey:publicKey privateKey:privateKey];
}

- (NSString *)decryptPushNotification:(NSString *)message withDevicePrivateKey:(NSData *)privateKey
{
    if (message == nil || privateKey == nil) { return nil; }
    
    NSString *privateKeyString = [[NSString alloc] initWithData:privateKey encoding:NSUTF8StringEncoding];
    NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:message options:0];
    char *privKey = (char *)[privateKeyString UTF8String];
    
    // Get Device Private Key from PEM
    BIO *bio = BIO_new(BIO_s_mem());
    BIO_write(bio, privKey, (int)strlen(privKey));
    
    EVP_PKEY *pkey = 0;
    PEM_read_bio_PrivateKey(bio, &pkey, 0, 0);

    RSA *rsa = EVP_PKEY_get1_RSA(pkey);

    // Decrypt the message
    unsigned char *decrypted = (unsigned char *) malloc(4096);
    
    int decrypted_length = RSA_private_decrypt((int)[decodedData length], [decodedData bytes], decrypted, rsa, RSA_PKCS1_PADDING);
    if(decrypted_length == -1) {
        char buffer[500];
        ERR_error_string(ERR_get_error(), buffer);
        NSLog(@"%@",[NSString stringWithUTF8String:buffer]);
        return nil;
    }
    
    NSString *decryptString = [[NSString alloc] initWithBytes:decrypted length:decrypted_length encoding:NSUTF8StringEncoding];
    
    if (decrypted)
        free(decrypted);
    free(bio);
    free(rsa);
    
    return decryptString;
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
