//
//  NCEndToEndEncryption.m
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

#import "NCEndToEndEncryption.h"
#import "NCBridgeSwift.h"
#import "CCUtility.h"

#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonKeyDerivation.h>

#import <openssl/x509.h>
#import <openssl/bio.h>
#import <openssl/err.h>
#import <openssl/pem.h>
#import <openssl/rsa.h>
#import <openssl/pkcs12.h>
#import <openssl/ssl.h>
#import <openssl/err.h>
#import <openssl/bn.h>
#import <openssl/md5.h>

#define addName(field, value) X509_NAME_add_entry_by_txt(name, field, MBSTRING_ASC, (unsigned char *)value, -1, -1, 0); NSLog(@"%s: %s", field, value);

#define AES_KEY_LENGTH              16
#define AES_IVEC_LENGTH             16
#define AES_GCM_TAG_LENGTH          16

#define IV_DELIMITER_ENCODED        @"fA==" // "|" base64 encoded
#define PBKDF2_INTERACTION_COUNT    1024
#define PBKDF2_KEY_LENGTH           256
#define PBKDF2_SALT                 @"$4$YmBjm3hk$Qb74D5IUYwghUmzsMqeNFx5z0/8$"
#define TEST_KEY                    @"hello"

#define fileNameCertificate         @"cert.pem"
#define fileNameCSR                 @"csr.pem"
#define fileNamePrivateKey          @"privateKey.pem"
#define fileNamePubliceKey          @"publicKey.pem"


@interface NCEndToEndEncryption ()
{
    NSData *_privateKeyData;
    NSData *_publicKeyData;
    NSData *_csrData;
}
@end

@implementation NCEndToEndEncryption

//Singleton
+ (instancetype)sharedManager {
    static NCEndToEndEncryption *NCEndToEndEncryption = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NCEndToEndEncryption = [self new];
    });
    return NCEndToEndEncryption;
}

#
#pragma mark - Generate Certificate X509 - CSR - Private Key
#

- (BOOL)generateCertificateX509WithUserID:(NSString *)userID directoryUser:(NSString *)directoryUser
{
    OPENSSL_init_ssl(0, NULL);
    OPENSSL_init_crypto(0, NULL);
    
    X509 *x509;
    x509 = X509_new();
    
    EVP_PKEY *pkey;
    NSError *keyError;
    pkey = [self generateRSAKey:&keyError];
    if (keyError) {
        return NO;
    }

    X509_set_pubkey(x509, pkey);
    EVP_PKEY_free(pkey);
    
    // Set Serial Number
    ASN1_INTEGER_set(X509_get_serialNumber(x509), 123);
    
    // Set Valididity Date Range
    long notBefore = [[NSDate date] timeIntervalSinceDate:[NSDate date]];
    long notAfter = [[[NSDate date] dateByAddingTimeInterval:60*60*24*365*10] timeIntervalSinceDate:[NSDate date]]; // 10 year
    X509_gmtime_adj((ASN1_TIME *)X509_get0_notBefore(x509), notBefore);
    X509_gmtime_adj((ASN1_TIME *)X509_get0_notAfter(x509), notAfter);
    
    X509_NAME *name = X509_get_subject_name(x509);
    
    // Now to add the subject name fields to the certificate
    // I use a macro here to make it cleaner.
    
    const unsigned char *cUserID = (const unsigned char *) [userID cStringUsingEncoding:NSUTF8StringEncoding];

    // Common Name = UserID.
    addName("CN", cUserID);
    
    // The organizational unit for the cert. Usually this is a department.
    addName("OU", "Certificate Authority");
    
    // The organization of the cert.
    addName("O",  "Nextcloud");
    
    // The city of the organization.
    addName("L",  "Vicenza");
    
    // The state/province of the organization.
    addName("S",  "Italy");
    
    // The country (ISO 3166) of the organization
    addName("C",  "IT");
    
    X509_set_issuer_name(x509, name);
    
    /*
     for (SANObject * san in self.options.sans) {
     if (!san.value || san.value.length <= 0) {
     continue;
     }
     
     NSString * prefix = san.type == SANObjectTypeIP ? @"IP:" : @"DNS:";
     NSString * value = [NSString stringWithFormat:@"%@%@", prefix, san.value];
     NSLog(@"Add subjectAltName %@", value);
     
     X509_EXTENSION * extension = NULL;
     ASN1_STRING * asnValue = ASN1_STRING_new();
     ASN1_STRING_set(asnValue, (const unsigned char *)[value UTF8String], (int)value.length);
     X509_EXTENSION_create_by_NID(&extension, NID_subject_alt_name, 0, asnValue);
     X509_add_ext(x509, extension, -1);
     }
     */
    
    // Specify the encryption algorithm of the signature.
    // SHA256 should suit your needs.
    if (X509_sign(x509, pkey, EVP_sha256()) < 0) {
        return NO;
    }
    
    X509_print_fp(stdout, x509);
    
    // Extract CSR, publicKey, privateKey
    int len;
    char *keyBytes;
    
    // CSR
    BIO *csrBIO = BIO_new(BIO_s_mem());
    X509_REQ *certReq = X509_to_X509_REQ(x509, pkey, EVP_sha256());
    PEM_write_bio_X509_REQ(csrBIO, certReq);
    
    len = BIO_pending(csrBIO);
    keyBytes  = malloc(len);
    
    BIO_read(csrBIO, keyBytes, len);
    _csrData = [NSData dataWithBytes:keyBytes length:len];
    NSLog(@"\n%@", [[NSString alloc] initWithData:_csrData encoding:NSUTF8StringEncoding]);
    
    // PublicKey
    BIO *publicKeyBIO = BIO_new(BIO_s_mem());
    PEM_write_bio_PUBKEY(publicKeyBIO, pkey);
    
    len = BIO_pending(publicKeyBIO);
    keyBytes  = malloc(len);
    
    BIO_read(publicKeyBIO, keyBytes, len);
    _publicKeyData = [NSData dataWithBytes:keyBytes length:len];
    NSLog(@"\n%@", [[NSString alloc] initWithData:_publicKeyData encoding:NSUTF8StringEncoding]);
    
    // PrivateKey
    BIO *privateKeyBIO = BIO_new(BIO_s_mem());
    PEM_write_bio_PKCS8PrivateKey(privateKeyBIO, pkey, NULL, NULL, 0, NULL, NULL);
    
    len = BIO_pending(privateKeyBIO);
    keyBytes = malloc(len);
    
    BIO_read(privateKeyBIO, keyBytes, len);
    _privateKeyData = [NSData dataWithBytes:keyBytes length:len];
    NSLog(@"\n%@", [[NSString alloc] initWithData:_privateKeyData encoding:NSUTF8StringEncoding]);
    
    if(keyBytes)
        free(keyBytes);
    
#ifdef DEBUG
    // Save to disk [DEBUG MODE]
    [self saveToDiskPEMWithCert:x509 key:pkey directoryUser:directoryUser];
#endif
    
    return YES;
}

- (EVP_PKEY *)generateRSAKey:(NSError **)error
{
    EVP_PKEY *pkey = EVP_PKEY_new();
    if (!pkey) {
        return NULL;
    }
    
    BIGNUM *bigNumber = BN_new();
    int exponent = RSA_F4;
    RSA *rsa = RSA_new();
    
    if (BN_set_word(bigNumber, exponent) < 0) {
        goto cleanup;
    }
    
    if (RSA_generate_key_ex(rsa, 2048, bigNumber, NULL) < 0) {
        goto cleanup;
    }
    
    if (!EVP_PKEY_set1_RSA(pkey, rsa)) {
        goto cleanup;
    }
    
cleanup:
    RSA_free(rsa);
    BN_free(bigNumber);
    
    return pkey;
}

- (BOOL)saveToDiskPEMWithCert:(X509 *)x509 key:(EVP_PKEY *)pkey directoryUser:(NSString *)directoryUser
{
    FILE *f;
    
    // Certificate
    NSString *certificatePath = [NSString stringWithFormat:@"%@/%@", directoryUser, fileNameCertificate];
    f = fopen([certificatePath fileSystemRepresentation], "wb");
    if (PEM_write_X509(f, x509) < 0) {
        // Error writing to disk.
        fclose(f);
        return NO;
    }
    NSLog(@"Saved cert to %@", certificatePath);
    fclose(f);
    
    // PublicKey
    NSString *publicKeyPath = [NSString stringWithFormat:@"%@/%@", directoryUser, fileNamePubliceKey];
    f = fopen([publicKeyPath fileSystemRepresentation], "wb");
    if (PEM_write_PUBKEY(f, pkey) < 0) {
        // Error
        fclose(f);
        return NO;
    }
    NSLog(@"Saved publicKey to %@", publicKeyPath);
    fclose(f);
    
    // Here you write the private key (pkey) to disk. OpenSSL will encrypt the
    // file using the password and cipher you provide.
    //if (PEM_write_PrivateKey(f, pkey, EVP_des_ede3_cbc(), (unsigned char *)[password UTF8String], (int)password.length, NULL, NULL) < 0) {
    
    // PrivateKey
    NSString *privatekeyPath = [NSString stringWithFormat:@"%@/%@", directoryUser, fileNamePrivateKey];
    f = fopen([privatekeyPath fileSystemRepresentation], "wb");
    if (PEM_write_PrivateKey(f, pkey, NULL, NULL, 0, NULL, NULL) < 0) {
        // Error
        fclose(f);
        return NO;
    }
    NSLog(@"Saved privatekey to %@", privatekeyPath);
    fclose(f);
    
    // CSR Request sha256
    NSString *csrPath = [NSString stringWithFormat:@"%@/%@", directoryUser, fileNameCSR];
    f = fopen([csrPath fileSystemRepresentation], "wb");
    X509_REQ *certreq = X509_to_X509_REQ(x509, pkey, EVP_sha256());
    if (PEM_write_X509_REQ(f, certreq) < 0) {
        // Error
        fclose(f);
        return NO;
    }
    NSLog(@"Saved csr to %@", csrPath);
    fclose(f);
    
    return YES;
}

- (BOOL)saveP12WithCert:(X509 *)x509 key:(EVP_PKEY *)pkey directoryUser:(NSString *)directoryUser finished:(void (^)(NSError *))finished
{
    //PKCS12 * p12 = PKCS12_create([password UTF8String], NULL, pkey, x509, NULL, 0, 0, PKCS12_DEFAULT_ITER, 1, NID_key_usage);
    PKCS12 *p12 = PKCS12_create(NULL, NULL, pkey, x509, NULL, 0, 0, PKCS12_DEFAULT_ITER, 1, NID_key_usage);
    
    NSString *path = [NSString stringWithFormat:@"%@/certificate.p12", directoryUser];
    
    FILE *f = fopen([path fileSystemRepresentation], "wb");
    
    if (i2d_PKCS12_fp(f, p12) != 1) {
        fclose(f);
        return NO;
    }
    NSLog(@"Saved p12 to %@", path);
    fclose(f);
    
    return YES;
}

#
#pragma mark - Register client for Server with exists Key pair
#

- (NSString *)createCSR:(NSString *)userID directoryUser:(NSString *)directoryUser
{
    // Create Certificate, if do not exists
    if (!_csrData) {
        if (![self generateCertificateX509WithUserID:userID directoryUser:directoryUser])
            return nil;
    }
    
    NSString *csr = [[NSString alloc] initWithData:_csrData encoding:NSUTF8StringEncoding];
    
    return csr;
}

- (NSString *)encryptPrivateKey:(NSString *)userID directoryUser: (NSString *)directoryUser passphrase:(NSString *)passphrase
{
    NSMutableData *privateKeyCipherData = [NSMutableData new];

    if (!_privateKeyData) {
        if (![self generateCertificateX509WithUserID:userID directoryUser:directoryUser])
            return nil;
    }
    
    NSMutableData *keyData = [NSMutableData dataWithLength:PBKDF2_KEY_LENGTH];
    NSData *saltData = [PBKDF2_SALT dataUsingEncoding:NSUTF8StringEncoding];
    
    // Remove all whitespaces from passphrase
    passphrase = [passphrase stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    CCKeyDerivationPBKDF(kCCPBKDF2, passphrase.UTF8String, passphrase.length, saltData.bytes, saltData.length, kCCPRFHmacAlgSHA1, PBKDF2_INTERACTION_COUNT, keyData.mutableBytes, keyData.length);
    
    NSData *initVectorData = [self generateIV:AES_IVEC_LENGTH];

    BOOL result = [self encryptData:_privateKeyData cipherData:&privateKeyCipherData keyData:keyData initVectorData:initVectorData tagData:nil];
    
    if (result && privateKeyCipherData) {
        
        NSString *privateKeyCipherBase64;
        NSString *initVectorBase64;
        NSString *privateKeyCipherWithInitVectorBase64;

        privateKeyCipherBase64 = [privateKeyCipherData base64EncodedStringWithOptions:0];
        initVectorBase64 = [initVectorData base64EncodedStringWithOptions:0];
        privateKeyCipherWithInitVectorBase64 = [NSString stringWithFormat:@"%@%@%@", privateKeyCipherBase64, IV_DELIMITER_ENCODED, initVectorBase64];
        
        return privateKeyCipherWithInitVectorBase64;
        
    } else {
        
        return nil;
    }
}

#
#pragma mark - No key pair exists on the server
#

- (NSString *)decryptPrivateKey:(NSString *)privateKeyCipher passphrase:(NSString *)passphrase publicKey:(NSString *)publicKey
{
    NSMutableData *privateKeyData = [NSMutableData new];
    
    // Key (data)
    NSMutableData *keyData = [NSMutableData dataWithLength:PBKDF2_KEY_LENGTH];
    NSData *saltData = [PBKDF2_SALT dataUsingEncoding:NSUTF8StringEncoding];
    
    // Remove all whitespaces from passphrase
    passphrase = [passphrase stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    CCKeyDerivationPBKDF(kCCPBKDF2, passphrase.UTF8String, passphrase.length, saltData.bytes, saltData.length, kCCPRFHmacAlgSHA1, PBKDF2_INTERACTION_COUNT, keyData.mutableBytes, keyData.length);
    
    // Split
    NSRange range = [privateKeyCipher rangeOfString:IV_DELIMITER_ENCODED];
    NSInteger idx = range.location + range.length;
    
    // PrivateKey
    NSString *privateKeyCipherBase64 = [privateKeyCipher substringToIndex:range.location];
    NSData *privateKeyCipherData = [[NSData alloc] initWithBase64EncodedString:privateKeyCipherBase64 options:0];

    // Init Vector
    NSString *initVectorBase64 = [privateKeyCipher substringFromIndex:idx];
    NSData *initVectorData = [[NSData alloc] initWithBase64EncodedString:initVectorBase64 options:0];
    
    BOOL result = [self decryptData:privateKeyCipherData plainData:&privateKeyData keyData:keyData initVectorData:initVectorData tag:nil];
    
    if (result && privateKeyData) {
        
        NSString *privateKey = [[NSString alloc] initWithData:privateKeyData encoding:NSUTF8StringEncoding];
        
        NSData *encryptData = [self encryptAsymmetricString:TEST_KEY publicKey:publicKey];
        if (!encryptData)
            return nil;
        NSString *decryptString = [self decryptAsymmetricData:encryptData privateKey:privateKey];
        
        if (decryptString && [decryptString isEqualToString:TEST_KEY])
            return privateKey;
        else
            return nil;
        
    } else {
        
        return nil;
    }
}

#
#pragma mark - Asymmetric Encrypt/Decrypt String
#

- (NSData *)encryptAsymmetricString:(NSString *)plain publicKey:(NSString *)publicKey
{
    NSData *plainData = [plain dataUsingEncoding:NSUTF8StringEncoding];

    //unsigned char *pKey = (unsigned char *)[publicKey UTF8String];
    
    char *pKey = "-----BEGIN PUBLIC KEY-----\n"
    "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwMu7BZF451FjUXYNr323\n"
    "aeeaCW2a7s6eHHs8Gz5qgQ/zDegub6is3jwdTZJyGcRcN1DxKQsLcOa3F18KSiCk\n"
    "yzIWjNV4YH7GdV7Ke2qLjcQUs7wktGUKyPYJmDWGYv/QN0Sbbol9IbeLjSBHUt16\n"
    "xBex5IIpQqDtBy0RZvAMdUUB1rezKka0bC+b5CmE4ysIRFyFiweSlGsSdkaS9q1l\n"
    "d+c/V4LMxljNbhdpfpiniWAD3lm9+mDJzToOiqz+nH9SHs4ClEThBAScI00xJH36\n"
    "3mDvY0x6HVDyCsueC9jtfZKnI2uwM2tbUU4iDkCaIYm6VE6h1qs5AkrxH1o6K2lC\n"
    "kQIDAQAB\n"
    "-----END PUBLIC KEY-----\n";
    
    BIO *bio = BIO_new_mem_buf(pKey, -1);
    RSA *rsa = PEM_read_bio_RSA_PUBKEY(bio, NULL, 0, NULL);
    BIO_free(bio);

    int maxSize = RSA_size(rsa);
    unsigned char *output = (unsigned char *) malloc(maxSize * sizeof(char));
    
    int encrypted_length = RSA_public_encrypt((int)[plainData length], [plainData bytes], output, rsa, RSA_PKCS1_PADDING);
    if(encrypted_length == -1) {
        char buffer[500];
        ERR_error_string(ERR_get_error(), buffer);
        NSLog(@"%@",[NSString stringWithUTF8String:buffer]);
        return nil;
    }
    
    return [NSData dataWithBytes:output length:encrypted_length];
}

- (NSString *)decryptAsymmetricData:(NSData *)chiperData privateKey:(NSString *)privateKey
{
    //unsigned char *pKey = (unsigned char *)[privateKey UTF8String];
    
    char *pKey = "-----BEGIN RSA PRIVATE KEY-----\n"
    "MIIEowIBAAKCAQEAwMu7BZF451FjUXYNr323aeeaCW2a7s6eHHs8Gz5qgQ/zDegu\n"
    "b6is3jwdTZJyGcRcN1DxKQsLcOa3F18KSiCkyzIWjNV4YH7GdV7Ke2qLjcQUs7wk\n"
    "tGUKyPYJmDWGYv/QN0Sbbol9IbeLjSBHUt16xBex5IIpQqDtBy0RZvAMdUUB1rez\n"
    "Kka0bC+b5CmE4ysIRFyFiweSlGsSdkaS9q1ld+c/V4LMxljNbhdpfpiniWAD3lm9\n"
    "+mDJzToOiqz+nH9SHs4ClEThBAScI00xJH363mDvY0x6HVDyCsueC9jtfZKnI2uw\n"
    "M2tbUU4iDkCaIYm6VE6h1qs5AkrxH1o6K2lCkQIDAQABAoIBAChqzWNGcu0zb7nF\n"
    "IOtYVJocFnvBgYhswlLANwKTHCrAWDjjItD/sHXKbm4ztD3Yn2htTJFJInXhuCJr\n"
    "JzIRE9sRPg76NYktKpeybope9LCcmaZwW9WBlTg59Br3pZude14KwPb0Vco6u0Oz\n"
    "r6AclD8FpKJ98v5n1Cj79rj4u/PdTXZP+Fmz8y0KAgM1s39rtiaAHKGCcyfb1awf\n"
    "pCsYL0IvmU1Z00sPe5dzSqLY4HcIyT2kIMqnC0c0HTPtU6A5GI7dPMQsJy+ZEsWo\n"
    "kR4YdymmN3C11gdd8kTpExdm1Ick5GfgUfc5hYYTBUO4n8bWJFJLxY6MtjdRfWHc\n"
    "SBg4hw0CgYEA3vYaOzk8gUgUVkhnAsyoRNPkMKOH+EbOWuAssK3lQ2U8gvryJngz\n"
    "KaQEGnluHvwK69BkJQQ5+PTMKhvhDZ4Ur9t6K7iZ3io3XLafH+jZk8alxYtZen00\n"
    "Z38z2VQ8gjYHjfXGKNs1YGcfb+uJ5a8YMGbNjYTdGkIeWL0DLdrYH78CgYEA3V1R\n"
    "fTPCY93kxOfYEnRvsO7HY6/4aESAMthROABd9IbYzmsA2Jkcs9Cns3MvWoLpbUY5\n"
    "c36WDn9pZOg8vF0dday9Gr/ZrisEv7MgFl0FloyNsnGviHHFfoLPbOjEPUGXcRy2\n"
    "1350nFJ2L0e9XcHgvPSjkmwcLbGgkrtWgjJoMa8CgYB0URPSPcPw9jeV4+PJtBc9\n"
    "AQYU0duHjPjus/Dco3vtswzkkCJwK1kVqjlxzlPC2l6gM3FrVk8gMCWq+ixovEWy\n"
    "kN+lm4K6Qm/rcGKHdSS9UW7+JfqiSltiexwDj0yZ6bH7P3MHsYShLGtcKhcguj32\n"
    "Ukt+PwhSQJgwVzsnWvpRZQKBgQCDFrIdLLufHFZPbOR9+UnzQ1P8asb2KCqq8YMX\n"
    "YNBC8GAPzToRCor+yT+mez29oezN81ouVPZT24v0X7sn6RR7DTJnVtl31K3ZQCBu\n"
    "XePjRZTb6YsDiCxmQNzJKAaeJ+ug5lo4vwAbWpH2actwbFHEVDNRkIgXXysx+ZK/\n"
    "Q06ErQKBgHzXwrSRWppsQGdxSrU1Ynwg0bIirfi2N8zyHgFutQzdkDXY5N0gRG7a\n"
    "Xz8GFJecE8Goz8Mw2NigtBC4EystXievCwR3EztDyU5PgvEQV7d+0GLKtCG6QFqC\n"
    "gZKlwzSf9rLhfXYCrWgqg7ZXsiaADQePw+fU2dudERxmg3gokBFL\n"
    "-----END RSA PRIVATE KEY-----\n";
    
    BIO *bio = BIO_new_mem_buf(pKey, -1);
    RSA *rsa = PEM_read_bio_RSAPrivateKey(bio, NULL, 0, NULL);
    BIO_free(bio);
    
    unsigned char *decrypted = (unsigned char *) malloc(1000);
    
    int decrypted_length = RSA_private_decrypt((int)[chiperData length], [chiperData bytes], decrypted, rsa, RSA_PKCS1_PADDING);
    if(decrypted_length == -1) {
        char buffer[500];
        ERR_error_string(ERR_get_error(), buffer);
        NSLog(@"%@",[NSString stringWithUTF8String:buffer]);
        return nil;
    }
    
    NSString *plain = [[NSString alloc] initWithBytes:decrypted length:decrypted_length encoding:NSUTF8StringEncoding];

    return plain;
}

#
#pragma mark - Encrypt/Decrypt Files AES/GCM/NoPadding as cipher (128 bit key size)
#

- (void)encryptMetadata:(tableMetadata *)metadata activeUrl:(NSString *)activeUrl
{
    NSMutableData *cipherData;
    NSData *tagData;
    NSString* authenticationTag;

    NSData *plainData = [[NSFileManager defaultManager] contentsAtPath:[NSString stringWithFormat:@"%@/%@", activeUrl, metadata.fileID]];
    NSData *keyData = [[NSData alloc] initWithBase64EncodedString:@"WANM0gRv+DhaexIsI0T3Lg==" options:0];
    NSData *initVectorData = [[NSData alloc] initWithBase64EncodedString:@"gKm3n+mJzeY26q4OfuZEqg==" options:0];
    
    BOOL result = [self encryptData:plainData cipherData:&cipherData keyData:keyData initVectorData:initVectorData tagData:&tagData];
    
    if (cipherData != nil && result) {
        [cipherData writeToFile:[NSString stringWithFormat:@"%@/%@", activeUrl, @"encrypted.dms"] atomically:YES];
        authenticationTag = [tagData base64EncodedStringWithOptions:0];
    }
}

- (void)decryptMetadata:(tableMetadata *)metadata activeUrl:(NSString *)activeUrl
{
    NSMutableData *plainData;
    
    NSData *cipherData = [[NSFileManager defaultManager] contentsAtPath:[NSString stringWithFormat:@"%@/%@", activeUrl, metadata.fileID]];
    NSData *keyData = [[NSData alloc] initWithBase64EncodedString:@"WANM0gRv+DhaexIsI0T3Lg==" options:0];
    NSData *initVectorData = [[NSData alloc] initWithBase64EncodedString:@"gKm3n+mJzeY26q4OfuZEqg==" options:0];
    NSString *tag = @"PboI9tqHHX3QeAA22PIu4w==";
    
    BOOL result = [self decryptData:cipherData plainData:&plainData keyData:keyData initVectorData:initVectorData tag:tag];
    
    if (plainData != nil && result) {
        [plainData writeToFile:[NSString stringWithFormat:@"%@/%@", activeUrl, @"decrypted"] atomically:YES];
    }
}

// encrypt data AES 256 GCM NOPADING
- (BOOL)encryptData:(NSData *)plainData cipherData:(NSMutableData **)cipherData keyData:(NSData *)keyData initVectorData:(NSData *)initVectorData tagData:(NSData **)tagData
{
    int status = 0;
    *cipherData = [NSMutableData dataWithLength:[plainData length]];
    
    // set up key
    unsigned char cKey[AES_KEY_LENGTH];
    bzero(cKey, sizeof(cKey));
    [keyData getBytes:cKey length:AES_KEY_LENGTH];
    
    // set up ivec
    unsigned char cIv[AES_IVEC_LENGTH];
    bzero(cIv, AES_IVEC_LENGTH);
    [initVectorData getBytes:cIv length:AES_IVEC_LENGTH];
    
    // set up to Encrypt AES 128 GCM
    int numberOfBytes = 0;
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    EVP_EncryptInit_ex (ctx, EVP_aes_128_gcm(), NULL, NULL, NULL);
    
    // set the key and ivec
    EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, AES_IVEC_LENGTH, NULL);
    EVP_EncryptInit_ex (ctx, NULL, NULL, cKey, cIv);
    
    unsigned char * ctBytes = [*cipherData mutableBytes];
    EVP_EncryptUpdate (ctx, ctBytes, &numberOfBytes, [plainData bytes], (int)[plainData length]);
    status = EVP_EncryptFinal_ex (ctx, ctBytes+numberOfBytes, &numberOfBytes);
    
    if (status && tagData) {
        
        unsigned char cTag[AES_GCM_TAG_LENGTH];
        bzero(cTag, AES_GCM_TAG_LENGTH);
        
        status = EVP_CIPHER_CTX_ctrl (ctx, EVP_CTRL_GCM_GET_TAG, AES_GCM_TAG_LENGTH, cTag);
        *tagData = [NSData dataWithBytes:cTag length:AES_GCM_TAG_LENGTH];
    }
    
    EVP_CIPHER_CTX_free(ctx);
    return (status != 0); // OpenSSL uses 1 for success
}

// decrypt data AES 256 GCM NOPADING
- (BOOL)decryptData:(NSData *)cipherData plainData:(NSMutableData **)plainData keyData:(NSData *)keyData initVectorData:(NSData *)initVectorData tag:(NSString *)tag
{    
    int status = 0;
    int numberOfBytes = 0;
    *plainData = [NSMutableData dataWithLength:[cipherData length]];
    
    // set up key
    unsigned char cKey[AES_KEY_LENGTH];
    bzero(cKey, sizeof(cKey));
    [keyData getBytes:cKey length:AES_KEY_LENGTH];
    
    // set up ivec
    unsigned char cIv[AES_IVEC_LENGTH];
    bzero(cIv, AES_IVEC_LENGTH);
    [initVectorData getBytes:cIv length:AES_IVEC_LENGTH];
    
    // set up tag
    //unsigned char cTag[AES_GCM_TAG_LENGTH];
    //bzero(cTag, AES_GCM_TAG_LENGTH);
    //[tagData getBytes:cTag length:AES_GCM_TAG_LENGTH];
    
    /* verify tag if exists*/
    if (tag) {
        
        NSData *authenticationTagData = [cipherData subdataWithRange:NSMakeRange([cipherData length] - AES_GCM_TAG_LENGTH, AES_GCM_TAG_LENGTH)];
        NSString *authenticationTag = [authenticationTagData base64EncodedStringWithOptions:0];
    
        if (![authenticationTag isEqualToString:tag])
            return NO;
    }
    
    /* Create and initialise the context */
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    
    /* Initialise the decryption operation. */
    status = EVP_DecryptInit_ex (ctx, EVP_aes_128_gcm(), NULL, NULL, NULL);
    if (! status)
        return NO;
    
    /* Set IV length. Not necessary if this is 12 bytes (96 bits) */
    status = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, AES_IVEC_LENGTH, NULL);
    if (! status)
        return NO;
    
    /* Initialise key and IV */
    status = EVP_DecryptInit_ex (ctx, NULL, NULL, cKey, cIv);
    if (! status)
        return NO;
    
    /* Provide the message to be decrypted, and obtain the plaintext output. */
    unsigned char * ctBytes = [*plainData mutableBytes];
    status = EVP_DecryptUpdate (ctx, ctBytes, &numberOfBytes, [cipherData bytes], (int)[cipherData length]);
    if (! status)
        return NO;
    
    /* Set expected tag value. Works in OpenSSL 1.0.1d and later */
    //status = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, AES_GCM_TAG_LENGTH, cTag);
    //if (!status)
    //    return NO;
    
    /* Finalise the decryption. A positive return value indicates success, anything else is a failure - the plaintext is n trustworthy. */
    //status = EVP_EncryptFinal_ex (ctx, ctBytes+numberOfBytes, &numberOfBytes);
    //if (!status)
    //    return NO;
    
    // Without test Final
    EVP_DecryptFinal_ex (ctx, NULL, &numberOfBytes);
    EVP_CIPHER_CTX_free(ctx);
    
    return status; // OpenSSL uses 1 for success
}

#
#pragma mark - Utility
#

- (NSString *)createSHA512:(NSString *)string
{
    const char *cstr = [string cStringUsingEncoding:NSUTF8StringEncoding];
    NSData *data = [NSData dataWithBytes:cstr length:string.length];
    uint8_t digest[CC_SHA512_DIGEST_LENGTH];
    CC_SHA512(data.bytes, (unsigned int)data.length, digest);
    NSMutableString* output = [NSMutableString  stringWithCapacity:CC_SHA512_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_SHA512_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    return output;
}

- (NSData *)generateIV:(int)ivLength
{
    NSMutableData  *ivData = [NSMutableData dataWithLength:ivLength];
    (void)SecRandomCopyBytes(kSecRandomDefault, ivLength, ivData.mutableBytes);
    
    return ivData;
}

- (NSString *)getMD5:(NSString *)input
{
    // Create pointer to the string as UTF8
    const char *ptr = [input cStringUsingEncoding:NSUTF8StringEncoding];
    
    // Create byte array of unsigned chars
    unsigned char md5Buffer[CC_MD5_DIGEST_LENGTH];
    
    // Create 16 byte MD5 hash value, store in buffer
    CC_MD5(ptr, (unsigned int)strlen(ptr), md5Buffer);
    
    // Convert MD5 value in the buffer to NSString of hex values
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x",md5Buffer[i]];
    
    return output;
}

- (NSString *)getSHA1:(NSString *)input
{
    const char *cstr = [input cStringUsingEncoding:NSUTF8StringEncoding];
    NSData *data = [NSData dataWithBytes:cstr length:input.length];
    
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    
    CC_SHA1(data.bytes, (unsigned int)data.length, digest);
    
    NSMutableString* output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    
    return output;
}

- (NSData *)hashValueMD5OfData:(NSData *)data
{
    MD5_CTX md5Ctx;
    unsigned char hashValue[MD5_DIGEST_LENGTH];
    if(!MD5_Init(&md5Ctx)) {
        return nil;
    }
    if (!MD5_Update(&md5Ctx, data.bytes, data.length)) {
        return nil;
    }
    if (!MD5_Final(hashValue, &md5Ctx)) {
        return nil;
    }
    return [NSData dataWithBytes:hashValue length:MD5_DIGEST_LENGTH];
}

- (NSString *)hexadecimalString:(NSData *)input
{
    const unsigned char *dataBuffer = (const unsigned char *) [input bytes];
    
    if (!dataBuffer) {
        return [NSString string];
    }
    
    NSUInteger dataLength = [input length];
    NSMutableString *hexString = [NSMutableString stringWithCapacity:(dataLength * 2)];
    
    for (int i = 0; i < dataLength; ++i) {
        [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long) dataBuffer[i]]];
    }
    
    return [NSString stringWithString:hexString];
}

- (NSString *)stringRemoveBeginEnd:(NSString *)input
{
    input = [input stringByReplacingOccurrencesOfString:@"-----BEGIN CERTIFICATE-----\n" withString:@""];
    input = [input stringByReplacingOccurrencesOfString:@"\n-----END CERTIFICATE-----" withString:@""];
    input = [input stringByReplacingOccurrencesOfString:@"-----BEGIN PRIVATE KEY-----\n" withString:@""];
    input = [input stringByReplacingOccurrencesOfString:@"\n-----END PRIVATE KEY-----" withString:@""];
    
    return input;
}

@end
