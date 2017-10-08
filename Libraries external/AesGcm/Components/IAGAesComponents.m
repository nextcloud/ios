//
//  IAGAesComponents.m
//  Pods
//
//  Created by Enrique de la Torre (dev) on 20/09/2016.
//
//

#import <CommonCrypto/CommonCryptor.h>

#import "IAGAesComponents.h"

#import "IAGError.h"

@implementation IAGAesComponents

#pragma mark - Public class methods

+ (BOOL)getCipheredBlock:(IAGBlockType)cipheredBlock
       byUsingAESOnBlock:(IAGBlockType)block
                 withKey:(NSData *)key
                   error:(NSError **)error
{
    size_t dataOutMoved = 0;
    CCCryptorStatus status = CCCrypt(kCCEncrypt,
                                     kCCAlgorithmAES,
                                     kCCOptionECBMode,
                                     key.bytes,
                                     key.length,
                                     nil,
                                     block,
                                     sizeof(IAGBlockType),
                                     cipheredBlock,
                                     sizeof(IAGBlockType),
                                     &dataOutMoved);
    BOOL success = ((status == kCCSuccess) && (dataOutMoved  == sizeof(IAGBlockType)));

    if (!success && error)
    {
        *error = [IAGErrorFactory errorAESFailed];
    }

    return success;
}

@end
