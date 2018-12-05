//
//  KTVHCHTTPRequest.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/10.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCHTTPRequest.h"
#import "KTVHCLog.h"

@implementation KTVHCHTTPRequest

- (instancetype)initWithURL:(NSURL *)URL headers:(NSDictionary *)headers
{
    if (self = [super init])
    {
        KTVHCLogAlloc(self);
        _URL = URL;
        _headers = headers;
        KTVHCLogHTTPRequest(@"%p, Create reqeust\nURL : %@\nHeaders : %@", self, self.URL, self.headers);
    }
    return self;
}

- (void)dealloc
{
    KTVHCLogDealloc(self);
}

@end
