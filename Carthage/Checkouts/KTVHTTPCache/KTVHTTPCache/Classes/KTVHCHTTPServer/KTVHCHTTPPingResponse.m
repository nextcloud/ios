//
//  KTVHCHTTPPingResponse.m
//  KTVHTTPCache
//
//  Created by Single on 2017/10/23.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCHTTPPingResponse.h"
#import "KTVHCHTTPConnection.h"
#import "KTVHCLog.h"

NSString * const KTVHCHTTPPingResponseResponseValue = @"pang";

@interface KTVHCHTTPPingResponse ()

@property (nonatomic, weak) KTVHCHTTPConnection * connection;
@property (nonatomic, strong) NSData * responseData;
@property (nonatomic, assign) long long readOffset;

@end

@implementation KTVHCHTTPPingResponse

+ (instancetype)responseWithConnection:(KTVHCHTTPConnection *)connection
{
    return [[self alloc] initWithConnection:connection];
}

- (instancetype)initWithConnection:(KTVHCHTTPConnection *)connection
{
    if (self = [super init])
    {
        KTVHCLogAlloc(self);
        static NSData * data = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            data = [KTVHCHTTPPingResponseResponseValue dataUsingEncoding:NSUTF8StringEncoding];
        });
        self.responseData = data;
    }
    return self;
}

- (void)dealloc
{
    KTVHCLogDealloc(self);
}

- (NSData *)readDataOfLength:(NSUInteger)length
{
    NSData * data = nil;
    NSUInteger readLength = (NSUInteger)MIN(length, self.responseData.length - self.readOffset);
    if (readLength == self.responseData.length)
    {
        data = self.responseData;
    }
    else if (readLength > 0)
    {
        data = [self.responseData subdataWithRange:NSMakeRange((NSUInteger)self.readOffset, readLength)];
    }
    self.readOffset += data.length;
    KTVHCLogHTTPResponsePing(@"%p, Read data : %lld", self, (long long)data.length);
    return data;
}

- (BOOL)delayResponseHeaders
{
    return NO;
}

- (UInt64)contentLength
{
    return self.responseData.length;
}

- (UInt64)offset
{
    return self.readOffset;
}

- (void)setOffset:(UInt64)offset
{
    self.readOffset = offset;
}

- (BOOL)isDone
{
    BOOL result = self.readOffset == self.responseData.length;
    return result;
}

- (void)connectionDidClose
{
    KTVHCLogHTTPResponsePing(@"%p, Connection did closed", self);
}

@end
