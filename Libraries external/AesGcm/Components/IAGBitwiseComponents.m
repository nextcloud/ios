//
//  IAGBitwiseComponents.m
//  Pods
//
//  Created by Enrique de la Torre (dev) on 25/09/2016.
//
//

#import "IAGBitwiseComponents.h"

const IAGUInt8Type IAGBitsInUChar = 8;
const IAGUInt8Type IAGMaxBitPositionInABlock = (IAGBitsInUChar * sizeof(IAGBlockType) - 1);

@implementation IAGBitwiseComponents

+ (void)getXorBlock:(IAGBlockType)buffer
          withBlock:(IAGBlockType)value1
           andBlock:(IAGBlockType)value2
{
    [IAGBitwiseComponents getXorBuffer:buffer
                            withBuffer:value1
                                buffer:value2
                            bufferSize:sizeof(IAGBlockType)];
}

+ (void)getXorBuffer:(IAGUCharType *)buffer
          withBuffer:(IAGUCharType *)value1
              buffer:(IAGUCharType *)value2
          bufferSize:(IAGSizeType)bufferSize
{
    for (IAGSizeType i = 0; i < bufferSize; i++)
    {
        buffer[i] = (value1[i] ^ value2[i]);
    }
}

+ (void)getSingleRightShiftedBlock:(IAGBlockType)shiftedBlock withBlock:(IAGBlockType)block
{
    for (IAGSizeType i = 0; i < sizeof(IAGBlockType); i++)
    {
        shiftedBlock[i] = block[i] >> 1;

        if ((i > 0) && (block[i - 1] & 0x01))
        {
            shiftedBlock[i] = (shiftedBlock[i] | 0x80);
        }
    }
}

+ (void)getMostSignificantBytes:(IAGUCharType *)msb
                       withSize:(IAGSizeType)msbSyze
                       inBuffer:(IAGUCharType *)buffer
                       withSize:(IAGSizeType)bufferSize
{
    NSParameterAssert(msbSyze <= bufferSize);

    memcpy(msb, buffer, msbSyze);
}

+ (void)getLeastSignificantBytes:(IAGUCharType *)lsb
                        withSize:(IAGSizeType)lsbSyze
                        inBuffer:(IAGUCharType *)buffer
                        withSize:(IAGSizeType)bufferSize
{
    NSParameterAssert(lsbSyze <= bufferSize);

    memcpy(lsb, buffer + (bufferSize - lsbSyze), lsbSyze);
}

+ (BOOL)isMostSignificantBitActivatedAtPosition:(IAGUInt8Type)position
                                        inBlock:(IAGBlockType)block
{
    NSParameterAssert(position <= IAGMaxBitPositionInABlock);

    IAGUCharType mostSignificantByte = block[position / IAGBitsInUChar];
    IAGUCharType mask = 0x80 >> (position % IAGBitsInUChar);
    IAGUCharType mostSignificantBit = (mostSignificantByte & mask);

    return (mostSignificantBit != 0);
}

+ (BOOL)isLeastSignificantBitActivatedAtPosition:(IAGUInt8Type)position
                                         inBlock:(IAGBlockType)block
{
    NSParameterAssert(position <= IAGMaxBitPositionInABlock);

    IAGUCharType leastSignificantByte = block[(IAGMaxBitPositionInABlock - position) / IAGBitsInUChar];
    IAGUCharType mask = 0x01 << (position % IAGBitsInUChar);
    IAGUCharType leastSignificantBit = (leastSignificantByte & mask);

    return (leastSignificantBit != 0);
}

@end
