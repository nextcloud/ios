//
//  NCEndToEndEncryption.m
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

#import "NCEndToEndEncryption.h"
#import "NCBridgeSwift.h"
#import "CCUtility.h"

#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonKeyDerivation.h>
#import <OpenSSL/OpenSSL.h>

#define addName(field, value) X509_NAME_add_entry_by_txt(name, field, MBSTRING_ASC, (unsigned char *)value, -1, -1, 0); NSLog(@"%s: %s", field, value);

#define IV_DELIMITER_ENCODED_OLD    @"fA=="
#define IV_DELIMITER_ENCODED        @"|"
#define PBKDF2_INTERACTION_COUNT    1024
#define PBKDF2_KEY_LENGTH           256
//#define PBKDF2_SALT                 @"$4$YmBjm3hk$Qb74D5IUYwghUmzsMqeNFx5z0/8$"

#define ASYMMETRIC_STRING_TEST      @"Nextcloud a safe home for all your data"

#define fileNameCertificate         @"cert.pem"
#define fileNameCSR                 @"csr.pem"
#define fileNamePrivateKey          @"privateKey.pem"
#define fileNamePubliceKey          @"publicKey.pem"

#define AES_KEY_128_LENGTH          16
#define AES_KEY_256_LENGTH          32
#define AES_IVEC_LENGTH             16
#define AES_GCM_TAG_LENGTH          16
#define AES_SALT_LENGTH             40

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

- (BOOL)generateCertificateX509WithUserID:(NSString *)userID directory:(NSString *)directory
{
    OPENSSL_init();
    
    EVP_PKEY * pkey;
    pkey = EVP_PKEY_new();
    
    RSA * rsa;
    rsa = RSA_generate_key(
                           2048, /* number of bits for the key - 2048 is a sensible value */
                           RSA_F4, /* exponent - RSA_F4 is defined as 0x10001L */
                           NULL, /* callback - can be NULL if we aren't displaying progress */
                           NULL /* callback argument - not needed in this case */
                           );
    
    EVP_PKEY_assign_RSA(pkey, rsa);
    
    X509 * x509;
    x509 = X509_new();
    
    ASN1_INTEGER_set(X509_get_serialNumber(x509), 1);
    
    long notBefore = [[NSDate date] timeIntervalSinceDate:[NSDate date]];
    long notAfter = [[[NSDate date] dateByAddingTimeInterval:60*60*24*365*10] timeIntervalSinceDate:[NSDate date]]; // 10 year
    X509_gmtime_adj(X509_get_notBefore(x509), notBefore);
    X509_gmtime_adj(X509_get_notAfter(x509), notAfter);
    
    X509_set_pubkey(x509, pkey);
    
    X509_NAME * name;
    name = X509_get_subject_name(x509);
    
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
    NSLog(@"[LOG] \n%@", [[NSString alloc] initWithData:_csrData encoding:NSUTF8StringEncoding]);
    
    // PublicKey
    BIO *publicKeyBIO = BIO_new(BIO_s_mem());
    PEM_write_bio_PUBKEY(publicKeyBIO, pkey);
    
    len = BIO_pending(publicKeyBIO);
    keyBytes  = malloc(len);
    
    BIO_read(publicKeyBIO, keyBytes, len);
    _publicKeyData = [NSData dataWithBytes:keyBytes length:len];
    NSLog(@"[LOG] \n%@", [[NSString alloc] initWithData:_publicKeyData encoding:NSUTF8StringEncoding]);
    
    // PrivateKey
    BIO *privateKeyBIO = BIO_new(BIO_s_mem());
    PEM_write_bio_PKCS8PrivateKey(privateKeyBIO, pkey, NULL, NULL, 0, NULL, NULL);
    
    len = BIO_pending(privateKeyBIO);
    keyBytes = malloc(len);
    
    BIO_read(privateKeyBIO, keyBytes, len);
    _privateKeyData = [NSData dataWithBytes:keyBytes length:len];
    NSLog(@"[LOG] \n%@", [[NSString alloc] initWithData:_privateKeyData encoding:NSUTF8StringEncoding]);
    
    if(keyBytes)
        free(keyBytes);
    
    #ifdef DEBUG
    // Save to disk [DEBUG MODE]
    [self saveToDiskPEMWithCert:x509 key:pkey directory:directory];
    #endif
    
    return YES;
}

- (BOOL)saveToDiskPEMWithCert:(X509 *)x509 key:(EVP_PKEY *)pkey directory:(NSString *)directory
{
    FILE *f;
    
    // Certificate
    NSString *certificatePath = [NSString stringWithFormat:@"%@/%@", directory, fileNameCertificate];
    f = fopen([certificatePath fileSystemRepresentation], "wb");
    if (PEM_write_X509(f, x509) < 0) {
        // Error writing to disk.
        fclose(f);
        return NO;
    }
    NSLog(@"[LOG] Saved cert to %@", certificatePath);
    fclose(f);
    
    // PublicKey
    NSString *publicKeyPath = [NSString stringWithFormat:@"%@/%@", directory, fileNamePubliceKey];
    f = fopen([publicKeyPath fileSystemRepresentation], "wb");
    if (PEM_write_PUBKEY(f, pkey) < 0) {
        // Error
        fclose(f);
        return NO;
    }
    NSLog(@"[LOG] Saved publicKey to %@", publicKeyPath);
    fclose(f);
    
    // Here you write the private key (pkey) to disk. OpenSSL will encrypt the
    // file using the password and cipher you provide.
    //if (PEM_write_PrivateKey(f, pkey, EVP_des_ede3_cbc(), (unsigned char *)[password UTF8String], (int)password.length, NULL, NULL) < 0) {
    
    // PrivateKey
    NSString *privatekeyPath = [NSString stringWithFormat:@"%@/%@", directory, fileNamePrivateKey];
    f = fopen([privatekeyPath fileSystemRepresentation], "wb");
    if (PEM_write_PrivateKey(f, pkey, NULL, NULL, 0, NULL, NULL) < 0) {
        // Error
        fclose(f);
        return NO;
    }
    NSLog(@"[LOG] Saved privatekey to %@", privatekeyPath);
    fclose(f);
    
    // CSR Request sha256
    NSString *csrPath = [NSString stringWithFormat:@"%@/%@", directory, fileNameCSR];
    f = fopen([csrPath fileSystemRepresentation], "wb");
    X509_REQ *certreq = X509_to_X509_REQ(x509, pkey, EVP_sha256());
    if (PEM_write_X509_REQ(f, certreq) < 0) {
        // Error
        fclose(f);
        return NO;
    }
    NSLog(@"[LOG] Saved csr to %@", csrPath);
    fclose(f);
    
    return YES;
}

- (BOOL)saveP12WithCert:(X509 *)x509 key:(EVP_PKEY *)pkey directory:(NSString *)directory finished:(void (^)(NSError *))finished
{
    //PKCS12 * p12 = PKCS12_create([password UTF8String], NULL, pkey, x509, NULL, 0, 0, PKCS12_DEFAULT_ITER, 1, NID_key_usage);
    PKCS12 *p12 = PKCS12_create(NULL, NULL, pkey, x509, NULL, 0, 0, PKCS12_DEFAULT_ITER, 1, NID_key_usage);
    
    NSString *path = [NSString stringWithFormat:@"%@/certificate.p12", directory];
    
    FILE *f = fopen([path fileSystemRepresentation], "wb");
    
    if (i2d_PKCS12_fp(f, p12) != 1) {
        fclose(f);
        return NO;
    }
    NSLog(@"[LOG] Saved p12 to %@", path);
    fclose(f);
    
    return YES;
}

#
#pragma mark - Create CSR & Encrypt/Decrypt Private Key
#

- (NSString *)createCSR:(NSString *)userID directory:(NSString *)directory
{
    // Create Certificate, if do not exists
    if (!_csrData) {
        if (![self generateCertificateX509WithUserID:userID directory:directory])
            return nil;
    }
    
    NSString *csr = [[NSString alloc] initWithData:_csrData encoding:NSUTF8StringEncoding];
    
    return csr;
}

- (NSString *)encryptPrivateKey:(NSString *)userID directory:(NSString *)directory passphrase:(NSString *)passphrase privateKey:(NSString **)privateKey
{
    NSMutableData *privateKeyCipherData = [NSMutableData new];

    if (!_privateKeyData) {
        if (![self generateCertificateX509WithUserID:userID directory:directory])
            return nil;
    }
    
    NSMutableData *keyData = [NSMutableData dataWithLength:PBKDF2_KEY_LENGTH/8];
    NSData *saltData = [self generateSalt:AES_SALT_LENGTH];
    
    // Remove all whitespaces from passphrase
    passphrase = [passphrase stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    CCKeyDerivationPBKDF(kCCPBKDF2, passphrase.UTF8String, passphrase.length, saltData.bytes, saltData.length, kCCPRFHmacAlgSHA1, PBKDF2_INTERACTION_COUNT, keyData.mutableBytes, keyData.length);
    
    NSData *ivData = [self generateIV:AES_IVEC_LENGTH];
    NSData *tagData = [NSData new];
    
    /* ENCODE 64 privateKey JAVA compatibility */
    NSString *privateKeyBase64 = [_privateKeyData base64EncodedStringWithOptions:0];
    NSData *privateKeyBase64Data = [privateKeyBase64 dataUsingEncoding:NSUTF8StringEncoding];
    /* --------------------------------------- */
    
    BOOL result = [self encryptData:privateKeyBase64Data cipherData:&privateKeyCipherData keyData:keyData keyLen:AES_KEY_256_LENGTH ivData:ivData tagData:&tagData];
    
    if (result && privateKeyCipherData) {
        
        NSString *privateKeyCipherBase64 = [privateKeyCipherData base64EncodedStringWithOptions:0];
        NSString *initVectorBase64 = [ivData base64EncodedStringWithOptions:0];
        NSString *saltBase64 = [saltData base64EncodedStringWithOptions:0];
        NSString *privateKeyCipherWithInitVectorBase64 = [NSString stringWithFormat:@"%@%@%@%@%@", privateKeyCipherBase64, IV_DELIMITER_ENCODED, initVectorBase64, IV_DELIMITER_ENCODED, saltBase64];
        
        *privateKey = [[NSString alloc] initWithData:_privateKeyData encoding:NSUTF8StringEncoding];
        return privateKeyCipherWithInitVectorBase64;
        
    } else {
        
        return nil;
    }
}

- (NSString *)decryptPrivateKey:(NSString *)privateKeyCipher passphrase:(NSString *)passphrase publicKey:(NSString *)publicKey
{
    NSMutableData *privateKeyData = [NSMutableData new];
    NSString *privateKey;
    
    // Key (data)
    NSMutableData *keyData = [NSMutableData dataWithLength:PBKDF2_KEY_LENGTH/8];
    
    // Split
    NSArray *privateKeyCipherArray = [privateKeyCipher componentsSeparatedByString:IV_DELIMITER_ENCODED];
    if (privateKeyCipherArray.count != 3) {
        privateKeyCipherArray = [privateKeyCipher componentsSeparatedByString:IV_DELIMITER_ENCODED_OLD];
        if (privateKeyCipherArray.count != 3) {
            return nil;
        }
    }
    
    NSData *privateKeyCipherData = [[NSData alloc] initWithBase64EncodedString:privateKeyCipherArray[0] options:0];
    NSString *tagBase64 = [privateKeyCipher substringWithRange:NSMakeRange([(NSString *)privateKeyCipherArray[0] length] - AES_GCM_TAG_LENGTH, AES_GCM_TAG_LENGTH)];
    NSData *tagData = [[NSData alloc] initWithBase64EncodedString:tagBase64 options:0];
    NSData *ivData = [[NSData alloc] initWithBase64EncodedString:privateKeyCipherArray[1] options:0];
    NSData *saltData = [[NSData alloc] initWithBase64EncodedString:privateKeyCipherArray[2] options:0];
    
    // Remove all whitespaces from passphrase
    passphrase = [passphrase stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    CCKeyDerivationPBKDF(kCCPBKDF2, passphrase.UTF8String, passphrase.length, saltData.bytes, saltData.length, kCCPRFHmacAlgSHA1, PBKDF2_INTERACTION_COUNT, keyData.mutableBytes, keyData.length);
    
    BOOL result = [self decryptData:privateKeyCipherData plainData:&privateKeyData keyData:keyData keyLen:AES_KEY_256_LENGTH ivData:ivData tagData:tagData];
    
    if (result && privateKeyData)
        
        /* DENCODE 64 privateKey JAVA compatibility */
        privateKey = [self base64DecodeData:privateKeyData];
        /* ---------------------------------------- */
    
        if (privateKey) {
        
            NSData *encryptData = [self encryptAsymmetricString:ASYMMETRIC_STRING_TEST publicKey:publicKey privateKey:nil];
            if (!encryptData)
                return nil;
        
            NSString *decryptString = [self decryptAsymmetricData:encryptData privateKey:privateKey];
        
            if (decryptString && [decryptString isEqualToString:ASYMMETRIC_STRING_TEST])
                return privateKey;
            else
                return nil;
            
            return privateKey;
            
    } else {
        
        return nil;
    }
}

#
#pragma mark - Encrypt / Decrypt Encrypted Json
#

- (NSString *)encryptEncryptedJson:(NSString *)encrypted key:(NSString *)key
{
    NSMutableData *cipherData;
    NSData *tagData = [NSData new];
    
    // ENCODE 64 encrypted JAVA compatibility */
    NSData *encryptedData = [encrypted dataUsingEncoding:NSUTF8StringEncoding];
    NSString *encryptedDataBase64 = [encryptedData base64EncodedStringWithOptions:0];
    NSData *encryptedData64Data = [encryptedDataBase64 dataUsingEncoding:NSUTF8StringEncoding];
    /* --------------------------------------- */
    
    // Key
    NSData *keyData = [[NSData alloc] initWithBase64EncodedString:key options:0];

    // IV
    NSData *ivData = [self generateIV:AES_IVEC_LENGTH];
    
    BOOL result = [self encryptData:encryptedData64Data cipherData:&cipherData keyData:keyData keyLen:AES_KEY_128_LENGTH ivData:ivData tagData:&tagData];
    
    if (cipherData != nil && result) {
        
        NSString *cipherBase64 = [cipherData base64EncodedStringWithOptions:0];
        NSString *ivBase64 = [ivData base64EncodedStringWithOptions:0];
        NSString *encryptedJson = [NSString stringWithFormat:@"%@%@%@", cipherBase64, IV_DELIMITER_ENCODED, ivBase64];
        
        return encryptedJson;
    }
    
    return nil;
}

- (NSString *)decryptEncryptedJson:(NSString *)encrypted key:(NSString *)key
{
    NSMutableData *plainData;
    NSRange range = [encrypted rangeOfString:IV_DELIMITER_ENCODED];
    if (range.location == NSNotFound) {
        range = [encrypted rangeOfString:IV_DELIMITER_ENCODED_OLD];
        if (range.location == NSNotFound) {
            return nil;
        }
    }
    
    // Cipher
    NSString *cipher = [encrypted substringToIndex:(range.location)];
    NSData *cipherData = [[NSData alloc] initWithBase64EncodedString:cipher options:0];
    
    // Key
    NSData *keyData = [[NSData alloc] initWithBase64EncodedString:key options:0];
    
    // IV
    NSString *iv  = [encrypted substringWithRange:NSMakeRange(range.location + range.length, encrypted.length - (range.location + range.length))];
    NSData *ivData = [[NSData alloc] initWithBase64EncodedString:iv options:0];

    // TAG
    NSString *tag = [cipher substringWithRange:NSMakeRange(cipher.length - AES_GCM_TAG_LENGTH, AES_GCM_TAG_LENGTH)];
    NSData *tagData = [[NSData alloc] initWithBase64EncodedString:tag options:0];
    
    BOOL result = [self decryptData:cipherData plainData:&plainData keyData:keyData keyLen:AES_KEY_128_LENGTH ivData:ivData tagData:tagData];
    
    if (plainData != nil && result) {
        
        /* DENCODE 64 JAVA compatibility            */
        NSString *plain = [self base64DecodeData:plainData];
        /* ---------------------------------------- */
    
        return plain;
    }
        
    return nil;
}

#
#pragma mark - Encrypt / Decrypt file
#

- (void)encryptkey:(NSString **)key initializationVector:(NSString **)initializationVector
{
    NSData *keyData = [self generateKey:AES_KEY_128_LENGTH];
    NSData *ivData = [self generateIV:AES_IVEC_LENGTH];
    
    *key = [keyData base64EncodedStringWithOptions:0];
    *initializationVector = [ivData base64EncodedStringWithOptions:0];
}


- (BOOL)encryptFileName:(NSString *)fileName fileNameIdentifier:(NSString *)fileNameIdentifier directory:(NSString *)directory key:(NSString **)key initializationVector:(NSString **)initializationVector authenticationTag:(NSString **)authenticationTag
{
    NSMutableData *cipherData;
    NSData *tagData;
   
    NSData *plainData = [[NSFileManager defaultManager] contentsAtPath:[NSString stringWithFormat:@"%@/%@", directory, fileName]];
    if (plainData == nil)
        return false;
    
    NSData *keyData = [self generateKey:AES_KEY_128_LENGTH];
    NSData *ivData = [self generateIV:AES_IVEC_LENGTH];
    
    BOOL result = [self encryptData:plainData cipherData:&cipherData keyData:keyData keyLen:AES_KEY_128_LENGTH ivData:ivData tagData:&tagData];
    
    if (cipherData != nil && result) {
        
        [cipherData writeToFile:[NSString stringWithFormat:@"%@/%@", directory, fileNameIdentifier] atomically:YES];
        
        *key = [keyData base64EncodedStringWithOptions:0];
        *initializationVector = [ivData base64EncodedStringWithOptions:0];
        *authenticationTag = [tagData base64EncodedStringWithOptions:0];

        if (key == nil || initializationVector == nil || authenticationTag == nil) {
            return false;
        } else {
            return true;
        }
    }
    
    return false;
}

- (BOOL)decryptFileName:(NSString *)fileName fileNameView:(NSString *)fileNameView ocId:(NSString *)ocId key:(NSString *)key initializationVector:(NSString *)initializationVector authenticationTag:(NSString *)authenticationTag
{
    NSMutableData *plainData;

    NSData *cipherData = [[NSFileManager defaultManager] contentsAtPath:[CCUtility getDirectoryProviderStorageOcId:ocId fileNameView:fileName]];
    if (cipherData == nil)
        return false;
    
    NSData *keyData = [[NSData alloc] initWithBase64EncodedString:key options:0];
    NSData *ivData = [[NSData alloc] initWithBase64EncodedString:initializationVector options:0];
    NSData *tagData = [[NSData alloc] initWithBase64EncodedString:authenticationTag options:0];

    BOOL result = [self decryptData:cipherData plainData:&plainData keyData:keyData keyLen:AES_KEY_128_LENGTH ivData:ivData tagData:tagData];
    if (plainData != nil && result) {
        [plainData writeToFile:[CCUtility getDirectoryProviderStorageOcId:ocId fileNameView:fileNameView] atomically:YES];
        return true;
    }
    
    return false;
}

// -----------------------------------------------------------------------------------------------------------------------------------------------------------------------
// -----------------------------------------------------------------------------------------------------------------------------------------------------------------------

#
#pragma mark - OPENSSL ENCRYPT/DECRYPT
#


#
#pragma mark - Asymmetric Encrypt/Decrypt String
#

- (NSData *)encryptAsymmetricString:(NSString *)plain publicKey:(NSString *)publicKey privateKey:(NSString *)privateKey
{
    ENGINE *eng = ENGINE_get_default_RSA();
    EVP_PKEY *key = NULL;
    int status = 0;
    
    if (publicKey != nil) {
        
        unsigned char *pKey = (unsigned char *)[publicKey UTF8String];

        // Extract real publicKey
        BIO *bio = BIO_new_mem_buf(pKey, -1);
        if (!bio)
            return nil;
        
        X509 *x509 = PEM_read_bio_X509(bio, NULL, 0, NULL);
        if (!x509)
            return nil;
        
        key = X509_get_pubkey(x509);
        if (!key)
            return nil;
    }
    
    if (privateKey != nil) {
        
        unsigned char *pKey = (unsigned char *)[privateKey UTF8String];

        BIO *bio = BIO_new_mem_buf(pKey, -1);
        if (!bio)
            return nil;
        
        key = PEM_read_bio_PrivateKey(bio, NULL, NULL, NULL);
        if (!key)
            return nil;
    }
    
    EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new(key, eng);
    if (!ctx)
        return nil;
    
    status = EVP_PKEY_encrypt_init(ctx);
    if (status <= 0)
        return nil;
    
    status = EVP_PKEY_CTX_set_rsa_padding(ctx, RSA_PKCS1_OAEP_PADDING);
    if (status <= 0)
        return nil;
    
    status = EVP_PKEY_CTX_set_rsa_oaep_md(ctx, EVP_sha256());
    if (status <= 0)
        return nil;
    
    status = EVP_PKEY_CTX_set_rsa_mgf1_md(ctx, EVP_sha256());
    if (status <= 0)
        return nil;
    
    unsigned long outLen = 0;
    NSData *plainData = [plain dataUsingEncoding:NSUTF8StringEncoding];
    status = EVP_PKEY_encrypt(ctx, NULL, &outLen, [plainData bytes], (int)[plainData length]);
    if (status <= 0 || outLen == 0)
        return nil;
    
    unsigned char *out = (unsigned char *) malloc(outLen);
    status = EVP_PKEY_encrypt(ctx, out, &outLen, [plainData bytes], (int)[plainData length]);
    if (status <= 0)
        return nil;
    
    NSData *outData = [[NSData alloc] initWithBytes:out length:outLen];
    
    if (out)
        free(out);
    
    return outData;
}

- (NSString *)decryptAsymmetricData:(NSData *)cipherData privateKey:(NSString *)privateKey
{
    unsigned char *pKey = (unsigned char *)[privateKey UTF8String];
    ENGINE *eng = ENGINE_get_default_RSA();
    int status = 0;
    
    BIO *bio = BIO_new_mem_buf(pKey, -1);
    if (!bio)
        return nil;
    
    EVP_PKEY *key = PEM_read_bio_PrivateKey(bio, NULL, NULL, NULL);
    if (!key)
        return nil;
    
    EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new(key, eng);
    if (!ctx)
        return nil;
    
    status = EVP_PKEY_decrypt_init(ctx);
    if (status <= 0)
        return nil;
    
    status = EVP_PKEY_CTX_set_rsa_padding(ctx, RSA_PKCS1_OAEP_PADDING);
    if (status <= 0)
        return nil;
    
    status = EVP_PKEY_CTX_set_rsa_oaep_md(ctx, EVP_sha256());
    if (status <= 0)
        return nil;
    
    status = EVP_PKEY_CTX_set_rsa_mgf1_md(ctx, EVP_sha256());
    if (status <= 0)
        return nil;
    
    unsigned long outLen = 0;
    status = EVP_PKEY_decrypt(ctx, NULL, &outLen, [cipherData bytes], (int)[cipherData length]);
    if (status <= 0 || outLen == 0)
        return nil;
    
    unsigned char *out = (unsigned char *) malloc(outLen);
    status = EVP_PKEY_decrypt(ctx, out, &outLen, [cipherData bytes], (int)[cipherData length]);
    if (status <= 0)
        return nil;
    
    NSString *outString = [[NSString alloc] initWithBytes:out length:outLen encoding:NSUTF8StringEncoding];
    
    if (out)
        free(out);
    
    return outString;
}

#
#pragma mark - AES/GCM/NoPadding
#

// Encryption using GCM mode
- (BOOL)encryptData:(NSData *)plainData cipherData:(NSMutableData **)cipherData keyData:(NSData *)keyData keyLen:(int)keyLen ivData:(NSData *)ivData tagData:(NSData **)tagData
{
    int status = 0;
    int len = 0;
    
    // set up key
    len = keyLen;
    unsigned char cKey[len];
    bzero(cKey, sizeof(cKey));
    [keyData getBytes:cKey length:len];

    // set up ivec
    len = AES_IVEC_LENGTH;
    unsigned char cIV[len];
    bzero(cIV, sizeof(cIV));
    [ivData getBytes:cIV length:len];
    
    // set up tag
    len = AES_GCM_TAG_LENGTH;
    unsigned char cTag[len];
    bzero(cTag, sizeof(cTag));
    
    // Create and initialise the context
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx)
        return NO;
    
    // Initialise the encryption operation
    if (keyLen == AES_KEY_128_LENGTH)
        status = EVP_EncryptInit_ex(ctx, EVP_aes_128_gcm(), NULL, NULL, NULL);
    else if (keyLen == AES_KEY_256_LENGTH)
        status = EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, NULL, NULL);
    
    if (status <= 0)
        return NO;
    
    // Set IV length. Not necessary if this is 12 bytes (96 bits)
    status = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, (int)sizeof(cIV), NULL);
    if (status <= 0)
        return NO;
    
    // Initialise key and IV
    status = EVP_EncryptInit_ex (ctx, NULL, NULL, cKey, cIV);
    if (status <= 0)
        return NO;
    
    // Provide the message to be encrypted, and obtain the encrypted output
    *cipherData = [NSMutableData dataWithLength:[plainData length]];
    unsigned char * cCipher = [*cipherData mutableBytes];
    int cCipherLen = 0;
    status = EVP_EncryptUpdate(ctx, cCipher, &cCipherLen, [plainData bytes], (int)[plainData length]);
    if (status <= 0)
        return NO;
    
    // Finalise the encryption
    len = cCipherLen;
    status = EVP_EncryptFinal_ex(ctx, cCipher+cCipherLen, &len);
    if (status <= 0)
        return NO;
    
    // Get the tag
    status = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, (int)sizeof(cTag), cTag);
    *tagData = [NSData dataWithBytes:cTag length:sizeof(cTag)];
    
    // Add TAG JAVA compatibility
    [*cipherData appendData:*tagData];
    // --------------------------
    
    // Free
    EVP_CIPHER_CTX_free(ctx);
    
    return status; // OpenSSL uses 1 for success
}

// Decryption using GCM mode
- (BOOL)decryptData:(NSData *)cipherData plainData:(NSMutableData **)plainData keyData:(NSData *)keyData keyLen:(int)keyLen ivData:(NSData *)ivData tagData:(NSData *)tagData
{    
    int status = 0;
    int len = 0;
    
    // set up key
    len = keyLen;
    unsigned char cKey[len];
    bzero(cKey, sizeof(cKey));
    [keyData getBytes:cKey length:len];
    
    // set up ivec
    len = (int)[ivData length];
    unsigned char cIV[len];
    bzero(cIV, sizeof(cIV));
    [ivData getBytes:cIV length:len];
   
    // set up tag
    len = (int)[tagData length];;
    unsigned char cTag[len];
    bzero(cTag, sizeof(cTag));
    [tagData getBytes:cTag length:len];

    // Create and initialise the context
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx)
        return NO;
    
    // Initialise the decryption operation
    if (keyLen == AES_KEY_128_LENGTH)
        status = EVP_DecryptInit_ex(ctx, EVP_aes_128_gcm(), NULL, NULL, NULL);
    else if (keyLen == AES_KEY_256_LENGTH)
        status = EVP_DecryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, NULL, NULL);
    
    if (status <= 0)
        return NO;
    
    // Set IV length. Not necessary if this is 12 bytes (96 bits)
    status = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, (int)sizeof(cIV), NULL);
    if (status <= 0)
        return NO;
    
    // Initialise key and IV
    status = EVP_DecryptInit_ex(ctx, NULL, NULL, cKey, cIV);
    if (status <= 0)
        return NO;
    
    // Remove TAG JAVA compatibility
    cipherData = [cipherData subdataWithRange:NSMakeRange(0, cipherData.length - AES_GCM_TAG_LENGTH)];
    // -----------------------------
    
    // Provide the message to be decrypted, and obtain the plaintext output
    *plainData = [NSMutableData dataWithLength:([cipherData length])];
    int cPlainLen = 0;
    unsigned char * cPlain = [*plainData mutableBytes];
    status = EVP_DecryptUpdate(ctx, cPlain, &cPlainLen, [cipherData bytes], (int)([cipherData length]));
    if (status <= 0)
        return NO;
    
    // Tag is the last 16 bytes
    status = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, (int)sizeof(cTag), cTag);
    if (status <= 0)
        return NO;
    
    // Finalise the encryption
    EVP_DecryptFinal_ex(ctx,NULL, &cPlainLen);
    
    // Free
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

- (NSData *)generateIV:(int)length
{
    NSMutableData *ivData = [NSMutableData dataWithLength:length];
    (void)SecRandomCopyBytes(kSecRandomDefault, length, ivData.mutableBytes);
    
    return ivData;
}

- (NSData *)generateSalt:(int)length
{
    NSMutableData *saltData = [NSMutableData dataWithLength:length];
    (void)SecRandomCopyBytes(kSecRandomDefault, length, saltData.mutableBytes);
    
    return saltData;
}

- (NSData *)generateKey:(int)length
{
    NSMutableData *keyData = [NSMutableData dataWithLength:length];
    unsigned char *pKeyData = [keyData mutableBytes];

    RAND_bytes(pKeyData, length);
    
    return keyData;
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

/*
- (NSData *)base64Encode:(NSData *)input
{
    void *bytes;

    BIO *buffer = BIO_new(BIO_s_mem());
    BIO *base64 = BIO_new(BIO_f_base64());
    buffer = BIO_push(base64, buffer);
    BIO_write(buffer, [input bytes], (int)[input length]);
    
    NSUInteger length = BIO_get_mem_data(buffer, &bytes);
    NSString *string = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
    
    BIO_free_all(buffer);
    
    return [string dataUsingEncoding:NSUTF8StringEncoding];
}
*/

- (NSString *)base64DecodeData:(NSData *)input
{
    NSMutableData *data = [NSMutableData data];

    BIO *buffer = BIO_new_mem_buf((void *)[input bytes], (int)[input length]);
    BIO *base64 = BIO_new(BIO_f_base64());
    buffer = BIO_push(base64, buffer);
    BIO_set_flags(base64, BIO_FLAGS_BASE64_NO_NL);
    
    char chars[input.length];
    int length = BIO_read(buffer, chars, (int)sizeof(chars));
    while (length > 0) {
        [data appendBytes:chars length:length];
        length = BIO_read(buffer, chars, (int)sizeof(chars));
    }
    
    BIO_free_all(buffer);
    
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (NSData *)base64DecodeString:(NSString *)input
{
    NSMutableData *data = [NSMutableData data];
    
    NSData *inputData = [input dataUsingEncoding:NSUTF8StringEncoding];

    BIO *buffer = BIO_new_mem_buf((void *)[inputData bytes], (int)[inputData length]);
    BIO *base64 = BIO_new(BIO_f_base64());
    buffer = BIO_push(base64, buffer);
    BIO_set_flags(base64, BIO_FLAGS_BASE64_NO_NL);
    
    char chars[input.length];
    int length = BIO_read(buffer, chars, (int)sizeof(chars));
    while (length > 0) {
        [data appendBytes:chars length:length];
        length = BIO_read(buffer, chars, (int)sizeof(chars));
    }
    
    BIO_free_all(buffer);
    
    return data;
}

- (NSString *)derToPemPrivateKey:(NSString *)input
{
    NSInteger substringLength = 65;

    NSMutableString *result = [NSMutableString stringWithString: input];
    for(long i=substringLength;i<=input.length;i++) {
        [result insertString: @"\n" atIndex: i];
        i+=substringLength;
    }
    
    [result insertString: @"-----BEGIN PRIVATE KEY-----\n" atIndex: 0];
    [result appendString:@"\n-----END PRIVATE KEY-----\n"];

    return result;
}

@end
