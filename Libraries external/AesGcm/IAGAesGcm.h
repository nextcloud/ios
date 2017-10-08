//
//  IAGAesGcm.h
//  Pods
//
//  Created by Enrique de la Torre (dev) on 17/09/2016.
//
//

#import <Foundation/Foundation.h>

#import "IAGCipheredData.h"

/**
 This class provides the methods that implement the GCM algorithm with AES.
 */

NS_ASSUME_NONNULL_BEGIN

@interface IAGAesGcm : NSObject

/**
 Given an initialization vector,a key, a plaintext and an additional authenticated data,
 this method returns the corresponding ciphertext and authentication tag.

 @param plainData Data to cipher: byte length(plainData) <= 2^36 - 32
 @param aad Additional Authenticated Data: byte length(aad) <= 2^61 - 1
 @param tagLength Supported authentication tag length, used to build the returned ciphered data
 @param iv Initialization Vector: 1 <= byte length(iv) <= 2^61 - 1
 @param key Key used to cipher the data with length: kCCKeySizeAES128 (16), kCCKeySizeAES192 (24) or kCCKeySizeAES256 (32) bytes
 @param error Set to a value if the operation fails
 
 @return Ciphered data or nil, if there is an error
 
 @see IAGAuthenticationTagLength
 @see IAGCipheredData
 @see IAGErrorFactory
 */
+ (nullable IAGCipheredData *)cipheredDataByAuthenticatedEncryptingPlainData:(NSData *)plainData
                                             withAdditionalAuthenticatedData:(NSData *)aad
                                                     authenticationTagLength:(IAGAuthenticationTagLength)tagLength
                                                        initializationVector:(NSData *)iv
                                                                         key:(NSData *)key
                                                                       error:(NSError **)error;

/**
 Given an initialization vector, a key, a ciphertext with its associated authentication tag and an
 additional authenticated tag, this method return the corresponding plaintext.

 @param cipheredData Data to decipher: byte length(plainData) <= 2^36 - 32
 @param aad Additional Authenticated Data: byte length(aad) <= 2^61 - 1
 @param iv Initialization Vector: 1 <= byte length(iv) <= 2^61 - 1
 @param key Key used to decipher the data with length: kCCKeySizeAES128 (16), kCCKeySizeAES192 (24) or kCCKeySizeAES256 (32) bytes
 @param error Set to a value if the operation fails
 
 @return Plain data or nil, if there is an error
 
 @see IAGErrorFactory
 */
+ (nullable NSData *)plainDataByAuthenticatedDecryptingCipheredData:(IAGCipheredData *)cipheredData
                                    withAdditionalAuthenticatedData:(NSData *)aad
                                               initializationVector:(NSData *)iv
                                                                key:(NSData *)key
                                                              error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
