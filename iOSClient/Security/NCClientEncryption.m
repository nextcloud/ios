//
//  NCClientEncryption.m
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

#import "NCClientEncryption.h"
#import "NCBridgeSwift.h"

#import <CommonCrypto/CommonDigest.h>

#import <openssl/x509.h>
#import <openssl/bio.h>
#import <openssl/err.h>
#import <openssl/pem.h>
#import <openssl/rsa.h>
#import <openssl/pkcs12.h>
#import <openssl/ssl.h>
#import <openssl/err.h>
#import <openssl/bn.h>

#define NSMakeError(description) [NSError errorWithDomain:@"com.nextcloud.nextcloudiOS" code:-1 userInfo:@{NSLocalizedDescriptionKey: description}];

#define AES_KEY_LENGTH      16
#define AES_KEY_LENGTH_BITS 128
#define AES_IVEC_LENGTH     16
#define AES_GCM_TAG_LENGTH  16

@implementation NCClientEncryption

//Singleton
+ (id)sharedManager {
    static NCClientEncryption *NCClientEncryption = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NCClientEncryption = [self new];
    });
    return NCClientEncryption;
}

- (void)generateCertificateX509WithDirectoryUser:(NSString *)directoryUser finished:(void (^)(NSError *))finished
{
    OPENSSL_init_ssl(0, NULL);
    OPENSSL_init_crypto(0, NULL);
    
    X509 *x509;
    x509 = X509_new();
    
    EVP_PKEY *pkey;
    NSError *keyError;
    pkey = [self generateRSAKey:&keyError];
    if (keyError) {
        finished(keyError);
        return;
    }
    
    //
    //NSData *data = [NSData dataWithBytes:pkey length:2048];
    //NSString *s = [[NSString alloc] initWithData:[NSData dataWithBytes:pkey length:2048] encoding:NSASCIIStringEncoding];
    
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
#define addName(field, value) X509_NAME_add_entry_by_txt(name, field,  MBSTRING_ASC, (unsigned char *)value, -1, -1, 0); NSLog(@"%s: %s", field, value);
    
    // The domain name or IP address that the certificate is issued for.
    addName("CN", "nextcloud.com");
    
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
        finished([self opensslError:@"Error signing the certificate with the key"]);
        return;
    }
    
    X509_print_fp(stdout, x509);
    
    [self savePEMWithCert:x509 key:pkey directoryUser:directoryUser finished:finished];
}

- (EVP_PKEY *)generateRSAKey:(NSError **)error
{
    EVP_PKEY *pkey = EVP_PKEY_new();
    if (!pkey) {
        *error = [self opensslError:@"Error creating modulus."];
        return NULL;
    }
    
    BIGNUM *bigNumber = BN_new();
    int exponent = RSA_F4;
    RSA *rsa = RSA_new();
    
    if (BN_set_word(bigNumber, exponent) < 0) {
        *error = [self opensslError:@"Error creating modulus."];
        goto cleanup;
    }
    
    if (RSA_generate_key_ex(rsa, 2048, bigNumber, NULL) < 0) {
        *error = [self opensslError:@"Error generating private key."];
        goto cleanup;
    }
    
    if (!EVP_PKEY_set1_RSA(pkey, rsa)) {
        *error = [self opensslError:@"Unable to generate RSA key"];
        goto cleanup;
    }
    
cleanup:
    RSA_free(rsa);
    BN_free(bigNumber);
    
    return pkey;
}

- (void)savePEMWithCert:(X509 *)x509 key:(EVP_PKEY *)pkey directoryUser:(NSString *)directoryUser finished:(void (^)(NSError *))finished
{
    NSString *keyPath = [NSString stringWithFormat:@"%@/privatekey.pem", directoryUser];
    NSString *certPath = [NSString stringWithFormat:@"%@/certificate.crt", directoryUser];
    
    FILE *f = fopen([keyPath fileSystemRepresentation], "wb");
    
    // Here you write the private key (pkey) to disk. OpenSSL will encrypt the
    // file using the password and cipher you provide.
    //if (PEM_write_PrivateKey(f, pkey, EVP_des_ede3_cbc(), (unsigned char *)[password UTF8String], (int)password.length, NULL, NULL) < 0) {
    
    if (PEM_write_PrivateKey(f, pkey, NULL, NULL, 0, NULL, NULL) < 0) {
        // Error encrypting or writing to disk.
        finished([self opensslError:@"Error saving private key."]);
        fclose(f);
    }
    NSLog(@"Saved key to %@", keyPath);
    fclose(f);
    
    f = fopen([certPath fileSystemRepresentation], "wb");
    
    // Here you write the certificate to the disk. No encryption is needed here
    // since this is public facing information
    if (PEM_write_X509(f, x509) < 0) {
        // Error writing to disk.
        finished([self opensslError:@"Error saving cert."]);
        fclose(f);
    }
    NSLog(@"Saved cert to %@", certPath);
    fclose(f);
    finished(nil);
}

- (void)saveP12WithCert:(X509 *)x509 key:(EVP_PKEY *)pkey directoryUser:(NSString *)directoryUser finished:(void (^)(NSError *))finished
{
    //PKCS12 * p12 = PKCS12_create([password UTF8String], NULL, pkey, x509, NULL, 0, 0, PKCS12_DEFAULT_ITER, 1, NID_key_usage);
    PKCS12 *p12 = PKCS12_create(NULL, NULL, pkey, x509, NULL, 0, 0, PKCS12_DEFAULT_ITER, 1, NID_key_usage);
    
    NSString *path = [NSString stringWithFormat:@"%@/certificate.p12", directoryUser];
    
    FILE *f = fopen([path fileSystemRepresentation], "wb");
    
    if (i2d_PKCS12_fp(f, p12) != 1) {
        finished([self opensslError:@"Error writing p12 to disk."]);
        fclose(f);
        return;
    }
    NSLog(@"Saved p12 to %@", path);
    fclose(f);
    finished(nil);
}

- (NSError *)opensslError:(NSString *)description
{
    const char *file;
    int line;
    ERR_peek_last_error_line(&file, &line);
    NSString *errorBody = [NSString stringWithFormat:@"%@ - OpenSSL Error %s:%i", description, file, line];
    NSLog(@"%@", errorBody);
    return NSMakeError(errorBody);
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

- (void)decryptMetadata:(tableMetadata *)metadata activeUrl:(NSString *)activeUrl
{
    BOOL result;
    
    // Decrypt
    //NSData *dataDecrypt = [[NSFileManager defaultManager] contentsAtPath:[NSString stringWithFormat:@"%@/crypted.dms", activeUrl]];
    NSData *dataDecrypt = [[NSFileManager defaultManager] contentsAtPath:[NSString stringWithFormat:@"%@/%@", activeUrl, metadata.fileID]];
    NSMutableData *plainText = [[NSMutableData alloc] initWithCapacity:dataDecrypt.length];
    
    result = [self aes256gcmDecrypt:dataDecrypt plaintext:&plainText keyString:@"bGzWfQBj2lE4ZnysDWwsIg==" initVectorString:@"rTBECYNekKF+a1HR7z32/Q=="];
    
    if (result == YES && plainText != nil)
        [plainText writeToFile:[NSString stringWithFormat:@"%@/%@", activeUrl, @"decrypted.jpg"] atomically:YES];
}

// encrypt plaintext.
- (BOOL) aes256gcmEncrypt:(NSData*)plaintext ciphertext:(NSMutableData**)ciphertext aad:(NSData*)aad key:(const unsigned char*)key ivec:(const unsigned char*)ivec tag:(unsigned char*)tag {
    
    int status = 0;
    *ciphertext = [NSMutableData dataWithLength:[plaintext length]];
    if (! *ciphertext)
        return NO;
    
    // set up to Encrypt AES 256 GCM
    int numberOfBytes = 0;
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    EVP_EncryptInit_ex (ctx, EVP_aes_128_gcm(), NULL, NULL, NULL);
    
    // set the key and ivec
    EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, AES_IVEC_LENGTH, NULL);
    EVP_EncryptInit_ex (ctx, NULL, NULL, key, ivec);
    
    // add optional AAD (Additional Auth Data)
    if (aad)
        status = EVP_EncryptUpdate( ctx, NULL, &numberOfBytes, [aad bytes], (int)[aad length]);
    
    unsigned char * ctBytes = [*ciphertext mutableBytes];
    EVP_EncryptUpdate (ctx, ctBytes, &numberOfBytes, [plaintext bytes], (int)[plaintext length]);
    status = EVP_EncryptFinal_ex (ctx, ctBytes+numberOfBytes, &numberOfBytes);
    
    if (status && tag) {
        status = EVP_CIPHER_CTX_ctrl (ctx, EVP_CTRL_GCM_GET_TAG, AES_GCM_TAG_LENGTH, tag);
    }
    EVP_CIPHER_CTX_free(ctx);
    return (status != 0); // OpenSSL uses 1 for success
}

// decrypt ciphertext.
- (BOOL)aes256gcmDecrypt:(NSData*)ciphertext plaintext:(NSMutableData**)plaintext keyString:(NSString *)keyString initVectorString:(NSString *)initVectorString
{    
    int status = 0;
    
    // set up to Decrypt AES 128 GCM
    int numberOfBytes = 0;
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    EVP_DecryptInit_ex (ctx, EVP_aes_128_gcm(), NULL, NULL, NULL);
    
    // set the key and ivec
    unsigned char cKey[AES_KEY_LENGTH];
    bzero(cKey, sizeof(cKey));
    [[[NSData alloc] initWithBase64EncodedString:keyString options:0] getBytes:cKey length:AES_KEY_LENGTH];
    
    unsigned char cIv[AES_KEY_LENGTH];
    bzero(cIv, AES_KEY_LENGTH);
    [[[NSData alloc] initWithBase64EncodedString:initVectorString options:0] getBytes:cIv length:AES_KEY_LENGTH];
    
    EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, AES_IVEC_LENGTH, NULL);
    status = EVP_DecryptInit_ex (ctx, NULL, NULL, cKey, cIv);
    
    // Set expected tag value. A restriction in OpenSSL 1.0.1c and earlier requires the tag before any AAD or ciphertext
    //if (status && tag)
    //    EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, AES_GCM_TAG_LENGTH, tag);
    
    // add optional AAD (Additional Auth Data)
    //if (aad)
    //    EVP_DecryptUpdate(ctx, NULL, &numberOfBytes, [aad bytes], (int)[aad length]);
    
    status = EVP_DecryptUpdate (ctx, [*plaintext mutableBytes], &numberOfBytes, [ciphertext bytes], (int)[ciphertext length]);
    if (! status) {
        NSLog(@"aes256gcmDecrypt: EVP_DecryptUpdate failed");
        return NO;
    }
    EVP_DecryptFinal_ex (ctx, NULL, &numberOfBytes);
    EVP_CIPHER_CTX_free(ctx);
    return (status != 0); // OpenSSL uses 1 for success
}

@end
