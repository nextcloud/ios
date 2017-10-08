//
//  IAGGcmEndianness.h
//  Pods
//
//  Created by Enrique de la Torre (dev) on 25/09/2016.
//
//

#import <Foundation/Foundation.h>

#import "IAGTypes.h"

/**
 Use the methods in this class to converts integers from/to GCM format to/from the host’s native byte order.
 */
@interface IAGGcmEndianness : NSObject

/**
 Convert a 32-bit unsigned integer with host’s native byte order to GCM format.

 @param arg 32-bit unsigned integer with host’s native byte order
 
 @return 32-bit unsigned integer in GCM format
 */
+ (IAGUInt32Type)swapUInt32HostToGcm:(IAGUInt32Type)arg;

/**
 Convert a 32-bit unsigned integer in GCM format to host’s native byte order.

 @param arg 32-bit unsigned integer in GCM format

 @return 32-bit unsigned integer with host’s native byte order
 */
+ (IAGUInt32Type)swapUInt32GcmToHost:(IAGUInt32Type)arg;

/**
 Convert a 64-bit unsigned integer with host’s native byte order to GCM format.

 @param arg 64-bit unsigned integer with host’s native byte order

 @return 64-bit unsigned integer in GCM format
 */
+ (IAGUInt64Type)swapUInt64HostToGcm:(IAGUInt64Type)arg;

@end
