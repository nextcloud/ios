//
//  KTVHCDataSourceManager.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCDataSourceManager.h"
#import "KTVHCDataCallback.h"
#import "KTVHCLog.h"

@interface KTVHCDataSourceManager () <NSLocking, KTVHCDataFileSourceDelegate, KTVHCDataNetworkSourceDelegate>

@property (nonatomic, strong) NSLock *coreLock;
@property (nonatomic, strong) id <KTVHCDataSource> currentSource;
@property (nonatomic, strong) KTVHCDataNetworkSource *currentNetworkSource;
@property (nonatomic, strong) NSMutableArray<id<KTVHCDataSource>> *sources;
@property (nonatomic) BOOL calledPrepare;
@property (nonatomic) BOOL calledReceiveResponse;

@end

@implementation KTVHCDataSourceManager

@synthesize error = _error;
@synthesize range = _range;
@synthesize closed = _closed;
@synthesize prepared = _prepared;
@synthesize finished = _finished;
@synthesize readedLength = _readedLength;

- (instancetype)initWithSources:(NSArray<id<KTVHCDataSource>> *)sources delegate:(id<KTVHCDataSourceManagerDelegate>)delegate delegateQueue:(dispatch_queue_t)delegateQueue
{
    if (self = [super init]) {
        KTVHCLogAlloc(self);
        self->_sources = [sources mutableCopy];
        self->_delegate = delegate;
        self->_delegateQueue = delegateQueue;
    }
    return self;
}

- (void)dealloc
{
    KTVHCLogDealloc(self);
    KTVHCLogDataReader(@"%p, Destory reader\nError : %@\ncurrentSource : %@\ncurrentNetworkSource : %@", self, self.error, self.currentSource, self.currentNetworkSource);
}

- (void)prepare
{
    [self lock];
    if (self.isClosed) {
        [self unlock];
        return;
    }
    if (self.calledPrepare) {
        [self unlock];
        return;
    }
    self->_calledPrepare = YES;
    KTVHCLogDataSourceManager(@"%p, Call prepare", self);
    KTVHCLogDataSourceManager(@"%p, Sort sources - Begin\nSources : %@", self, self.sources);
    [self.sources sortUsingComparator:^NSComparisonResult(id <KTVHCDataSource> obj1, id <KTVHCDataSource> obj2) {
        if (obj1.range.start < obj2.range.start) {
            return NSOrderedAscending;
        }
        return NSOrderedDescending;
    }];
    KTVHCLogDataSourceManager(@"%p, Sort sources - End  \nSources : %@", self, self.sources);
    for (id <KTVHCDataSource> obj in self.sources) {
        if ([obj isKindOfClass:[KTVHCDataFileSource class]]) {
            KTVHCDataFileSource *source = (KTVHCDataFileSource *)obj;
            [source setDelegate:self delegateQueue:self.delegateQueue];
        }
        else if ([obj isKindOfClass:[KTVHCDataNetworkSource class]]) {
            KTVHCDataNetworkSource *source = (KTVHCDataNetworkSource *)obj;
            [source setDelegate:self delegateQueue:self.delegateQueue];
        }
    }
    self.currentSource = self.sources.firstObject;
    for (id<KTVHCDataSource> obj in self.sources) {
        if ([obj isKindOfClass:[KTVHCDataNetworkSource class]]) {
            self.currentNetworkSource = obj;
            break;
        }
    }
    KTVHCLogDataSourceManager(@"%p, Sort source\ncurrentSource : %@\ncurrentNetworkSource : %@", self, self.currentSource, self.currentNetworkSource);
    [self.currentSource prepare];
    [self.currentNetworkSource prepare];
    [self unlock];
}

- (void)close
{
    [self lock];
    if (self.isClosed) {
        [self unlock];
        return;
    }
    self->_closed = YES;
    KTVHCLogDataSourceManager(@"%p, Call close", self);
    for (id <KTVHCDataSource> obj in self.sources) {
        [obj close];
    }
    [self unlock];
}

- (NSData *)readDataOfLength:(NSUInteger)length
{
    [self lock];
    if (self.isClosed) {
        [self unlock];
        return nil;
    }
    if (self.isFinished) {
        [self unlock];
        return nil;
    }
    if (self.error) {
        [self unlock];
        return nil;
    }
    NSData *data = [self.currentSource readDataOfLength:length];
    self->_readedLength += data.length;
    KTVHCLogDataSourceManager(@"%p, Read data : %lld", self, (long long)data.length);
    if (self.currentSource.isFinished) {
        self.currentSource = [self nextSource];
        if (self.currentSource) {
            KTVHCLogDataSourceManager(@"%p, Switch to next source, %@", self, self.currentSource);
            if ([self.currentSource isKindOfClass:[KTVHCDataFileSource class]]) {
                [self.currentSource prepare];
            }
        } else {
            KTVHCLogDataSourceManager(@"%p, Read data did finished", self);
            self->_finished = YES;
        }
    }
    [self unlock];
    return data;
}

- (id<KTVHCDataSource>)nextSource
{
    NSUInteger index = [self.sources indexOfObject:self.currentSource] + 1;
    if (index < self.sources.count) {
        KTVHCLogDataSourceManager(@"%p, Fetch next source : %@", self, [self.sources objectAtIndex:index]);
        return [self.sources objectAtIndex:index];
    }
    KTVHCLogDataSourceManager(@"%p, Fetch netxt source failed", self);
    return nil;
}

- (KTVHCDataNetworkSource *)nextNetworkSource
{
    NSUInteger index = [self.sources indexOfObject:self.currentNetworkSource] + 1;
    for (; index < self.sources.count; index++) {
        id <KTVHCDataSource> obj = [self.sources objectAtIndex:index];
        if ([obj isKindOfClass:[KTVHCDataNetworkSource class]]) {
            KTVHCLogDataSourceManager(@"%p, Fetch next network source : %@", self, obj);
            return obj;
        }
    }
    KTVHCLogDataSourceManager(@"%p, Fetch netxt network source failed", self);
    return nil;
}

#pragma mark - KTVHCDataFileSourceDelegate

- (void)ktv_fileSourceDidPrepare:(KTVHCDataFileSource *)fileSource
{
    [self lock];
    [self callbackForPrepared];
    [self unlock];
}

- (void)ktv_fileSource:(KTVHCDataFileSource *)fileSource didFailWithError:(NSError *)error
{
    [self callbackForFailed:error];
}

#pragma mark - KTVHCDataNetworkSourceDelegate

- (void)ktv_networkSourceDidPrepare:(KTVHCDataNetworkSource *)networkSource
{
    [self lock];
    [self callbackForPrepared];
    [self callbackForReceiveResponse:networkSource.response];
    [self unlock];
}

- (void)ktv_networkSourceHasAvailableData:(KTVHCDataNetworkSource *)networkSource
{
    [self lock];
    if ([self.delegate respondsToSelector:@selector(ktv_sourceManagerHasAvailableData:)]) {
        KTVHCLogDataSourceManager(@"%p, Callback for has available data - Begin\nSource : %@", self, networkSource);
        [KTVHCDataCallback callbackWithQueue:self.delegateQueue block:^{
            KTVHCLogDataSourceManager(@"%p, Callback for has available data - End", self);
            [self.delegate ktv_sourceManagerHasAvailableData:self];
        }];
    }
    [self unlock];
}

- (void)ktv_networkSourceDidFinisheDownload:(KTVHCDataNetworkSource *)networkSource
{
    [self lock];
    self.currentNetworkSource = [self nextNetworkSource];
    [self.currentNetworkSource prepare];
    [self unlock];
}

- (void)ktv_networkSource:(KTVHCDataNetworkSource *)networkSource didFailWithError:(NSError *)error
{
    [self callbackForFailed:error];
}

#pragma mark - Callback

- (void)callbackForPrepared
{
    if (self.isClosed) {
        return;
    }
    if (self.isPrepared) {
        return;
    }
    self->_prepared = YES;
    if ([self.delegate respondsToSelector:@selector(ktv_sourceManagerDidPrepare:)]) {
        KTVHCLogDataSourceManager(@"%p, Callback for prepared - Begin", self);
        [KTVHCDataCallback callbackWithQueue:self.delegateQueue block:^{
            KTVHCLogDataSourceManager(@"%p, Callback for prepared - End", self);
            [self.delegate ktv_sourceManagerDidPrepare:self];
        }];
    }
}

- (void)callbackForReceiveResponse:(KTVHCDataResponse *)response
{
    if (self.isClosed) {
        return;
    }
    if (self.calledReceiveResponse) {
        return;
    }
    self->_calledReceiveResponse = YES;
    if ([self.delegate respondsToSelector:@selector(ktv_sourceManager:didReceiveResponse:)]) {
        KTVHCLogDataSourceManager(@"%p, Callback for did receive response - End", self);
        [KTVHCDataCallback callbackWithQueue:self.delegateQueue block:^{
            KTVHCLogDataSourceManager(@"%p, Callback for did receive response - End", self);
            [self.delegate ktv_sourceManager:self didReceiveResponse:response];
        }];
    }
}

- (void)callbackForFailed:(NSError *)error
{
    if (!error) {
        return;
    }
    [self lock];
    if (self.isClosed) {
        [self unlock];
        return;
    }
    if (self.error) {
        [self unlock];
        return;
    }
    self->_error = error;
    KTVHCLogDataSourceManager(@"failure, %d", (int)self.error.code);
    if (self.error && [self.delegate respondsToSelector:@selector(ktv_sourceManager:didFailWithError:)]) {
        KTVHCLogDataSourceManager(@"%p, Callback for network source failed - Begin\nError : %@", self, self.error);
        [KTVHCDataCallback callbackWithQueue:self.delegateQueue block:^{
            KTVHCLogDataSourceManager(@"%p, Callback for network source failed - End", self);
            [self.delegate ktv_sourceManager:self didFailWithError:self.error];
        }];
    }
    [self unlock];
}

#pragma mark - NSLocking

- (void)lock
{
    if (!self.coreLock) {
        self.coreLock = [[NSLock alloc] init];
    }
    [self.coreLock lock];
}

- (void)unlock
{
    [self.coreLock unlock];
}

@end
