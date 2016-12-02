//
//  NSURL+MPEncodingAdditions.m
//  MPOAuthConnection
//
//  Created by Karl Adam on 08.12.05.
//  Copyright 2008 matrixPointer. All rights reserved.
//

#import "NSURLResponse+Encoding.h"


@implementation NSURLResponse (EncodingAdditions)

- (NSStringEncoding)encoding {
	NSStringEncoding encoding = NSUTF8StringEncoding;
	
	if ([self textEncodingName]) {
		CFStringEncoding cfStringEncoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef)[self textEncodingName]);
		if (cfStringEncoding != kCFStringEncodingInvalidId) {
			encoding = CFStringConvertEncodingToNSStringEncoding(cfStringEncoding); 
		}
	}
	
	return encoding;
}

@end
