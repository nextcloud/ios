//
//  NCUchardet.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 16/08/17.
//  Copyright (c) 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "NCUchardet.h"
#import "uchardet.h"

@interface NCUchardet ()
{
   uchardet_t _detector;
}
@end

@implementation NCUchardet

+ (NCUchardet *)sharedNUCharDet {
    static NCUchardet *nuCharDet;
    @synchronized(self) {
        if (!nuCharDet) {
            nuCharDet = [NCUchardet new];
        }
        return nuCharDet;
    }
}

- (id)init
{
    self = [super init];
    
    if (self) {
        _detector = uchardet_new();
    }
    
    return self;
}

- (void)dealloc
{
    uchardet_delete(_detector);
}

- (NSString *)encodingStringDetectWithData:(NSData *)data
{
    uchardet_handle_data(_detector, [data bytes], [data length]);
    uchardet_data_end(_detector);
    
    const char *charset = uchardet_get_charset(_detector);
    NSString *encodingName = [NSString stringWithCString:charset encoding:NSASCIIStringEncoding];
    
    uchardet_reset(_detector);
    
    // Default UTF-8
    if ([encodingName isEqualToString:@""])
        encodingName = @"UTF-8";
    
    return encodingName;
}

- (CFStringEncoding)encodingCFStringDetectWithData:(NSData *)data
{
    NSString *encodingName = [self encodingStringDetectWithData:data];
    
    if ([encodingName isEqualToString:@""]) {
        return kCFStringEncodingUTF8;
    }
    
    CFStringEncoding encoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef)encodingName);
    
    return encoding;
}

@end
