//
//  IAGGcmEndianness.m
//  Pods
//
//  Created by Enrique de la Torre (dev) on 25/09/2016.
//
//

#import "IAGGcmEndianness.h"

@implementation IAGGcmEndianness

+ (IAGUInt32Type)swapUInt32HostToGcm:(IAGUInt32Type)arg
{
    return CFSwapInt32HostToBig(arg);
}

+ (IAGUInt32Type)swapUInt32GcmToHost:(IAGUInt32Type)arg
{
    return CFSwapInt32BigToHost(arg);
}

+ (IAGUInt64Type)swapUInt64HostToGcm:(IAGUInt64Type)arg
{
    return CFSwapInt64HostToBig(arg);
}

@end
