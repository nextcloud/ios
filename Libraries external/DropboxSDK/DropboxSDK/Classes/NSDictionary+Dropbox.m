//
//  NSDictionary+Dropbox.m
//  Dropbox
//
//  Created by Brian Smith on 6/5/11.
//  Copyright 2011 Dropbox, Inc. All rights reserved.
//

#import "NSDictionary+Dropbox.h"


@implementation NSDictionary (Dropbox)

+ (NSDictionary *)dictionaryWithQueryString:(NSString *)query {
    NSArray *pairs = [query componentsSeparatedByString:@"&"];
    NSMutableDictionary *params = [[[NSMutableDictionary alloc] init] autorelease];
    for (NSString *pair in pairs) {
        NSArray *kv = [pair componentsSeparatedByString:@"="];
        NSString *val =
            [[kv objectAtIndex:1]
             stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

        [params setObject:val forKey:[kv objectAtIndex:0]];
    }
    return params;
}

- (NSString *)urlRepresentation {
    NSMutableString *str = [NSMutableString stringWithString:@""];
    for (id key in self) {
        CFStringRef escapeChars = (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ";
        CFStringRef sKey = (CFStringRef)[key description];
        NSString *eKey = (NSString *)CFURLCreateStringByAddingPercentEscapes(
            NULL, sKey, NULL, escapeChars, kCFStringEncodingUTF8);
        CFStringRef sVal = (CFStringRef)[[self objectForKey:key] description];
        NSString *eVal = (NSString *)CFURLCreateStringByAddingPercentEscapes(
            NULL, sVal, NULL, escapeChars, kCFStringEncodingUTF8);
        if ([str length] > 0) {
            [str appendString:@"&"];
        }
        [str appendFormat:@"%@=%@", eKey, eVal];
        [eKey release];
        [eVal release];
    }
    return str;
}

@end
