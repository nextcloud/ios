//
//  NCPushNotificationEncryption.m
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

#import "NCPushNotificationEncryption.h"

#import <OpenSSL/OpenSSL.h>
#import <CommonCrypto/CommonDigest.h>

#import "NCEndToEndEncryption.h"
#import "CCUtility.h"

@implementation NCPushNotificationEncryption

+ (NCPushNotificationEncryption *)shared
{
    static dispatch_once_t once;
    static NCPushNotificationEncryption *shared;
    dispatch_once(&once, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (id)init
{
    self = [super init];
    if (self) {
       
    }
    return self;
}

- (BOOL)generatePushNotificationsKeyPair:(NSString *)account
{
    int len;
    char *keyBytes;
    
    EVP_PKEY *pkey = EVP_PKEY_new();
    BIGNUM *bigNumber = BN_new();
    int exponent = RSA_F4;
    RSA *rsa = RSA_new();
    
    BN_set_word(bigNumber, exponent);
    RSA_generate_key_ex(rsa, 2048, bigNumber, NULL);
    EVP_PKEY_set1_RSA(pkey, rsa);

    // PublicKey
    BIO *publicKeyBIO = BIO_new(BIO_s_mem());
    PEM_write_bio_PUBKEY(publicKeyBIO, pkey);
    
    len = BIO_pending(publicKeyBIO);
    keyBytes  = malloc(len);
    
    BIO_read(publicKeyBIO, keyBytes, len);
    NSData *ncPNPublicKey = [NSData dataWithBytes:keyBytes length:len];
    [CCUtility setPushNotificationPublicKey:account data:ncPNPublicKey];
    NSLog(@"Push Notifications Key Pair generated: \n%@", [[NSString alloc] initWithData:ncPNPublicKey encoding:NSUTF8StringEncoding]);
    
    // PrivateKey
    BIO *privateKeyBIO = BIO_new(BIO_s_mem());
    PEM_write_bio_PKCS8PrivateKey(privateKeyBIO, pkey, NULL, NULL, 0, NULL, NULL);
    
    len = BIO_pending(privateKeyBIO);
    keyBytes = malloc(len);
    
    BIO_read(privateKeyBIO, keyBytes, len);
    NSData *ncPNPrivateKey = [NSData dataWithBytes:keyBytes length:len];
    [CCUtility setPushNotificationPrivateKey:account data:ncPNPrivateKey];
    
    RSA_free(rsa);
    BN_free(bigNumber);
    EVP_PKEY_free(pkey);
    
    return YES;
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
    
    EVP_PKEY* pkey = 0;
    PEM_read_bio_PrivateKey(bio, &pkey, 0, 0);
    
    RSA* rsa = EVP_PKEY_get1_RSA(pkey);
    
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

@end
