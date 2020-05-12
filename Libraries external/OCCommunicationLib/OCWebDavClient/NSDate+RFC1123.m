//
//  NSDate+RFC1123.h
//  OCWebDAVClient
//
//  This class is based in https://github.com/zwaldowski/DZWebDAVClient. Copyright (c) 2012 Zachary Waldowski, Troy Brant, Marcus Rohrmoser, and Sam Soffes.
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


#import "NSDate+RFC1123.h"

static NSDateFormatter *RFC1123Formatter(void) {
	static NSDateFormatter *formatter = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		formatter = [NSDateFormatter new];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
        formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
        formatter.dateFormat = @"EEE',' dd MMM yyyy HH':'mm':'ss z";
	});
	return formatter;
}

static NSDateFormatter *RFC850Formatter(void) {
	static NSDateFormatter *formatter = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		formatter = [NSDateFormatter new];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
        formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
        formatter.dateFormat = @"EEEE',' dd'-'MMM'-'yy HH':'mm':'ss z";
	});
	return formatter;
}

static NSDateFormatter *ASCTimeFormatter(void) {
	static NSDateFormatter *formatter = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		formatter = [NSDateFormatter new];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
        formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
        formatter.dateFormat = @"EEE MMM d HH':'mm':'ss yyyy";
	});
	return formatter;
}

@implementation NSDate (RFC1123)

+ (NSDate *)dateFromRFC1123String:(NSString *)value {
    if (!value.length)
        return nil;
	
	return [RFC1123Formatter() dateFromString: value] ?: [RFC850Formatter() dateFromString: value] ?: [ASCTimeFormatter() dateFromString: value];
}

- (NSString *)RFC1123String {
	return [RFC1123Formatter() stringFromDate: self];
}

@end
