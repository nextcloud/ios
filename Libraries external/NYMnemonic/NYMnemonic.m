// NYMnemonic.m
//
// Copyright (c) 2014 Nybex, Inc. (https://nybex.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
#import "NYMnemonic.h"

@implementation NYMnemonic
+ (NSString *)mnemonicStringFromRandomHexString:(NSString *)seed language:(NSString *)language {

    // Convert our hex string to NSData
    NSData *seedData = [seed ny_dataFromHexString];

    // Calculate the sha256 hash to use with a checksum
    NSMutableData *hash = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(seedData.bytes, (int)seedData.length, hash.mutableBytes);

    NSMutableArray *checksumBits = [NSMutableArray
      arrayWithArray:[[NSData dataWithData:hash] ny_hexToBitArray]];
    NSMutableArray *seedBits =
      [NSMutableArray arrayWithArray:[seedData ny_hexToBitArray]];

    // Append the appropriate checksum bits to the seed
    for (int i = 0; i < (int)seedBits.count / 32; i++) {
        [seedBits addObject: checksumBits[i]];
    }
    NSString *path = [NSString stringWithFormat:@"%@/%@.txt", [[NSBundle mainBundle] bundlePath], language];
    NSString *fileText = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    NSArray *lines = [fileText componentsSeparatedByCharactersInSet: [NSCharacterSet newlineCharacterSet]];

    // Split into groups of 11, and change to numbers
    NSMutableArray *words = [NSMutableArray arrayWithCapacity:(int)seedBits.count / 11];
    for (int i = 0; i < (int)seedBits.count / 11; i++) {
        NSUInteger wordNumber =
            strtol(
                [[[seedBits subarrayWithRange: NSMakeRange(i * 11, 11)] componentsJoinedByString: @""] UTF8String],
                NULL,
                2);

        [words addObject: lines[wordNumber]];
    }

    return [words componentsJoinedByString:@" "];
}

+ (NSString *)deterministicSeedStringFromMnemonicString:(NSString *)mnemonic
                                             passphrase:(NSString *)passphrase
                                               language:(NSString *)language {

    NSData *data = [mnemonic dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString *dataString = [[NSString alloc] initWithData: data encoding: NSASCIIStringEncoding];
    NSData *normalized = [dataString dataUsingEncoding: NSASCIIStringEncoding allowLossyConversion: NO];

    NSData *saltData =
      [[@"mnemonic" stringByAppendingString: [[NSString alloc] initWithData:[passphrase dataUsingEncoding: NSASCIIStringEncoding
                                                       allowLossyConversion:YES]
                                     encoding:NSASCIIStringEncoding]]
       dataUsingEncoding: NSASCIIStringEncoding
       allowLossyConversion: NO];

    NSMutableData *hashKeyData =
      [NSMutableData dataWithLength:CC_SHA512_DIGEST_LENGTH];

    CCKeyDerivationPBKDF(kCCPBKDF2, normalized.bytes, normalized.length,
                       saltData.bytes, saltData.length, kCCPRFHmacAlgSHA512,
                       2048, hashKeyData.mutableBytes, hashKeyData.length);

    return [[NSData dataWithData:hashKeyData] ny_hexString];
}

+ (NSString *)generateMnemonicString:(NSNumber *)strength
                            language:(NSString *)language {

    // Check that the strength is divisible by 32
    if ([strength intValue] % 32 != 0) {
        [NSException raise:@"Strength must be divisible by 32"
                    format:@"Strength Was: %@", strength];
    }

    // Create an array of bytes
    NSMutableData *bytes = [NSMutableData dataWithLength: ([strength integerValue]/8)];
    // Generate the random data
    int status = SecRandomCopyBytes(kSecRandomDefault, bytes.length, bytes.mutableBytes);
    // Make sure we were successful
    if (status != -1) {
        return [self mnemonicStringFromRandomHexString:[bytes ny_hexString] language:language];
    } else {
        [NSException raise:@"Unable to get random data!"
                    format:@"Unable to get random data!"];
    }
    return nil;
}
@end

@implementation NSData (NYMnemonic)
- (NSString *)ny_hexString {
    const unsigned char *dataBuffer = (const unsigned char *)[self bytes];

    if (!dataBuffer) {
        return [NSString string];
    }

    NSUInteger dataLength = [self length];
    NSMutableString *hexString = [NSMutableString stringWithCapacity:(dataLength * 2)];
    for (int i = 0; i < dataLength; ++i) {
        [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)dataBuffer[i]]];
    }

    return [NSString stringWithString:hexString];
}

- (NSArray *)ny_hexToBitArray {
    NSMutableArray *bitArray = [NSMutableArray arrayWithCapacity:(int)self.length * 8];
    NSString *hexStr = [self ny_hexString];
    // Loop over the string and convert each char
    for (NSUInteger i = 0; i < [hexStr length]; i++) {
        NSString *bin = [self _hexToBinary:[hexStr characterAtIndex:i]];
        // Each character will return a string representation of the binary
        // Create NSNumbers from each and append to the array.
        for (NSInteger j = 0; j < bin.length; j++) {
            [bitArray addObject:
                @([[NSString stringWithFormat: @"%C", [bin characterAtIndex: j]] intValue])];
        }
    }
    return [NSArray arrayWithArray:bitArray];
}

- (NSString *)_hexToBinary:(unichar)value {
    switch (value) {
        case '0': return @"0000";
        case '1': return @"0001";
        case '2': return @"0010";
        case '3': return @"0011";
        case '4': return @"0100";
        case '5': return @"0101";
        case '6': return @"0110";
        case '7': return @"0111";
        case '8': return @"1000";
        case '9': return @"1001";

        case 'a':
        case 'A': return @"1010";

        case 'b':
        case 'B': return @"1011";

        case 'c':
        case 'C': return @"1100";

        case 'd':
        case 'D': return @"1101";

        case 'e':
        case 'E': return @"1110";

        case 'f':
        case 'F': return @"1111";
    }
    return @"-1";
}

@end

@implementation NSString (NYMnemonic)
- (NSData *)ny_dataFromHexString {
    const char *chars = [self UTF8String];
    int i = 0, len = (int)self.length;

    NSMutableData *data = [NSMutableData dataWithCapacity:len / 2];
    char byteChars[3] = { '\0', '\0', '\0' };
    unsigned long wholeByte;

    while (i < len) {
        byteChars[0] = chars[i++];
        byteChars[1] = chars[i++];
        wholeByte = strtoul(byteChars, NULL, 16);
        [data appendBytes:&wholeByte length:1];
    }

    return data;
}

@end
