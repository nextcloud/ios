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

#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>
#import "CommonCryptorSPI.h"
#import <Security/Security.h>

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
    //NSData *data = [[NSFileManager defaultManager] contentsAtPath:[NSString stringWithFormat:@"%@/%@", activeUrl, metadata.fileID]];
    
    NSData *data = [@"I love Nextcloud Android and iOS" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *keyData = [[NSData alloc] initWithBase64EncodedString:@"bGzWfQBj2lE4ZnysDWwsIg==" options:0];
    NSData *initVectorData = [[NSData alloc] initWithBase64EncodedString:@"rTBECYNekKF+a1HR7z32/Q==" options:0];
    
    // Encrypt
    NSData *encryptedData = cipherOperation(data, keyData, initVectorData, kCCEncrypt);
    NSString *base64Encoded = [encryptedData base64EncodedStringWithOptions:0];
    
    NSLog(@"%@", base64Encoded);
    
    // Decrypt
    NSData *decryptedData = cipherOperation(data, keyData, initVectorData, kCCDecrypt);
    
    if (decryptedData != nil) {
        NSLog(@"MARIO YAY");
    }
    //if (decryptedData != nil)
    // [decryptedData writeToFile:[NSString stringWithFormat:@"%@/%@", activeUrl, @"decrypted.jpg"] atomically:YES];
}

NSData *cipherOperation(NSData *contentData, NSData *keyData, NSData *initVectorData, CCOperation operation)
{
    NSMutableData *dataOut = [NSMutableData dataWithLength:contentData.length];

    // setup key
    unsigned char cKey[kCCKeySizeAES128];
    bzero(cKey, sizeof(cKey));
    [keyData getBytes:cKey length:kCCKeySizeAES128];
    
    // setup iv
    char cIv[kCCBlockSizeAES128];
    bzero(cIv, kCCBlockSizeAES128);
    [initVectorData getBytes:cIv length:kCCBlockSizeAES128];
    
    NSMutableData *tag = [NSMutableData dataWithLength:kCCBlockSizeAES128];
    size_t  tagLength = kCCBlockSizeAES128;

    CCCryptorStatus cryptStatus = CCCryptorGCM(operation,
                                          kCCAlgorithmAES128,
                                          cKey,
                                          kCCKeySizeAES128,
                                          cIv,
                                          kCCBlockSizeAES128,
                                          nil,
                                          0,
                                          contentData.bytes,
                                          contentData.length,
                                          dataOut.mutableBytes,
                                          tag.bytes,
                                          &tagLength);
    
    if (cryptStatus == kCCSuccess) {
        return [NSData dataWithBytesNoCopy:dataOut.bytes length:dataOut.length];
    }
    
    return nil;
}

@end
