//
//  KTVHCDataSourceManager.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCDataSourceManager.h"
#import "KTVHCDataSourceQueue.h"
#import "KTVHCDataCallback.h"
#import "KTVHCLog.h"

@interface KTVHCDataSourceManager () <NSLocking, KTVHCDataFileSourceDelegate, KTVHCDataNetworkSourceDelegate>

@property (nonatomic, strong) NSLock * coreLock;
@property (nonatomic, assign) BOOL didCalledPrepare;
@property (nonatomic, assign) BOOL didCalledReceiveResponse;

@property (nonatomic, strong) KTVHCDataSourceQueue * sourceQueue;
@property (nonatomic, strong) id <KTVHCDataSourceProtocol> currentSource;
@property (nonatomic, strong) KTVHCDataNetworkSource * currentNetworkSource;

@end

@implementation KTVHCDataSourceManager

- (instancetype)initWithDelegate:(id <KTVHCDataSourceManagerDelegate>)delegate delegateQueue:(dispatch_queue_t)delegateQueue
{
    if (self = [super init])
    {
        KTVHCLogAlloc(self);
        _delegate = delegate;
        _delegateQueue = delegateQueue;
        self.sourceQueue = [KTVHCDataSourceQueue sourceQueue];
    }
    return self;
}

- (void)dealloc
{
    KTVHCLogDealloc(self);
    KTVHCLogDataReader(@"%p, Destory reader\nError : %@\ncurrentSource : %@\ncurrentNetworkSource : %@", self, self.error, self.currentSource, self.currentNetworkSource);
}

- (void)putSource:(id<KTVHCDataSourceProtocol>)source
{
    KTVHCLogDataSourceManager(@"%p, Put source : %@", self, source);
    [self.sourceQueue putSource:source];
}

- (void)prepare
{
    [self lock];
    if (self.didClosed)
    {
        [self unlock];
        return;
    }
    if (self.didCalledPrepare)
    {
        [self unlock];
        return;
    }
    _didCalledPrepare = YES;
    KTVHCLogDataSourceManager(@"%p, Call prepare", self);
    [self.sourceQueue sortSources];
    [self.sourceQueue setAllSourceDelegate:self delegateQueue:self.delegateQueue];
    self.currentSource = [self.sourceQueue firstSource];
    self.currentNetworkSource = [self.sourceQueue firstNetworkSource];
    KTVHCLogDataSourceManager(@"%p, Sort source\ncurrentSource : %@\ncurrentNetworkSource : %@", self, self.currentSource, self.currentNetworkSource);
    [self.currentSource prepare];
    if (self.currentSource != self.currentNetworkSource)
    {
        [self.currentNetworkSource prepare];
    }
    [self unlock];
}

- (void)close
{
    [self lock];
    if (self.didClosed)
    {
        [self unlock];
        return;
    }
    _didClosed = YES;
    KTVHCLogDataSourceManager(@"%p, Call close", self);
    [self.sourceQueue closeAllSource];
    [self unlock];
}

- (NSData *)readDataOfLength:(NSUInteger)length
{
    [self lock];
    if (self.didClosed)
    {
        [self unlock];
        return nil;
    }
    if (self.didFinished)
    {
        [self unlock];
        return nil;
    }
    if (self.error)
    {
        [self unlock];
        return nil;
    }
    NSData * data = [self.currentSource readDataOfLength:length];
    KTVHCLogDataSourceManager(@"%p, Read data : %lld", self, (long long)data.length);
    if (self.currentSource.didFinished)
    {
        self.currentSource = [self.sourceQueue nextSource:self.currentSource];
        if (self.currentSource)
        {
            KTVHCLogDataSourceManager(@"%p, Switch to next source, %@", self, self.currentSource);
            if ([self.currentSource isKindOfClass:[KTVHCDataFileSource class]])
            {
                [self.currentSource prepare];
            }
        }
        else
        {
            KTVHCLogDataSourceManager(@"%p, Read data did finished", self);
            _didFinished = YES;
        }
    }
    [self unlock];
    return data;
}

- (void)fileSourceDidPrepared:(KTVHCDataFileSource *)fileSource
{
    [self lock];
    [self callbackForPrepared];
    [self unlock];
}

- (void)fileSource:(KTVHCDataFileSource *)fileSource didFailed:(NSError *)error
{
    [self callbackForFailed:error];
}

- (void)networkSourceDidPrepared:(KTVHCDataNetworkSource *)networkSource
{
    [self lock];
    [self callbackForPrepared];
    [self callbackForReceiveResponse:networkSource.response];
    [self unlock];
}

- (void)networkSourceHasAvailableData:(KTVHCDataNetworkSource *)networkSource
{
    [self lock];
    if ([self.delegate respondsToSelector:@selector(sourceManagerHasAvailableData:)])
    {
        KTVHCLogDataSourceManager(@"%p, Callback for has available data - Begin\nSource : %@", self, networkSource);
        [KTVHCDataCallback callbackWithQueue:self.delegateQueue block:^{
            KTVHCLogDataSourceManager(@"%p, Callback for has available data - End", self);
            [self.delegate sourceManagerHasAvailableData:self];
        }];
    }
    [self unlock];
}

- (void)networkSourceDidFinishedDownload:(KTVHCDataNetworkSource *)networkSource
{
    [self lock];
    self.currentNetworkSource = [self.sourceQueue nextNetworkSource:self.currentNetworkSource];
    [self.currentNetworkSource prepare];
    [self unlock];
}

- (void)networkSource:(KTVHCDataNetworkSource *)networkSource didFailed:(NSError *)error
{
    [self callbackForFailed:error];
}

- (void)callbackForPrepared
{
    if (self.didClosed)
    {
        return;
    }
    if (self.didPrepared)
    {
        return;
    }
    _didPrepared = YES;
    if ([self.delegate respondsToSelector:@selector(sourceManagerDidPrepared:)])
    {
        KTVHCLogDataSourceManager(@"%p, Callback for prepared - Begin", self);
        [KTVHCDataCallback callbackWithQueue:self.delegateQueue block:^{
            KTVHCLogDataSourceManager(@"%p, Callback for prepared - End", self);
            [self.delegate sourceManagerDidPrepared:self];
        }];
    }
}

- (void)callbackForReceiveResponse:(KTVHCDataResponse *)response
{
    if (self.didClosed)
    {
        return;
    }
    if (self.didCalledReceiveResponse)
    {
        return;
    }
    _didCalledReceiveResponse = YES;
    if ([self.delegate respondsToSelector:@selector(sourceManager:didReceiveResponse:)])
    {
        KTVHCLogDataSourceManager(@"%p, Callback for did receive response - End", self);
        [KTVHCDataCallback callbackWithQueue:self.delegateQueue block:^{
            KTVHCLogDataSourceManager(@"%p, Callback for did receive response - End", self);
            [self.delegate sourceManager:self didReceiveResponse:response];
        }];
    }
}

- (void)callbackForFailed:(NSError *)error
{
    if (!error)
    {
        return;
    }
    [self lock];
    if (self.didClosed)
    {
        [self unlock];
        return;
    }
    if (self.error)
    {
        [self unlock];
        return;
    }
    _error = error;
    KTVHCLogDataSourceManager(@"failure, %d", (int)self.error.code);
    if (self.error && [self.delegate respondsToSelector:@selector(sourceManager:didFailed:)])
    {
        KTVHCLogDataSourceManager(@"%p, Callback for network source failed - Begin\nError : %@", self, self.error);
        [KTVHCDataCallback callbackWithQueue:self.delegateQueue block:^{
            KTVHCLogDataSourceManager(@"%p, Callback for network source failed - End", self);
            [self.delegate sourceManager:self didFailed:self.error];
        }];
    }
    [self unlock];
}

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
