//
//  IAGGcmMathComponents.h
//  Pods
//
//  Created by Enrique de la Torre (dev) on 20/09/2016.
//
//

#import <Foundation/Foundation.h>

#import "IAGTypes.h"

/**
 Mathematical components used by the authenticated encryption and authenticated decryption functions.
 
 @see IAGAesGcm
 */

NS_ASSUME_NONNULL_BEGIN

@interface IAGGcmMathComponents : NSObject

/**
 Quoting the documentation [here](http://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-38d.pdf): "The authentication mechanism within GCM is based on a hash function, called GHASH, that features multiplication by a fixed parameter, called the hash subkey, within a binary Galois field.".

 @param ghashBlock Output parameter with the hash block
 @param buffer Input parameter with the data to hash
 @param bufferSize Length of the buffer, it has to be a multiple of sizeof(IAGBlockType)
 @param hashSubkey The hash subkey
 */
+ (void)getGhashBlock:(IAGBlockType _Nonnull )ghashBlock
           withBuffer:(IAGUCharType *)buffer
           bufferSize:(IAGSizeType)bufferSize
           hashSubkey:(IAGBlockType _Nonnull )hashSubkey;

/**
 This method generates the counter buffers used during the encryption/decryption process.

 @param gcounterBuffer Output paramter with same size than inpit buffer
 @param buffer Input parameter
 @param bufferSize Size of the input buffer
 @param icb Initial Counter Block
 @param key Key used by the "Forward cipher function"
 @param error Set to a value if the operation fails

 @return YES if the operation is successful, NO in other case

 @see IAGAesGcm
 @see IAGErrorFactory
 @see [IAGAesComponents getCipheredBlock:byUsingAESOnBlock:withKey:error:]
 */
+ (BOOL)getGCounterBuffer:(IAGUCharType *)gcounterBuffer
               withBuffer:(IAGUCharType *)buffer
               bufferSize:(IAGSizeType)bufferSize
      initialCounterBlock:(IAGBlockType _Nonnull )icb
                      key:(NSData *)key
                    error:(NSError **)error;

/**
 Increment the right-most 32 bits of the input buffer, regarded as an integer (modulo 2^32), and leave the remaining left-most bits unchanged.

 @param incBuffer Output parameter
 @param buffer Input paramater
 @param size Size of both buffers, it has to be greater than or equal to sizeof(IAGUInt32Type)
 */
+ (void)get32BitIncrementedBuffer:(IAGUCharType *)incBuffer
                       withBuffer:(IAGUCharType *)buffer
                             size:(IAGSizeType)size;

@end

NS_ASSUME_NONNULL_END
