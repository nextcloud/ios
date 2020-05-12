//
//  NSDate+RFC1123.h
//  OCWebDAVClient.h
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


#import <Foundation/Foundation.h>

/**
 * Provides extensions to `NSDate` for representing RFC1123-formatted strings.
 * 
 * Based on the [W3 specification](http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.3.1) and ["NSDateFormatter & HTTP Header"](http://blog.mro.name/2009/08/nsdateformatter-http-header/).
 */
@interface NSDate (RFC1123)

/**
 Convert a RFC1123 'Full-Date' string (http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.3.1) into NSDate.
 @param value something like either @"Fri, 14 Aug 2009 14:45:31 GMT" or @"Sunday, 06-Nov-94 08:49:37 GMT" or @"Sun Nov  6 08:49:37 1994"
 @return nil if not parseable.
 */
+ (NSDate *)dateFromRFC1123String:(NSString *)value;

/**
 Convert NSDate into a RFC1123 'Full-Date' string (http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.3.1).
 @return something like @"Fri, 14 Aug 2009 14:45:31 GMT"
 */
- (NSString *)RFC1123String;

@end
