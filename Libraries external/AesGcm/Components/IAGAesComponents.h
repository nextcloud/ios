//
//  IAGAesComponents.h
//  Pods
//
//  Created by Enrique de la Torre (dev) on 20/09/2016.
//
//

#import <Foundation/Foundation.h>

#import "IAGTypes.h"

/**
 [As mentioned in the documentation](http://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-38d.pdf): "The operations of GCM depend on the choice of an underlying symmetric key block cipher ...". In this case, the chosen algorithm is AES and here you can find the "forward cipher function" used in this implementation of GCM.
 */

NS_ASSUME_NONNULL_BEGIN

@interface IAGAesComponents : NSObject

/**
 "Forward cipher function" required by GCM and based on AES.

 @param cipheredBlock Output parameter with the resulting ciphered data
 @param block Input parameter with the data to cipher
 @param key Key used to cipher the data with length: kCCKeySizeAES128 (16), kCCKeySizeAES192 (24) or kCCKeySizeAES256 (32) bytes
 @param error Set to a value if the operation fails
 
 @return YES if the operation is successful, NO in other case
 
 @see IAGErrorFactory
 */
+ (BOOL)getCipheredBlock:(IAGBlockType _Nonnull )cipheredBlock
       byUsingAESOnBlock:(IAGBlockType _Nonnull )block
                 withKey:(NSData *)key
                   error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
