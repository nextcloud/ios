//
//  IAGCipheredData.m
//  Pods
//
//  Created by Enrique de la Torre (dev) on 17/09/2016.
//
//

#import "IAGCipheredData.h"

@interface IAGCipheredData ()

@property (nonatomic) NSData *cipheredData;
@property (nonatomic) NSData *authenticationTagData;

@end

@implementation IAGCipheredData

#pragma mark - Synthesize properties

- (const void *)cipheredBuffer
{
    return self.cipheredData.bytes;
}

- (NSUInteger)cipheredBufferLength
{
    return self.cipheredData.length;
}

- (const void *)authenticationTag
{
    return self.authenticationTagData.bytes;
}

- (IAGAuthenticationTagLength)authenticationTagLength
{
    return self.authenticationTagData.length;
}

#pragma mark - NSObject methods

- (NSString *)description
{
    return [NSString stringWithFormat:@"Ciphertext: %@. Auth tag: %@",
            self.cipheredData, self.authenticationTagData];
}

#pragma mark - Init object

- (instancetype)initWithCipheredBuffer:(const void *)cipheredBuffer
                  cipheredBufferLength:(NSUInteger)cipheredBufferLength
                     authenticationTag:(const void *)authenticationTag
               authenticationTagLength:(IAGAuthenticationTagLength)authenticationTagLength
{
    self = [super init];

    if (self)
    {
        _cipheredData = [NSData dataWithBytes:cipheredBuffer length:cipheredBufferLength];
        _authenticationTagData = [NSData dataWithBytes:authenticationTag
                                                length:authenticationTagLength];
    }

    return self;
}

#pragma mark - Equality

- (NSUInteger)hash
{
    return self.cipheredData.hash;
}

- (BOOL)isEqual:(id)object
{
    if ([self class] == [object class])
    {
        return [self isEqualToCipheredData:object];
    }

    return [super isEqual:object];
}

- (BOOL)isEqualToCipheredData:(IAGCipheredData *)object
{
    if (self == object)
    {
        return YES;
    }

    return ([self.cipheredData isEqualToData:object.cipheredData] &&
            [self.authenticationTagData isEqualToData:object.authenticationTagData]);
}

@end
