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

#define IV_DELIMITER_ENCODED        @"fA==" // "|" base64 encoded
#define PBKDF2_INTERACTION_COUNT    1024
#define PBKDF2_KEY_LENGTH           256
#define PBKDF2_SALT                 @"$4$YmBjm3hk$Qb74D5IUYwghUmzsMqeNFx5z0/8$"

#define RSA_CIPHER                  RSA_PKCS1_PADDING
#define ASYMMETRIC_STRING_TEST      @"Nextcloud a safe home for all your data"

#define fileNameCertificate         @"cert.pem"
#define fileNameCSR                 @"csr.pem"
#define fileNamePrivateKey          @"privateKey.pem"
#define fileNamePubliceKey          @"publicKey.pem"

#define AES_KEY_128_LENGTH          16
#define AES_KEY_256_LENGTH          32
#define AES_IVEC_LENGTH             16
#define AES_GCM_TAG_LENGTH          16

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
    NSLog(@"[LOG] Saved cert to %@", certificatePath);
    fclose(f);
    
    // PublicKey
    NSString *publicKeyPath = [NSString stringWithFormat:@"%@/%@", directoryUser, fileNamePubliceKey];
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
    NSString *privatekeyPath = [NSString stringWithFormat:@"%@/%@", directoryUser, fileNamePrivateKey];
    f = fopen([privatekeyPath fileSystemRepresentation], "wb");
    if (PEM_write_PrivateKey(f, pkey, NULL, NULL, 0, NULL, NULL) < 0) {
        // Error
        fclose(f);
        return NO;
    }
    NSLog(@"[LOG] Saved privatekey to %@", privatekeyPath);
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
    NSLog(@"[LOG] Saved csr to %@", csrPath);
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
    NSLog(@"[LOG] Saved p12 to %@", path);
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
    
    NSMutableData *keyData = [NSMutableData dataWithLength:PBKDF2_KEY_LENGTH/8];
    NSData *saltData = [PBKDF2_SALT dataUsingEncoding:NSUTF8StringEncoding];
    
    // Remove all whitespaces from passphrase
    passphrase = [passphrase stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    CCKeyDerivationPBKDF(kCCPBKDF2, passphrase.UTF8String, passphrase.length, saltData.bytes, saltData.length, kCCPRFHmacAlgSHA1, PBKDF2_INTERACTION_COUNT, keyData.mutableBytes, keyData.length);
    
    NSData *initVectorData = [self generateIV:AES_IVEC_LENGTH];

    BOOL result = [self encryptData:_privateKeyData cipherData:&privateKeyCipherData keyData:keyData keyLen:AES_KEY_256_LENGTH initVectorData:initVectorData tagData:nil];
    
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
    NSMutableData *keyData = [NSMutableData dataWithLength:PBKDF2_KEY_LENGTH/8];
    NSData *saltData = [PBKDF2_SALT dataUsingEncoding:NSUTF8StringEncoding];
    
    // Remove all whitespaces from passphrase
    passphrase = [passphrase stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    CCKeyDerivationPBKDF(kCCPBKDF2, passphrase.UTF8String, passphrase.length, saltData.bytes, saltData.length, kCCPRFHmacAlgSHA1, PBKDF2_INTERACTION_COUNT, keyData.mutableBytes, keyData.length);
    
    // Find range for IV_DELIMITER_ENCODED
    NSRange range = [privateKeyCipher rangeOfString:IV_DELIMITER_ENCODED];
   
    // Init Vector
    NSString *ivBase64 = [privateKeyCipher substringFromIndex:(range.location + range.length)];
    NSData *ivData = [[NSData alloc] initWithBase64EncodedString:ivBase64 options:0];
    
    // TAG
    NSString *tagBase64 = [privateKeyCipher substringWithRange:NSMakeRange(range.location - AES_GCM_TAG_LENGTH, AES_GCM_TAG_LENGTH)];
    NSData *tagData = [[NSData alloc] initWithBase64EncodedString:tagBase64 options:0];
    
    // PrivateKey
    NSString *privateKeyCipherBase64 = [privateKeyCipher substringToIndex:(range.location)];
    NSData *privateKeyCipherData = [[NSData alloc] initWithBase64EncodedString:privateKeyCipherBase64 options:0];
    
    BOOL result = [self decryptData:privateKeyCipherData plainData:&privateKeyData keyData:keyData keyLen:AES_KEY_256_LENGTH ivData:ivData tagData:tagData];
    
    if (result && privateKeyData) {
        
        NSString *privateKey = [self base64Decode:privateKeyData];
        privateKey = [self structPEMFormat:privateKey];
        
        NSData *encryptData = [self encryptAsymmetricString:ASYMMETRIC_STRING_TEST publicKey:publicKey];
        if (!encryptData)
            return nil;
        
        NSString *decryptString = [self decryptAsymmetricData:encryptData privateKey:privateKey];
        
        if (decryptString && [decryptString isEqualToString:ASYMMETRIC_STRING_TEST])
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
    unsigned char *pKey = (unsigned char *)[publicKey UTF8String];
    
    // Extract real publicKey
    BIO *bio = BIO_new_mem_buf(pKey, -1);
    if (bio == NULL)
        return nil;
    X509 *x509 = PEM_read_bio_X509(bio, NULL, 0, NULL);
    if (x509 == NULL)
        return nil;
    EVP_PKEY *evpkey = X509_get_pubkey(x509);
    if (evpkey == NULL)
        return nil;
    RSA *rsa = EVP_PKEY_get1_RSA(evpkey);
    if (rsa == NULL)
        return nil;

    unsigned char *encrypted = (unsigned char *) malloc(4096);
    
    int encrypted_length = RSA_public_encrypt((int)[plainData length], [plainData bytes], encrypted, rsa, RSA_CIPHER);
    if(encrypted_length == -1) {
        char buffer[500];
        ERR_error_string(ERR_get_error(), buffer);
        NSLog(@"[LOG]  %@",[NSString stringWithUTF8String:buffer]);
        return nil;
    }
    
    NSData *encryptData = [[NSData alloc] initWithBytes:encrypted length:encrypted_length];
    
    if (encrypted)
        free(encrypted);
    free(rsa);
    
    return encryptData;
}

- (NSString *)decryptAsymmetricData:(NSData *)chiperData privateKey:(NSString *)privateKey
{
    unsigned char *pKey = (unsigned char *)[privateKey UTF8String];
    
    BIO *bio = BIO_new_mem_buf(pKey, -1);
    if (bio == NULL)
        return nil;
    RSA *rsa = PEM_read_bio_RSAPrivateKey(bio, NULL, 0, NULL);
    if (rsa == NULL)
        return nil;
    
    unsigned char *decrypted = (unsigned char *) malloc(4096);
    
    int decrypted_length = RSA_private_decrypt((int)[chiperData length], [chiperData bytes], decrypted, rsa, RSA_CIPHER);
    if(decrypted_length == -1) {
        char buffer[500];
        ERR_error_string(ERR_get_error(), buffer);
        NSLog(@"[LOG] %@",[NSString stringWithUTF8String:buffer]);
        return nil;
    }
    
    NSString *decryptString = [[NSString alloc] initWithBytes:decrypted length:decrypted_length encoding:NSUTF8StringEncoding];
    
    if (decrypted)
        free(decrypted);
    free(bio);
    free(rsa);

    return decryptString;
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
    
    BOOL result = [self encryptData:plainData cipherData:&cipherData keyData:keyData keyLen:AES_KEY_128_LENGTH initVectorData:initVectorData tagData:&tagData];
    
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
    
    /*
    BOOL result = [self decryptData:cipherData plainData:&plainData keyData:keyData keyLen:AES_KEY_128_LENGTH initVectorData:initVectorData tag:tag];
    
    if (plainData != nil && result) {
        [plainData writeToFile:[NSString stringWithFormat:@"%@/%@", activeUrl, @"decrypted"] atomically:YES];
    }
    */
}

// Encryption using GCM mode
- (BOOL)encryptData:(NSData *)plainData cipherData:(NSMutableData **)cipherData keyData:(NSData *)keyData keyLen:(int)keyLen initVectorData:(NSData *)initVectorData tagData:(NSData **)tagData
{
    int status = 0;
    int numberOfBytes = 0;
    *cipherData = [NSMutableData dataWithLength:[plainData length]];
    
    // set up key
    unsigned char cKey[keyLen];
    bzero(cKey, sizeof(cKey));
    [keyData getBytes:cKey length:keyLen];
    
    // set up ivec
    unsigned char cIv[AES_IVEC_LENGTH];
    bzero(cIv, AES_IVEC_LENGTH);
    [initVectorData getBytes:cIv length:AES_IVEC_LENGTH];
    
    // Create and initialise the context
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    
    // Initialise the encryption operation
    if (keyLen == AES_KEY_128_LENGTH)
        status = EVP_EncryptInit_ex (ctx, EVP_aes_128_gcm(), NULL, NULL, NULL);
    else if (keyLen == AES_KEY_256_LENGTH)
        status = EVP_EncryptInit_ex (ctx, EVP_aes_256_gcm(), NULL, NULL, NULL);
    
    // Set IV length if default 12 bytes (96 bits) is not appropriate
    status = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, AES_IVEC_LENGTH, NULL);
    if (! status)
        return NO;
    
    // Initialise key and IV
    status = EVP_EncryptInit_ex (ctx, NULL, NULL, cKey, cIv);
    if (! status)
        return NO;
    
    // Provide the message to be encrypted, and obtain the encrypted output
    unsigned char * ctBytes = [*cipherData mutableBytes];
    status = EVP_EncryptUpdate (ctx, ctBytes, &numberOfBytes, [plainData bytes], (int)[plainData length]);
    if (! status)
        return NO;
    
    //Finalise the encryption
    status = EVP_EncryptFinal_ex (ctx, ctBytes+numberOfBytes, &numberOfBytes);
    
    if (status && tagData) {
    }
    
    // Free
    EVP_CIPHER_CTX_free(ctx);
    
    return status; // OpenSSL uses 1 for success
}

// Decryption using GCM mode
- (BOOL)decryptData:(NSData *)cipherData plainData:(NSMutableData **)plainData keyData:(NSData *)keyData keyLen:(int)keyLen ivData:(NSData *)ivData tagData:(NSData *)tagData
{    
    int status = 0;
    int len = 0;
    NSData *printData;
    
    // set up key
    len = keyLen;
    unsigned char cKey[len];
    bzero(cKey, sizeof(cKey));
    [keyData getBytes:cKey length:len];
    // ----- DEBUG Print -----
    printData = [NSData dataWithBytes:cKey length:len];
    NSLog(@"Key %@", [printData base64EncodedStringWithOptions:0]);
    // -----------------------
    
    // set up ivec
    len = (int)[ivData length];
    unsigned char cIV[len];
    bzero(cIV, sizeof(cIV));
    [ivData getBytes:cIV length:len];
    // ----- DEBUG Print -----
    printData = [NSData dataWithBytes:cIV length:len];
    NSLog(@"IV %@", [printData base64EncodedStringWithOptions:0]);
    // -----------------------
    
    // set up tag
    len = (int)[tagData length];;
    unsigned char cTag[len];
    bzero(cTag, sizeof(cTag));
    [tagData getBytes:cTag length:len];
    // ----- DEBUG Print -----
    printData = [NSData dataWithBytes:cTag length:len];
    NSLog(@"Tag %@", [printData base64EncodedStringWithOptions:0]);
    // -----------------------
    
    // Create and initialise the context
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    
    // Initialise the decryption operation
    if (keyLen == AES_KEY_128_LENGTH)
        status = EVP_DecryptInit_ex(ctx, EVP_aes_128_gcm(), NULL, NULL, NULL);
    else if (keyLen == AES_KEY_256_LENGTH)
        status = EVP_DecryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, NULL, NULL);
    
    if (! status)
        return NO;
    
    // Set IV length. Not necessary if this is 12 bytes (96 bits)
    status = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, (int)sizeof(cIV), NULL);
    if (! status)
        return NO;
    
    // Initialise key and IV
    status = EVP_DecryptInit_ex(ctx, NULL, NULL, cKey, cIV);
    if (! status)
        return NO;
    
    // Provide the message to be decrypted, and obtain the plaintext output
    cipherData = [cipherData subdataWithRange:NSMakeRange(0, cipherData.length - 16)]; // remove TAG
    *plainData = [NSMutableData dataWithLength:([cipherData length])];
    int pPlainLen = 0;
    unsigned char * pPlain = [*plainData mutableBytes];
    status = EVP_DecryptUpdate (ctx, pPlain, &pPlainLen, [cipherData bytes], (int)([cipherData length]));
    if (! status)
        return NO;
    
    // Tag is the last 16 bytes
    status = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, (int)sizeof(cTag), cTag);
    if (! status)
        return NO;
    
    //Finalise the encryption
    len = pPlainLen;
    int statusEND = EVP_DecryptFinal_ex (ctx, pPlain + pPlainLen, &len);
    
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

- (NSString *)base64Encode:(NSData *)input
{
    void *bytes;

    BIO *buffer = BIO_new(BIO_s_mem());
    BIO *base64 = BIO_new(BIO_f_base64());
    buffer = BIO_push(base64, buffer);
    BIO_write(buffer, [input bytes], (int)[input length]);
    
    NSUInteger length = BIO_get_mem_data(buffer, &bytes);
    NSString *string = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
    
    BIO_free_all(buffer);
    
    return string;
}

- (NSString *)base64Decode:(NSData *)input
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

- (NSString *)structPEMFormat:(NSString *)input
{
    NSMutableArray *substringArray = [NSMutableArray array];
    NSInteger startingPoint = 0;
    NSInteger substringLength = 65;

    for (NSInteger i = 0; i < input.length / substringLength; i++) {
        NSString *substring = [input substringWithRange:NSMakeRange(startingPoint, substringLength)];
        substring = [substring stringByAppendingString:@"\n"];
        [substringArray addObject:substring];
        startingPoint += substringLength;
    }
    
    if (startingPoint < input.length) {
        NSString *substring = [input substringWithRange:NSMakeRange(startingPoint, input.length-startingPoint)];
        substring = [substring stringByAppendingString:@"\n"];
        [substringArray addObject:substring];
     }
    
    NSMutableString *result = [NSMutableString new];
    [result appendString:@"-----BEGIN PRIVATE KEY-----\n"];
    for (NSObject * obj in substringArray)
        [result appendString:[obj description]];
    [result appendString:@"-----END PRIVATE KEY-----\n"];

    return result;
}

@end
