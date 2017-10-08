//
//  IAGBitwiseComponents.h
//  Pods
//
//  Created by Enrique de la Torre (dev) on 25/09/2016.
//
//

#import <Foundation/Foundation.h>

#import "IAGTypes.h"

/**
 Number of bits in a byte ... obviously 8 ... the only purpose of this constant is to easily track where this value is used and what for.
 */
extern const IAGUInt8Type IAGBitsInUChar;

/**
 Position of the last bit in a block.
 
 @see [IAGBitwiseComponents isMostSignificantBitActivatedAtPosition:inBlock:]
 @see [IAGBitwiseComponents isLeastSignificantBitActivatedAtPosition:inBlock:]
 */
extern const IAGUInt8Type IAGMaxBitPositionInABlock;

/**
 This class provides a bunch of methods able to work with data on bit or byte level.
 */

@interface IAGBitwiseComponents : NSObject

/**
 Perform a XOR operation with 2 blocks and copy the result in a third one.
 
 @param buffer Output parameter
 @param value1 Input parameter
 @param value2 Input parameter
 */
+ (void)getXorBlock:(IAGBlockType)buffer
          withBlock:(IAGBlockType)value1
           andBlock:(IAGBlockType)value2;

/**
 Perform a XOR operation with 2 buffers of the same size and copy the result in a third one.
 
 @param buffer Output parameter
 @param value1 Input parameter
 @param value2 Input parameter
 @param bufferSize Size of the 3 buffers
 */
+ (void)getXorBuffer:(IAGUCharType *)buffer
          withBuffer:(IAGUCharType *)value1
              buffer:(IAGUCharType *)value2
          bufferSize:(IAGSizeType)bufferSize;

/**
 Move one bit to the right a block.
 
 @param shiftedBlock Output parameter
 @param block Input parameter
 */
+ (void)getSingleRightShiftedBlock:(IAGBlockType)shiftedBlock withBlock:(IAGBlockType)block;

/**
 Get left-most msbSyze bytes out of an input buffer.

 @param msb Ouput parameter
 @param msbSyze Size of msb, it has to be less than or equal to bufferSize
 @param buffer Input parameter
 @param bufferSize Size of buffer
 */
+ (void)getMostSignificantBytes:(IAGUCharType *)msb
                       withSize:(IAGSizeType)msbSyze
                       inBuffer:(IAGUCharType *)buffer
                       withSize:(IAGSizeType)bufferSize;

/**
 Get right-most lsbSyze bytes out of an input buffer.

 @param lsb Ouput parameter
 @param lsbSyze Size of lsb, it has to be less than or equal to bufferSize
 @param buffer Input parameter
 @param bufferSize Size of buffer
 */
+ (void)getLeastSignificantBytes:(IAGUCharType *)lsb
                        withSize:(IAGSizeType)lsbSyze
                        inBuffer:(IAGUCharType *)buffer
                        withSize:(IAGSizeType)bufferSize;

/**
 @return YES if the left-most bit at the given position is 1
 */
+ (BOOL)isMostSignificantBitActivatedAtPosition:(IAGUInt8Type)position
                                        inBlock:(IAGBlockType)block;

/**
 @return YES if the right-most bit at the given position is 1
 */
+ (BOOL)isLeastSignificantBitActivatedAtPosition:(IAGUInt8Type)position
                                         inBlock:(IAGBlockType)block;

@end
