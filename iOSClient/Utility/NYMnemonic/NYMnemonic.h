// NYMnemonic.h
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

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonKeyDerivation.h>

/**
 `NYMnemonic` is an objective-c implimentation of BIP-39 style mnemonic codes
 for use with generating deterministic keys.
 */
@interface NYMnemonic : NSObject

/**
 Creates a mnemonic code from a hex encoded seed.

 @param seed The hex encoded random seed. Should be between 128-256 bits
 @param language The language file to use. Currently the only value is 'english'

 @return a string containing the mnemonic code
 */
+ (NSString *)mnemonicStringFromRandomHexString:(NSString *)seed
                                       language:(NSString *)language;
/**
 Creates a mnemonic code from a hex encoded seed.

 @param mnemonic The mnemonic phrase to use as the deterministic seed
 @param passphrase A passphrase to be applied when creating the seed
 @param language The language file to use. Currently the only value is 'english'

 @return a string containing the deterministic seed
 */
+ (NSString *)deterministicSeedStringFromMnemonicString:(NSString *)mnemonic
                                             passphrase:(NSString *)passphrase
                                               language:(NSString *)language;

/**
 Creates a mnemonic code from a hex encoded seed.

 @param strength The strength of code, should be >=128 & <=256 & divisible by 32
 @param language The language file to use. Currently the only value is 'english'

 @return a string containing the mnemonic code
 */
+ (NSString *)generateMnemonicString:(NSNumber *)strength
                            language:(NSString *)language;
@end

/**
 Category on NSData that helps with conversion to bit arrays and to hex
 strings.
 */
@interface NSData (NYMnemonic)
- (NSString *)ny_hexString;
- (NSArray *)ny_hexToBitArray;
@end

/**
 Category on NSString to convert a hex string to NSData
 @return NSData
 */
@interface NSString (NYMnemonic)
- (NSData *)ny_dataFromHexString;
@end
