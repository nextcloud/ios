//
//  KTVHCHTTPConnection.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/10.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCHTTPConnection.h"
#import "KTVHCHTTPRequest.h"
#import "KTVHCHTTPResponse.h"
#import "KTVHCHTTPPingResponse.h"
#import "KTVHCHTTPURL.h"
#import "KTVHCLog.h"

@implementation KTVHCHTTPConnection

+ (NSString *)pingResponseValue
{
    return KTVHCHTTPPingResponseResponseValue;
}

- (id)initWithAsyncSocket:(GCDAsyncSocket *)newSocket configuration:(HTTPConfig *)aConfig
{
    if (self = [super initWithAsyncSocket:newSocket configuration:aConfig])
    {
        KTVHCLogAlloc(self);
    }
    return self;
}

- (void)dealloc
{
    KTVHCLogDealloc(self);
}

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
    KTVHCLogHTTPConnection(@"%p, Receive request\nmethod : %@\npath : %@\nURL : %@", self, method, path, request.url);
    KTVHCHTTPURL * URL = [[KTVHCHTTPURL alloc] initWithProxyURL:request.url];
    switch (URL.type)
    {
        case KTVHCHTTPURLTypeUnknown:
            return nil;
        case KTVHCHTTPURLTypePing:
        {
            KTVHCHTTPPingResponse * currentResponse = [KTVHCHTTPPingResponse responseWithConnection:self];
            return currentResponse;
        }
        case KTVHCHTTPURLTypeContent:
        {
            KTVHCHTTPRequest * currentRequest = [[KTVHCHTTPRequest alloc] initWithURL:URL.URL headers:request.allHeaderFields];
            currentRequest.method = request.method;
            currentRequest.version = request.version;
            KTVHCHTTPResponse * currentResponse = [[KTVHCHTTPResponse alloc] initWithConnection:self request:currentRequest];
            return currentResponse;
        }
    }
    return nil;
}


@end
