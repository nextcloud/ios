//
//  IAGError.m
//  Pods
//
//  Created by Enrique de la Torre (dev) on 20/09/2016.
//
//

#import "IAGError.h"

NSString * const IAGErrorDomain = @"IAGErrorDomain";

@implementation IAGErrorFactory

#pragma mark - Public class methods

+ (NSError *)errorAESFailed
{
    return [NSError errorWithDomain:IAGErrorDomain
                               code:IAGErrorCodeAESFailed
                           userInfo:nil];
}

+ (NSError *)errorInputDataLengthNotSupported
{
    return [NSError errorWithDomain:IAGErrorDomain
                               code:IAGErrorCodeInputDataLengthNotSupported
                           userInfo:nil];
}

+ (NSError *)errorAuthenticationTagsNotIdentical
{
    return [NSError errorWithDomain:IAGErrorDomain
                               code:IAGErrorCodeAuthenticationTagsNotIdentical
                           userInfo:nil];
}

@end
