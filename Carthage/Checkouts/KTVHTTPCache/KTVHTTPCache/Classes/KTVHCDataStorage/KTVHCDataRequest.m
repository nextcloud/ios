//
//  KTVHCDataRequest.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCDataRequest.h"
#import "KTVHCLog.h"

@implementation KTVHCDataRequest

- (instancetype)initWithURL:(NSURL *)URL headers:(NSDictionary *)headers
{
    if (self = [super init])
    {
        KTVHCLogAlloc(self);
        _URL = URL;
        if (![headers objectForKey:@"Range"]) {
            _headers = KTVHCRangeFillToRequestHeaders(KTVHCRangeFull(), headers);
        } else {
            _headers = headers;
        }
        _range = KTVHCRangeWithRequestHeaderValue([_headers objectForKey:@"Range"]);
        KTVHCLogDataRequest(@"%p Create data request\nURL : %@\nHeaders : %@\nRange : %@", self, self.URL, self.headers, KTVHCStringFromRange(self.range));
    }
    return self;
}

- (void)dealloc
{
    KTVHCLogDealloc(self);
}

- (KTVHCDataRequest *)requestWithRange:(KTVHCRange)range
{
    if (!KTVHCEqualRanges(self.range, range))
    {
        NSDictionary * headers = KTVHCRangeFillToRequestHeaders(range, self.headers);
        KTVHCDataRequest * obj = [[KTVHCDataRequest alloc] initWithURL:self.URL headers:headers];
        return obj;
    }
    return self;
}

- (KTVHCDataRequest *)requestWithTotalLength:(long long)totalLength
{
    KTVHCRange range = KTVHCRangeWithEnsureLength(self.range, totalLength);
    return [self requestWithRange:range];
}

@end
