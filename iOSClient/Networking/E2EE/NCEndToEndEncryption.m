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

#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonKeyDerivation.h>
#import <OpenSSL/OpenSSL.h>

#define addName(field, value) X509_NAME_add_entry_by_txt(name, field, MBSTRING_ASC, (unsigned char *)value, -1, -1, 0); NSLog(@"%s: %s", field, value);

#define IV_DELIMITER_ENCODED_OLD    @"fA=="
#define IV_DELIMITER_ENCODED        @"|"
#define PBKDF2_KEY_LENGTH           256
//#define PBKDF2_SALT                 @"$4$YmBjm3hk$Qb74D5IUYwghUmzsMqeNFx5z0/8$"

#define ASYMMETRIC_STRING_TEST      @"Nextcloud a safe home for all your data"

#define fileNameCertificate         @"cert.pem"
#define fileNameCSR                 @"csr.pem"
#define fileNamePrivateKey          @"privateKey.pem"
#define fileNamePubliceKey          @"publicKey.pem"

#define streamBuffer                1024

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
+ (instancetype)shared {
    static dispatch_once_t once;
    static NCEndToEndEncryption *shared;
    dispatch_once(&once, ^{
        shared = [self new];
    });
    return shared;
}

#
#pragma mark - Generate Certificate X509 - CSR - Private Key
#

- (BOOL)generateCertificateX509WithUserId:(NSString *)userId directory:(NSString *)directory
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

    X509 *x509 = X509_new();

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
    
    const unsigned char *cUserId = (const unsigned char *) [userId cStringUsingEncoding:NSUTF8StringEncoding];

    // Common Name = UserID.
    addName("CN", cUserId);
    
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
    NSLog(@"[INFO] \n%@", [[NSString alloc] initWithData:_csrData encoding:NSUTF8StringEncoding]);

    // PublicKey
    BIO *publicKeyBIO = BIO_new(BIO_s_mem());
    PEM_write_bio_PUBKEY(publicKeyBIO, pkey);
    
    len = BIO_pending(publicKeyBIO);
    keyBytes  = malloc(len);
    
    BIO_read(publicKeyBIO, keyBytes, len);
    _publicKeyData = [NSData dataWithBytes:keyBytes length:len];
    self.generatedPublicKey = [[NSString alloc] initWithData:_publicKeyData encoding:NSUTF8StringEncoding];
    NSLog(@"[INFO] \n%@", self.generatedPublicKey);

    // PrivateKey
    BIO *privateKeyBIO = BIO_new(BIO_s_mem());
    PEM_write_bio_PKCS8PrivateKey(privateKeyBIO, pkey, NULL, NULL, 0, NULL, NULL);
    
    len = BIO_pending(privateKeyBIO);
    keyBytes = malloc(len);
    
    BIO_read(privateKeyBIO, keyBytes, len);
    _privateKeyData = [NSData dataWithBytes:keyBytes length:len];
    self.generatedPrivateKey = [[NSString alloc] initWithData:_privateKeyData encoding:NSUTF8StringEncoding];
    NSLog(@"[INFO] \n%@", self.generatedPrivateKey);

    if(keyBytes)
        free(keyBytes);
    
#ifdef DEBUG
    // Save to disk [DEBUG MODE]
    [self saveToDiskPEMWithCert:x509 key:pkey directory:directory];
#endif
    
    return YES;
}

- (NSString *)extractPublicKeyFromCertificate:(NSString *)pemCertificate
{
    const char *ptrCert = [pemCertificate cStringUsingEncoding:NSUTF8StringEncoding];
    
    BIO *certBio = BIO_new(BIO_s_mem());
    BIO_write(certBio, ptrCert,(unsigned int)strlen(ptrCert));
    
    X509 *certX509 = PEM_read_bio_X509(certBio, NULL, NULL, NULL);
    if (!certX509) {
        fprintf(stderr, "unable to parse certificate in memory\n");
        return nil;
    }
    
    EVP_PKEY *pkey;
    pkey = X509_get_pubkey(certX509);
    NSString *publicKey = [self pubKeyToString:pkey];
    
    EVP_PKEY_free(pkey);
    BIO_free(certBio);
    X509_free(certX509);
    
    NSLog(@"[INFO] \n%@", publicKey);
    return publicKey;
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
    NSLog(@"[INFO] Saved cert to %@", certificatePath);
    fclose(f);
    
    // PublicKey
    NSString *publicKeyPath = [NSString stringWithFormat:@"%@/%@", directory, fileNamePubliceKey];
    f = fopen([publicKeyPath fileSystemRepresentation], "wb");
    if (PEM_write_PUBKEY(f, pkey) < 0) {
        // Error
        fclose(f);
        return NO;
    }
    NSLog(@"[INFO] Saved publicKey to %@", publicKeyPath);
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
    NSLog(@"[INFO] Saved privatekey to %@", privatekeyPath);
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
    NSLog(@"[INFO] Saved csr to %@", csrPath);
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
    NSLog(@"[INFO] Saved p12 to %@", path);
    fclose(f);
    
    return YES;
}

#
#pragma mark - Create CSR & Encrypt/Decrypt Private Key
#

- (NSString *)createCSR:(NSString *)userId directory:(NSString *)directory
{
    // Create Certificate, if do not exists
    if (!_csrData) {
        if (![self generateCertificateX509WithUserId:userId directory:directory])
            return nil;
    }
    
    NSString *csr = [[NSString alloc] initWithData:_csrData encoding:NSUTF8StringEncoding];
    
    return csr;
}

- (NSString *)encryptPrivateKey:(NSString *)userId directory:(NSString *)directory passphrase:(NSString *)passphrase privateKey:(NSString **)privateKey iterationCount:(unsigned int)iterationCount
{
    NSMutableData *cipher = [NSMutableData new];

    if (!_privateKeyData) {
        if (![self generateCertificateX509WithUserId:userId directory:directory])
            return nil;
    }
    
    NSMutableData *key = [NSMutableData dataWithLength:PBKDF2_KEY_LENGTH/8];
    NSData *salt = [self generateSalt:AES_SALT_LENGTH];
    
    // Remove all whitespaces from passphrase
    passphrase = [passphrase stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    CCKeyDerivationPBKDF(kCCPBKDF2, passphrase.UTF8String, passphrase.length, salt.bytes, salt.length, kCCPRFHmacAlgSHA1, iterationCount, key.mutableBytes, key.length);
    
    NSData *initializationVector = [self generateIV:AES_IVEC_LENGTH];
    NSData *authenticationTag = [NSData new];
    
    NSString *pkEncoded = [_privateKeyData base64EncodedStringWithOptions:0];
    NSData *pkEncodedData = [pkEncoded dataUsingEncoding:NSUTF8StringEncoding];

    BOOL result = [self encryptData:pkEncodedData cipher:&cipher key:key keyLen:AES_KEY_256_LENGTH initializationVector:initializationVector authenticationTag:&authenticationTag];
    
    if (result && cipher) {
        
        NSString *cipherString = [cipher base64EncodedStringWithOptions:0];
        NSString *initializationVectorString = [initializationVector base64EncodedStringWithOptions:0];
        NSString *saltString = [salt base64EncodedStringWithOptions:0];
        NSString *encryptPrivateKey = [NSString stringWithFormat:@"%@%@%@%@%@", cipherString, IV_DELIMITER_ENCODED, initializationVectorString, IV_DELIMITER_ENCODED, saltString];
        
        *privateKey = [[NSString alloc] initWithData:_privateKeyData encoding:NSUTF8StringEncoding];
        return encryptPrivateKey;
        
    } else {
        
        return nil;
    }
}

- (NSData *)decryptPrivateKey:(NSString *)privateKey passphrase:(NSString *)passphrase publicKey:(NSString *)publicKey iterationCount:(unsigned int)iterationCount
{
    NSMutableData *plain = [NSMutableData new];

    // Key
    NSMutableData *key = [NSMutableData dataWithLength:PBKDF2_KEY_LENGTH/8];
    
    // Split
    NSArray *cipherArray = [privateKey componentsSeparatedByString:IV_DELIMITER_ENCODED];
    if (cipherArray.count != 3) {
        cipherArray = [privateKey componentsSeparatedByString:IV_DELIMITER_ENCODED_OLD];
        if (cipherArray.count != 3) {
            return nil;
        }
    }
    
    NSData *cipher = [[NSData alloc] initWithBase64EncodedString:cipherArray[0] options:0];
    NSString *authenticationTagString = [privateKey substringWithRange:NSMakeRange([(NSString *)cipherArray[0] length] - AES_GCM_TAG_LENGTH, AES_GCM_TAG_LENGTH)];
    NSData *authenticationTag = [[NSData alloc] initWithBase64EncodedString:authenticationTagString options:0];
    NSData *initializationVector = [[NSData alloc] initWithBase64EncodedString:cipherArray[1] options:0];
    NSData *salt = [[NSData alloc] initWithBase64EncodedString:cipherArray[2] options:0];

    // Remove Authentication Tag
    cipher = [cipher subdataWithRange:NSMakeRange(0, cipher.length - AES_GCM_TAG_LENGTH)];

    // Remove all whitespaces from passphrase
    passphrase = [passphrase stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    CCKeyDerivationPBKDF(kCCPBKDF2, passphrase.UTF8String, passphrase.length, salt.bytes, salt.length, kCCPRFHmacAlgSHA1, iterationCount, key.mutableBytes, key.length);
    
    BOOL result = [self decryptData:cipher plain:&plain key:key keyLen:AES_KEY_256_LENGTH initializationVector:initializationVector authenticationTag:authenticationTag];
    
    if (result && plain) {
        return plain;
    }

    return nil;
}

#
#pragma mark - Encrypt / Decrypt file material
#

- (NSString *)encryptPayloadFile:(NSData *)encrypted key:(NSString *)key
{
    NSMutableData *cipher;
    NSData *authenticationTag = [NSData new];

    // Key
    NSData *keyData = [[NSData alloc] initWithBase64EncodedString:key options:0];

    // Initialization Vector
    NSData *initializationVector = [self generateIV:AES_IVEC_LENGTH];

    BOOL result = [self encryptData:encrypted cipher:&cipher key:keyData keyLen:AES_KEY_128_LENGTH initializationVector:initializationVector authenticationTag:&authenticationTag];

    if (cipher != nil && result) {

        NSString *cipherString = [cipher base64EncodedStringWithOptions:0];
        NSString *initializationVectorString = [initializationVector base64EncodedStringWithOptions:0];
        NSString *payload = [NSString stringWithFormat:@"%@%@%@", cipherString, IV_DELIMITER_ENCODED, initializationVectorString];

        return payload;
    }

    return nil;
}


- (NSString *)encryptPayloadFile:(NSData *)encrypted key:(NSString *)key initializationVector:(NSString **)initializationVector authenticationTag:(NSString **)authenticationTag
{
    NSMutableData *cipher;
    NSData *authenticationTagData = [NSData new];

    // Key
    NSData *keyData = [[NSData alloc] initWithBase64EncodedString:key options:0];

    // Initialization Vector
    NSData *initializationVectorData = [self generateIV:AES_IVEC_LENGTH];

    BOOL result = [self encryptData:encrypted cipher:&cipher key:keyData keyLen:AES_KEY_128_LENGTH initializationVector:initializationVectorData authenticationTag:&authenticationTagData];

    if (cipher != nil && result) {

        *initializationVector = [initializationVectorData base64EncodedStringWithOptions:0];
        *authenticationTag = [authenticationTagData base64EncodedStringWithOptions:0];
        NSString *payload = [cipher base64EncodedStringWithOptions:0];
        
        return payload;
    }

    return nil;
}


- (NSData *)decryptPayloadFile:(NSString *)encrypted key:(NSString *)key
{
    NSMutableData *plain;
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

    // Initialization Vector
    NSString *initializationVector  = [encrypted substringWithRange:NSMakeRange(range.location + range.length, encrypted.length - (range.location + range.length))];
    NSData *initializationVectorData = [[NSData alloc] initWithBase64EncodedString:initializationVector options:0];

    // Authentication Tag
    NSString *authenticationTag = [cipher substringWithRange:NSMakeRange(cipher.length - AES_GCM_TAG_LENGTH, AES_GCM_TAG_LENGTH)];
    NSData *authenticationTagData = [[NSData alloc] initWithBase64EncodedString:authenticationTag options:0];

    // Remove Authentication Tag
    cipherData = [cipherData subdataWithRange:NSMakeRange(0, cipherData.length - AES_GCM_TAG_LENGTH)];

    BOOL result = [self decryptData:cipherData plain:&plain key:keyData keyLen:AES_KEY_128_LENGTH initializationVector:initializationVectorData authenticationTag:authenticationTagData];

    if (plain != nil && result) {
        return plain;
    }

    return nil;
}

- (NSData *)decryptPayloadFile:(NSString *)encrypted key:(NSString *)key initializationVector:(NSString *)initializationVector authenticationTag:(NSString *)authenticationTag
{
    NSMutableData *plain;

    // Remove initializationVector Tag if exists [ANDROID]
    NSString *android = [@"|" stringByAppendingString: initializationVector];
    encrypted = [encrypted stringByReplacingOccurrencesOfString:android withString:@""];

    NSData *cipher = [[NSData alloc] initWithBase64EncodedString:encrypted options:0];
    NSData *keyData = [[NSData alloc] initWithBase64EncodedString:key options:0];
    NSData *initializationVectorData = [[NSData alloc] initWithBase64EncodedString:initializationVector options:0];
    NSData *authenticationTagData = [[NSData alloc] initWithBase64EncodedString:authenticationTag options:0];

    // Remove Authentication Tag
    cipher = [cipher subdataWithRange:NSMakeRange(0, cipher.length - AES_GCM_TAG_LENGTH)];

    BOOL result = [self decryptData:cipher plain:&plain key:keyData keyLen:AES_KEY_128_LENGTH initializationVector:initializationVectorData authenticationTag:authenticationTagData];

    if (plain != nil && result && plain.length > 0) {
        return plain;
    }

    return nil;
}

#
#pragma mark - Encrypt / Decrypt file
#

- (BOOL)encryptFile:(NSString *)fileName fileNameIdentifier:(NSString *)fileNameIdentifier directory:(NSString *)directory key:(NSString **)key initializationVector:(NSString **)initializationVector authenticationTag:(NSString **)authenticationTag
{
    NSData *authenticationTagData;
    NSData *keyData = [self generateKey:AES_KEY_128_LENGTH];
    NSData *initializationVectorData = [self generateIV:AES_IVEC_LENGTH];

    BOOL result = [self encryptFile:[NSString stringWithFormat:@"%@/%@", directory, fileName] fileNameCipher:[NSString stringWithFormat:@"%@/%@", directory, fileNameIdentifier] key:keyData keyLen:AES_KEY_128_LENGTH initializationVector:initializationVectorData authenticationTag:&authenticationTagData];

    if (result) {

        *key = [keyData base64EncodedStringWithOptions:0];
        *initializationVector = [initializationVectorData base64EncodedStringWithOptions:0];
        *authenticationTag = [authenticationTagData base64EncodedStringWithOptions:0];

        if (key == nil || initializationVector == nil || authenticationTag == nil) {
            return false;
        } else {
            return true;
        }
    }
    
    return false;
}

- (BOOL)decryptFile:(NSString *)fileName fileNameView:(NSString *)fileNameView ocId:(NSString *)ocId key:(NSString *)key initializationVector:(NSString *)initializationVector authenticationTag:(NSString *)authenticationTag
{
    NSData *keyData = [[NSData alloc] initWithBase64EncodedString:key options:0];
    NSData *initializationVectorData = [[NSData alloc] initWithBase64EncodedString:initializationVector options:0];
    NSData *authenticationTagData = [[NSData alloc] initWithBase64EncodedString:authenticationTag options:0];

    return [self decryptFile:[[[NCUtilityFileSystem alloc] init] getDirectoryProviderStorageOcId:ocId fileNameView:fileName] fileNamePlain:[[[NCUtilityFileSystem alloc] init] getDirectoryProviderStorageOcId:ocId fileNameView:fileNameView] key:keyData keyLen:AES_KEY_128_LENGTH initializationVector:initializationVectorData authenticationTag:authenticationTagData];
}

// -----------------------------------------------------------------------------------------------------------------------------------------------------------------------
// -----------------------------------------------------------------------------------------------------------------------------------------------------------------------

#
#pragma mark - OPENSSL ENCRYPT/DECRYPT
#


#
#pragma mark - Encrypt/Decrypt asymmetric
#

- (NSData *)encryptAsymmetricData:(NSData *)plainData certificate:(NSString *)certificate
{
    EVP_PKEY *key = NULL;
    int status = 0;
    unsigned char *pKey = (unsigned char *)[certificate UTF8String];

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

    EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new(key, NULL);
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

- (NSData *)encryptAsymmetricData:(NSData *)plainData privateKey:(NSString *)privateKey
{
    EVP_PKEY *key = NULL;
    int status = 0;
    unsigned char *pKey = (unsigned char *)[privateKey UTF8String];

    BIO *bio = BIO_new_mem_buf(pKey, -1);
    if (!bio)
        return nil;

    key = PEM_read_bio_PrivateKey(bio, NULL, NULL, NULL);
    if (!key)
        return nil;

    EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new(key, NULL);
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

- (NSData *)decryptAsymmetricData:(NSData *)cipherData privateKey:(NSString *)privateKey
{
    unsigned char *pKey = (unsigned char *)[privateKey UTF8String];
    int status = 0;
    
    BIO *bio = BIO_new_mem_buf(pKey, -1);
    if (!bio)
        return nil;
    
    EVP_PKEY *key = PEM_read_bio_PrivateKey(bio, NULL, NULL, NULL);
    if (!key)
        return nil;
    
    EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new(key, NULL);
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

    NSData *outData = [[NSData alloc] initWithBytes:out length:outLen];

    if (out)
        free(out);
    
    return outData;
}

#
#pragma mark - AES/GCM/NoPadding
#

// Encryption data using GCM mode
- (BOOL)encryptData:(NSData *)plain cipher:(NSMutableData **)cipher key:(NSData *)key keyLen:(int)keyLen initializationVector:(NSData *)initializationVector authenticationTag:(NSData **)authenticationTag
{
    int status = 0;
    int len = 0;
    
    // set up key
    len = keyLen;
    unsigned char cKey[len];
    bzero(cKey, sizeof(cKey));
    [key getBytes:cKey length:len];

    // set up ivec
    len = AES_IVEC_LENGTH;
    unsigned char cIV[len];
    bzero(cIV, sizeof(cIV));
    [initializationVector getBytes:cIV length:len];
    
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
    
    if (status <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return NO;
    }
    
    // Set IV length. Not necessary if this is 12 bytes (96 bits)
    status = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, (int)sizeof(cIV), NULL);
    if (status <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return NO;
    }
    
    // Initialise key and IV
    status = EVP_EncryptInit_ex (ctx, NULL, NULL, cKey, cIV);
    if (status <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return NO;
    }
    
    // Provide the message to be encrypted, and obtain the encrypted output
    *cipher = [NSMutableData dataWithLength:[plain length]];
    unsigned char * cCipher = [*cipher mutableBytes];
    int cCipherLen = 0;
    status = EVP_EncryptUpdate(ctx, cCipher, &cCipherLen, [plain bytes], (int)[plain length]);
    if (status <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return NO;
    }
    
    // Finalise the encryption
    status = EVP_EncryptFinal_ex(ctx, cCipher, &cCipherLen);
    if (status <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return NO;
    }
    
    // Get the tag
    status = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, (int)sizeof(cTag), cTag);
    *authenticationTag = [NSData dataWithBytes:cTag length:sizeof(cTag)];

    // Append TAG
    [*cipher appendData:*authenticationTag];

    EVP_CIPHER_CTX_free(ctx);
    
    return status; // OpenSSL uses 1 for success
}

// Encryption file using GCM mode
- (BOOL)encryptFile:(NSString *)fileName fileNameCipher:(NSString *)fileNameCipher key:(NSData *)key keyLen:(int)keyLen initializationVector:(NSData *)initializationVector authenticationTag:(NSData **)authenticationTag
{
    int status = 0;
    int len = 0;

    // set up key
    len = keyLen;
    unsigned char cKey[len];
    bzero(cKey, sizeof(cKey));
    [key getBytes:cKey length:len];

    // set up ivec
    len = AES_IVEC_LENGTH;
    unsigned char cIV[len];
    bzero(cIV, sizeof(cIV));
    [initializationVector getBytes:cIV length:len];

    // set up tag
    len = AES_GCM_TAG_LENGTH;
    unsigned char cTag[len];
    bzero(cTag, sizeof(cTag));

    // Create and initialise the context
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx) {
        return NO;
    }

    // Initialise the encryption operation
    if (keyLen == AES_KEY_128_LENGTH)
        status = EVP_EncryptInit_ex(ctx, EVP_aes_128_gcm(), NULL, NULL, NULL);
    else if (keyLen == AES_KEY_256_LENGTH)
        status = EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, NULL, NULL);

    if (status <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return NO;
    }

    // Set IV length. Not necessary if this is 12 bytes (96 bits)
    status = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, (int)sizeof(cIV), NULL);
    if (status <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return NO;
    }

    // Initialise key and IV
    status = EVP_EncryptInit_ex (ctx, NULL, NULL, cKey, cIV);
    if (status <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return NO;
    }

    NSInputStream *inStream = [NSInputStream inputStreamWithFileAtPath:fileName];
    [inStream open];
    NSOutputStream *outStream = [NSOutputStream outputStreamToFileAtPath:fileNameCipher append:false];
    [outStream open];

    Byte buffer[streamBuffer];
    NSInteger totalNumberOfBytesWritten = 0;

    int cCipherLen = 0;
    unsigned char *cCipher;

    while ([inStream hasBytesAvailable]) {
        @autoreleasepool {
            NSInteger bytesRead = [inStream read:buffer maxLength:streamBuffer];
            if (bytesRead > 0) {

                cCipher = [[NSMutableData dataWithLength:bytesRead] mutableBytes];
                status = EVP_EncryptUpdate(ctx, cCipher, &cCipherLen, [[NSData dataWithBytes:buffer length:bytesRead] bytes], (int)bytesRead);
                if (status <= 0) {
                    [inStream close];
                    [outStream close];
                    EVP_CIPHER_CTX_free(ctx);
                    return NO;
                }

                if ([outStream hasSpaceAvailable]) {
                    totalNumberOfBytesWritten = [outStream write:cCipher maxLength:cCipherLen];
                    if (totalNumberOfBytesWritten != cCipherLen) {
                        [inStream close];
                        [outStream close];
                        EVP_CIPHER_CTX_free(ctx);
                        return NO;
                    }
                }
            }
        }
    }

    [inStream close];

    status = EVP_EncryptFinal_ex(ctx, cCipher, &cCipherLen);
    if (status <= 0) {
        [outStream close];
        EVP_CIPHER_CTX_free(ctx);
        return NO;
    }

    // Get the tag
    status = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, (int)sizeof(cTag), cTag);
    if (status <= 0) {
        [outStream close];
        EVP_CIPHER_CTX_free(ctx);
        return NO;
    }
    *authenticationTag = [NSData dataWithBytes:cTag length:sizeof(cTag)];

    // Append TAG
    if ([outStream hasSpaceAvailable]) {
        totalNumberOfBytesWritten = [outStream write:cTag maxLength:sizeof(cTag)];
        if (totalNumberOfBytesWritten != sizeof(cTag)) {
            status = NO;
        }
    } else {
        status = NO;
    }

    [outStream close];

    EVP_CIPHER_CTX_free(ctx);

    return status; // OpenSSL uses 1 for success
}

// Decryption data using GCM mode
- (BOOL)decryptData:(NSData *)cipher plain:(NSMutableData **)plain key:(NSData *)key keyLen:(int)keyLen initializationVector:(NSData *)initializationVector authenticationTag:(NSData *)authenticationTag
{    
    int status = 0;
    int len = 0;
    
    // set up key
    len = keyLen;
    unsigned char cKey[len];
    bzero(cKey, sizeof(cKey));
    [key getBytes:cKey length:len];
    
    // set up ivec
    len = (int)[initializationVector length];
    unsigned char cIV[len];
    bzero(cIV, sizeof(cIV));
    [initializationVector getBytes:cIV length:len];
   
    // set up tag
    len = (int)[authenticationTag length];;
    unsigned char cTag[len];
    bzero(cTag, sizeof(cTag));
    [authenticationTag getBytes:cTag length:len];

    // Create and initialise the context
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx)
        return NO;
    
    // Initialise the decryption operation
    if (keyLen == AES_KEY_128_LENGTH)
        status = EVP_DecryptInit_ex(ctx, EVP_aes_128_gcm(), NULL, NULL, NULL);
    else if (keyLen == AES_KEY_256_LENGTH)
        status = EVP_DecryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, NULL, NULL);
    
    if (status <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return NO;
    }
    
    // Set IV length. Not necessary if this is 12 bytes (96 bits)
    status = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, (int)sizeof(cIV), NULL);
    if (status <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return NO;
    }
    
    // Initialise key and IV
    status = EVP_DecryptInit_ex(ctx, NULL, NULL, cKey, cIV);
    if (status <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return NO;
    }
    
    // Provide the message to be decrypted, and obtain the plaintext output
    *plain = [NSMutableData dataWithLength:([cipher length])];
    int cPlainLen = 0;
    unsigned char * cPlain = [*plain mutableBytes];
    status = EVP_DecryptUpdate(ctx, cPlain, &cPlainLen, [cipher bytes], (int)([cipher length]));
    if (status <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return NO;
    }
    
    // Tag is the last 16 bytes
    status = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, (int)sizeof(cTag), cTag);
    if (status <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return NO;
    }
    
    // Finalise the encryption
    EVP_DecryptFinal_ex(ctx,NULL, &cPlainLen);

    // Free
    EVP_CIPHER_CTX_free(ctx);
    
    return status; // OpenSSL uses 1 for success
}

// Decryption file using GCM mode
- (BOOL)decryptFile:(NSString *)fileName fileNamePlain:(NSString *)fileNamePlain key:(NSData *)key keyLen:(int)keyLen initializationVector:(NSData *)initializationVector authenticationTag:(NSData *)authenticationTag
{
    int status = 0;
    int len = 0;

    // set up key
    len = keyLen;
    unsigned char cKey[len];
    bzero(cKey, sizeof(cKey));
    [key getBytes:cKey length:len];

    // set up ivec
    len = (int)[initializationVector length];
    unsigned char cIV[len];
    bzero(cIV, sizeof(cIV));
    [initializationVector getBytes:cIV length:len];

    // set up tag
    len = (int)[authenticationTag length];;
    unsigned char cTag[len];
    bzero(cTag, sizeof(cTag));
    [authenticationTag getBytes:cTag length:len];

    // Create and initialise the context
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx)
        return NO;

    // Initialise the decryption operation
    if (keyLen == AES_KEY_128_LENGTH)
        status = EVP_DecryptInit_ex(ctx, EVP_aes_128_gcm(), NULL, NULL, NULL);
    else if (keyLen == AES_KEY_256_LENGTH)
        status = EVP_DecryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, NULL, NULL);

    if (status <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return NO;
    }

    // Set IV length. Not necessary if this is 12 bytes (96 bits)
    status = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, (int)sizeof(cIV), NULL);
    if (status <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return NO;
    }

    // Initialise key and IV
    status = EVP_DecryptInit_ex(ctx, NULL, NULL, cKey, cIV);
    if (status <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return NO;
    }

    NSInputStream *inStream = [NSInputStream inputStreamWithFileAtPath:fileName];
    [inStream open];
    NSOutputStream *outStream = [NSOutputStream outputStreamToFileAtPath:fileNamePlain append:false];
    [outStream open];

    Byte buffer[streamBuffer];
    NSInteger totalNumberOfBytesWritten = 0;

    int cPlainLen = 0;
    unsigned char *cPlain;

    while ([inStream hasBytesAvailable]) {
        @autoreleasepool {
            NSInteger bytesRead = [inStream read:buffer maxLength:streamBuffer];
            if (bytesRead > 0) {

                cPlain = [[NSMutableData dataWithLength:bytesRead] mutableBytes];
                status = EVP_DecryptUpdate(ctx, cPlain, &cPlainLen, [[NSData dataWithBytes:buffer length:bytesRead] bytes], (int)bytesRead);
                if (status <= 0) {
                    [inStream close];
                    [outStream close];
                    EVP_CIPHER_CTX_free(ctx);
                    return NO;
                }

                if ([outStream hasSpaceAvailable]) {
                    totalNumberOfBytesWritten = [outStream write:cPlain maxLength:cPlainLen];
                    if (totalNumberOfBytesWritten != cPlainLen) {
                        [inStream close];
                        [outStream close];
                        EVP_CIPHER_CTX_free(ctx);
                        return NO;
                    }
                }
            }
        }
    }

    [inStream close];
    [outStream close];

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
#pragma mark - CMS
#

- (NSData *)generateSignatureCMS:(NSData *)data certificate:(NSString *)certificate privateKey:(NSString *)privateKey userId:(NSString *)userId
{
    unsigned char *pKey = (unsigned char *)[privateKey UTF8String];
    unsigned char *certKey = (unsigned char *)[certificate UTF8String];
    BIO *printBIO = BIO_new_fp(stdout, BIO_NOCLOSE);

    BIO *certKeyBIO = BIO_new_mem_buf(certKey, -1);
    if (!certKeyBIO)
        return nil;

    X509 *x509 = PEM_read_bio_X509(certKeyBIO, NULL, 0, NULL);
    if (!x509)
        return nil;

    BIO *pkeyBIO = BIO_new_mem_buf(pKey, -1);
    EVP_PKEY *key = PEM_read_bio_PrivateKey(pkeyBIO, NULL, NULL, NULL);
    if (!key)
        return nil;

    BIO *dataBIO = BIO_new_mem_buf((void*)data.bytes, (int)data.length);

    CMS_ContentInfo *contentInfo = CMS_sign(x509, key, NULL, dataBIO, CMS_DETACHED);
    if (contentInfo == nil)
        return nil;

    // DEBUG CMS_ContentInfo_print_ctx(printBIO, contentInfo, 0, NULL);
    PEM_write_bio_CMS(printBIO, contentInfo);

    BIO *i2dCmsBioOut = BIO_new(BIO_s_mem());
    if (i2d_CMS_bio(i2dCmsBioOut, contentInfo) != 1)
        return nil;

    int len = BIO_pending(i2dCmsBioOut);
    char *keyBytes = malloc(len);
    BIO_read(i2dCmsBioOut, keyBytes, len);

    NSData *i2dCmsData = [NSData dataWithBytes:keyBytes length:len];

    BIO_free(printBIO);
    BIO_free(certKeyBIO);
    BIO_free(pkeyBIO);
    BIO_free(dataBIO);
    BIO_free(i2dCmsBioOut);

    return i2dCmsData;
}

- (BOOL)verifySignatureCMS:(NSData *)cmsContent data:(NSData *)data publicKey:(NSString *)publicKey userId:(NSString *)userId
{
    BIO *dataBIO = BIO_new_mem_buf((void*)data.bytes, (int)data.length);
    BIO *printBIO = BIO_new_fp(stdout, BIO_NOCLOSE);
    BIO *cmsBIO = BIO_new_mem_buf(cmsContent.bytes, (int)cmsContent.length);

    CMS_ContentInfo *contentInfo = d2i_CMS_bio(cmsBIO, NULL);

    unsigned char *publicKeyUTF8 = (unsigned char *)[publicKey UTF8String];
    BIO *publicKeyBIO = BIO_new_mem_buf(publicKeyUTF8, -1);
    EVP_PKEY *pkey = PEM_read_bio_PUBKEY(publicKeyBIO, NULL, NULL, NULL);

    // DEBUG CMS_ContentInfo_print_ctx(printBIO, contentInfo, 0, NULL);

    BOOL verifyResult = CMS_verify(contentInfo, NULL, NULL, dataBIO, NULL, CMS_DETACHED | CMS_NO_SIGNER_CERT_VERIFY);

    if (verifyResult) {

        STACK_OF(X509) *signers = CMS_get0_signers(contentInfo);
        int numSigners = sk_X509_num(signers);

        for (int i = 0; i < numSigners; ++i) {

            X509 *signer = sk_X509_value(signers, i);
            int result = X509_verify(signer, pkey);
            if (result <= 0) {
                verifyResult = false;
                break;
            }

            int cnDataLength = X509_NAME_get_text_by_NID(X509_get_subject_name(signer), NID_commonName, 0, 0);
            cnDataLength += 1;
            NSMutableData* cnData = [NSMutableData dataWithLength:cnDataLength];
            X509_NAME_get_text_by_NID(X509_get_subject_name(signer), NID_commonName, [cnData mutableBytes], cnDataLength);
            NSString *cn = [[NSString alloc] initWithCString:[cnData mutableBytes] encoding:NSUTF8StringEncoding];
            if ([userId isEqualToString:cn]) {
                verifyResult = true;
                break;
            } else {
                verifyResult = false;
            }
        }

        if (signers) {
            sk_X509_free(signers);
        }
        signers = NULL;
    }

    BIO_free(dataBIO);
    BIO_free(printBIO);
    BIO_free(cmsBIO);
    BIO_free(publicKeyBIO);

    return verifyResult;
}

- (BOOL)verifySignatureCMS:(NSData *)cmsContent data:(NSData *)data certificates:(NSArray*)certificates
{
    BIO *dataBIO = BIO_new_mem_buf((void*)data.bytes, (int)data.length);
    BIO *printBIO = BIO_new_fp(stdout, BIO_NOCLOSE);
    BIO *cmsBIO = BIO_new_mem_buf(cmsContent.bytes, (int)cmsContent.length);

    CMS_ContentInfo *contentInfo = d2i_CMS_bio(cmsBIO, NULL);
    // DEBUG CMS_ContentInfo_print_ctx(printBIO, contentInfo, 0, NULL);

    BOOL verifyResult = CMS_verify(contentInfo, NULL, NULL, dataBIO, NULL, CMS_DETACHED | CMS_NO_SIGNER_CERT_VERIFY);

    BIO_free(dataBIO);
    BIO_free(printBIO);
    BIO_free(cmsBIO);

    if (verifyResult) {

        struct stack_st_CMS_SignerInfo* signerInfos = CMS_get0_SignerInfos(contentInfo);
        STACK_OF(X509) *signers = CMS_get0_signers(contentInfo);
        int numSigners = sk_X509_num(signers);

        for (NSString *certificate in certificates) {

            const char *ptrCertificate = [certificate cStringUsingEncoding:NSUTF8StringEncoding];
            BIO *certBio = BIO_new(BIO_s_mem());
            BIO_write(certBio, ptrCertificate,(unsigned int)strlen(ptrCertificate));
            X509 *certX509 = PEM_read_bio_X509(certBio, NULL, NULL, NULL);
            if (!certX509) {
                continue;
            }

            for (int i = 0; i < numSigners; ++i) {
                struct CMS_SignerInfo_st *signerInfo = sk_CMS_SignerInfo_value(signerInfos, i);
                if (CMS_SignerInfo_cert_cmp(signerInfo, certX509) == 0) {
                    BIO_free(certBio);
                    return true;
                }
            }
        }
    }

    return verifyResult;
}

#
#pragma mark - Utility
#

- (void)Encodedkey:(NSString **)key initializationVector:(NSString **)initializationVector
{
    NSData *keyData = [self generateKey:AES_KEY_128_LENGTH];
    NSData *ivData = [self generateIV:AES_IVEC_LENGTH];

    *key = [keyData base64EncodedStringWithOptions:0];
    *initializationVector = [ivData base64EncodedStringWithOptions:0];
}

- (NSString *)createSHA256:(NSData *)data
{
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (unsigned int)data.length, digest);
    NSMutableString* output = [NSMutableString  stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];

    for(int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    return output;
}

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

- (NSData *)generateKey
{
    NSMutableData *keyData = [NSMutableData dataWithLength:AES_KEY_128_LENGTH];
    unsigned char *pKeyData = [keyData mutableBytes];

    RAND_bytes(pKeyData, AES_KEY_128_LENGTH);

    return keyData;
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

- (NSString *)pubKeyToString:(EVP_PKEY *)pubkey
{
    char *buf[256];
    FILE *pFile;
    NSString *pkey_string;
    
    pFile = fmemopen(buf, sizeof(buf), "w");
    PEM_write_PUBKEY(pFile,pubkey);
    fputc('\0', pFile);
    fclose(pFile);
    
    pkey_string = [NSString stringWithUTF8String:(char *)buf];
    
    return pkey_string;
}

@end
