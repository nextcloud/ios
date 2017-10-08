//
//  IAGError.h
//  Pods
//
//  Created by Enrique de la Torre (dev) on 20/09/2016.
//
//

#import <Foundation/Foundation.h>

/** "One and only" list of error codes in this pod */
typedef NS_ENUM(NSInteger, IAGErrorCode) {
    /** @see [IAGErrorFactory errorAESFailed] */
    IAGErrorCodeAESFailed = 0,
    /** @see [IAGErrorFactory errorInputDataLengthNotSupported] */
    IAGErrorCodeInputDataLengthNotSupported,
    /** @see [IAGErrorFactory errorAuthenticationTagsNotIdentical] */
    IAGErrorCodeAuthenticationTagsNotIdentical
};

NS_ASSUME_NONNULL_BEGIN

/** "One and only" error domain in this pod */
extern NSString * const IAGErrorDomain;

/**
 Simple factory to easily build each of the errors generated while ciphering/deciphering data.
 */
@interface IAGErrorFactory : NSObject

/**
 Error returned if something goes wrong while ciphering a block with AES.
 
 @see IAGBlockType
 @see [IAGAesComponents getCipheredBlock:byUsingAESOnBlock:withKey:error:]
 */
+ (NSError *)errorAESFailed;

/**
 Error returned when the data passed to cipher/decipher methods does not have a supported length.
 
 @see IAGAesGcm
 */
+ (NSError *)errorInputDataLengthNotSupported;

/**
 Error returned when the authentication tag generated after deciphering some data is not identical to the tag passed by parameter.

 @see [IAGAesGcm plainDataByAuthenticatedDecryptingCipheredData:withAdditionalAuthenticatedData:initializationVector:key:error:]
 */
+ (NSError *)errorAuthenticationTagsNotIdentical;

@end

NS_ASSUME_NONNULL_END
