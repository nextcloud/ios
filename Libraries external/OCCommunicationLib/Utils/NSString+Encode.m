//
//  NSString+Encode.m
//  Owncloud iOs Client
//
// Copyright (C) 2016, ownCloud GmbH. ( http://www.owncloud.org/ )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//


#import "NSString+Encode.h"

@implementation NSString (encode)
- (NSString *)encodeString:(NSStringEncoding)encoding
{
    
    CFStringRef stringRef = CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)self,
                                                                    NULL, (CFStringRef)@";?@&=$+{}<>,!'*",
                                                                    CFStringConvertNSStringEncodingToEncoding(encoding));
    
    NSString *output = (NSString *)CFBridgingRelease(stringRef);
                                                                    
                                                                    
    

    int countCharactersAfterPercent = -1;
    
    for(int i = 0 ; i < [output length] ; i++) {
        NSString * newString = [output substringWithRange:NSMakeRange(i, 1)];
        //NSLog(@"newString: %@", newString);
        
        if(countCharactersAfterPercent>=0) {
            
            //NSLog(@"newString lowercaseString: %@", [newString lowercaseString]);
            output = [output stringByReplacingCharactersInRange:NSMakeRange(i, 1) withString:[newString lowercaseString]];
            countCharactersAfterPercent++;
        }
        
        if([newString isEqualToString:@"%"]) {
            countCharactersAfterPercent = 0;
        }
        
        if(countCharactersAfterPercent==2) {
            countCharactersAfterPercent = -1;
        }
    }
    
   // NSLog(@"output: %@", output);
    
    return output;
}

@end
