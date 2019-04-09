//
//  KTVHCHTTPResponse.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/10.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCHTTPResponse.h"
#import "KTVHCHTTPConnection.h"
#import "KTVHCDataStorage.h"
#import "KTVHCLog.h"

@interface KTVHCHTTPResponse () <KTVHCDataReaderDelegate>

@property (nonatomic) BOOL waitingResponse;
@property (nonatomic, strong) KTVHCDataReader *reader;
@property (nonatomic, weak) KTVHCHTTPConnection *connection;

@end

@implementation KTVHCHTTPResponse

- (instancetype)initWithConnection:(KTVHCHTTPConnection *)connection dataRequest:(KTVHCDataRequest *)dataRequest
{
    if (self = [super init]) {
        KTVHCLogAlloc(self);
        self.connection = connection;
        self.reader = [[KTVHCDataStorage storage] readerWithRequest:dataRequest];
        self.reader.delegate = self;
        [self.reader prepare];
        KTVHCLogHTTPResponse(@"%p, Create response\nrequest : %@", self, dataRequest);
    }
    return self;
}

- (void)dealloc
{
    [self.reader close];
    KTVHCLogDealloc(self);
}

#pragma mark - HTTPResponse

- (NSData *)readDataOfLength:(NSUInteger)length
{
    NSData *data = [self.reader readDataOfLength:length];
    KTVHCLogHTTPResponse(@"%p, Read data : %lld", self, (long long)data.length);
    if (self.reader.isFinished) {
        KTVHCLogHTTPResponse(@"%p, Read data did finished", self);
        [self.reader close];
        [self.connection responseDidAbort:self];
    }
    return data;
}

- (BOOL)delayResponseHeaders
{
    BOOL waiting = !self.reader.isPrepared;
    self.waitingResponse = waiting;
    KTVHCLogHTTPResponse(@"%p, Delay response : %d", self, self.waitingResponse);
    return waiting;
}

- (UInt64)contentLength
{
    KTVHCLogHTTPResponse(@"%p, Conetnt length : %lld", self, self.reader.response.totalLength);
    return self.reader.response.totalLength;
}

- (NSDictionary *)httpHeaders
{
    NSMutableDictionary *headers = [self.reader.response.headers mutableCopy];
    [headers removeObjectForKey:@"Content-Range"];
    [headers removeObjectForKey:@"content-range"];
    [headers removeObjectForKey:@"Content-Length"];
    [headers removeObjectForKey:@"content-length"];
    KTVHCLogHTTPResponse(@"%p, Header\n%@", self, headers);
    return headers;
}

- (UInt64)offset
{
    KTVHCLogHTTPResponse(@"%p, Offset : %lld", self, self.reader.readedLength);
    return self.reader.readedLength;
}

- (void)setOffset:(UInt64)offset
{
    KTVHCLogHTTPResponse(@"%p, Set offset : %lld, %lld", self, offset, self.reader.readedLength);
}

- (BOOL)isDone
{
    KTVHCLogHTTPResponse(@"%p, Check done : %d", self, self.reader.isFinished);
    return self.reader.isFinished;
}

- (void)connectionDidClose
{
    KTVHCLogHTTPResponse(@"%p, Connection did closed : %lld, %lld", self, self.reader.response.contentLength, self.reader.readedLength);
    [self.reader close];
}

#pragma mark - KTVHCDataReaderDelegate

- (void)ktv_readerDidPrepare:(KTVHCDataReader *)reader
{
    KTVHCLogHTTPResponse(@"%p, Prepared", self);
    if (self.reader.isPrepared && self.waitingResponse == YES) {
        KTVHCLogHTTPResponse(@"%p, Call connection did prepared", self);
        [self.connection responseHasAvailableData:self];
    }
}

- (void)ktv_readerHasAvailableData:(KTVHCDataReader *)reader
{
    KTVHCLogHTTPResponse(@"%p, Has available data", self);
    [self.connection responseHasAvailableData:self];
}

- (void)ktv_reader:(KTVHCDataReader *)reader didFailWithError:(NSError *)error
{
    KTVHCLogHTTPResponse(@"%p, Failed\nError : %@", self, error);
    [self.reader close];
    [self.connection responseDidAbort:self];
}

@end
