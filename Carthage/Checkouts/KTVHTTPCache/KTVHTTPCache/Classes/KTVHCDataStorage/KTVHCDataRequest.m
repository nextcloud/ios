//
//  KTVHCDataRequest.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCDataRequest.h"
#import "KTVHCData+Internal.h"
#import "KTVHCLog.h"

@implementation KTVHCDataRequest

- (instancetype)initWithURL:(NSURL *)URL headers:(NSDictionary *)headers
{
    if (self = [super init]) {
        KTVHCLogAlloc(self);
        self->_URL = URL;
        self->_headers = KTVHCRangeFillToRequestHeadersIfNeeded(KTVHCRangeFull(), headers);
        self->_range = KTVHCRangeWithRequestHeaderValue([self.headers objectForKey:@"Range"]);
        KTVHCLogDataRequest(@"%p Create data request\nURL : %@\nHeaders : %@\nRange : %@", self, self.URL, self.headers, KTVHCStringFromRange(self.range));
    }
    return self;
}

- (void)dealloc
{
    KTVHCLogDealloc(self);
}

- (KTVHCDataRequest *)newRequestWithRange:(KTVHCRange)range
{
    NSDictionary *headers = KTVHCRangeFillToRequestHeaders(range, self.headers);
    KTVHCDataRequest *obj = [[KTVHCDataRequest alloc] initWithURL:self.URL headers:headers];
    return obj;
}

- (KTVHCDataRequest *)newRequestWithTotalLength:(long long)totalLength
{
    KTVHCRange range = KTVHCRangeWithEnsureLength(self.range, totalLength);
    return [self newRequestWithRange:range];
}

@end
