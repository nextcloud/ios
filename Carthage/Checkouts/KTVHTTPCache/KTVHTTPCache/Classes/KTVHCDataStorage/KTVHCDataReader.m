//
//  KTVHCDataReader.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCDataReader.h"
#import "KTVHCDataSourceManager.h"
#import "KTVHCDataUnitPool.h"
#import "KTVHCDataCallback.h"
#import "KTVHCLog.h"

@interface KTVHCDataReader () <KTVHCDataSourceManagerDelegate>

@property (nonatomic, strong) NSRecursiveLock * coreLock;
@property (nonatomic, strong) dispatch_queue_t delegateQueue;
@property (nonatomic, strong) dispatch_queue_t internalDelegateQueue;
@property (nonatomic, assign) BOOL didCalledPrepare;

@property (nonatomic, strong) KTVHCDataUnit * unit;
@property (nonatomic, strong) KTVHCDataSourceManager * sourceManager;

@end

@implementation KTVHCDataReader

+ (instancetype)readerWithRequest:(KTVHCDataRequest *)request
{
    return [[self alloc] initWithRequest:request];
}

- (instancetype)initWithRequest:(KTVHCDataRequest *)request
{
    if (self = [super init])
    {
        KTVHCLogAlloc(self);
        self.unit = [[KTVHCDataUnitPool pool] unitWithURL:request.URL];
        _request = [request requestWithTotalLength:self.unit.totalLength];
        [self.unit updateRequestHeaders:self.request.headers];
        self.delegateQueue = dispatch_queue_create("KTVHCDataReader_delegateQueue", DISPATCH_QUEUE_SERIAL);
        self.internalDelegateQueue = dispatch_queue_create("KTVHCDataReader_internalDelegateQueue", DISPATCH_QUEUE_SERIAL);
        KTVHCLogDataReader(@"%p, Create reader\norignalRequest : %@\nfinalRequest : %@\nUnit : %@", self, request, self.request, self.unit);
    }
    return self;
}

- (void)dealloc
{
    KTVHCLogDealloc(self);
    [self close];
    KTVHCLogDataReader(@"%p, Destory reader\nError : %@\nreadOffset : %lld", self, self.error, self.readOffset);
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
    KTVHCLogDataReader(@"%p, Call prepare", self);
    [self prepareSourceManager];
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
    KTVHCLogDataReader(@"%p, Call close", self);
    [self.sourceManager close];
    [self.unit workingRelease];
    self.unit = nil;
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
    NSData * data = [self.sourceManager readDataOfLength:length];;
    _readOffset += data.length;
    KTVHCLogDataReader(@"%p, Read data : %lld", self, (long long)data.length);
    if (self.sourceManager.didFinished)
    {
        KTVHCLogDataReader(@"%p, Read data did finished", self);
        _didFinished = YES;
        [self close];
    }
    [self unlock];
    return data;
}

- (void)prepareSourceManager
{
    self.sourceManager = [[KTVHCDataSourceManager alloc] initWithDelegate:self delegateQueue:self.internalDelegateQueue];
    NSMutableArray <KTVHCDataFileSource *> * fileSources = [NSMutableArray array];
    NSMutableArray <KTVHCDataNetworkSource *> * networkSources = [NSMutableArray array];
    long long min = self.request.range.start;
    long long max = self.request.range.end;
    NSArray * unitItems = self.unit.unitItems;
    for (KTVHCDataUnitItem * item in unitItems)
    {
        long long itemMin = item.offset;
        long long itemMax = item.offset + item.length - 1;
        if (itemMax < min || itemMin > max)
        {
            continue;
        }
        if (min > itemMin)
        {
            itemMin = min;
        }
        if (max < itemMax)
        {
            itemMax = max;
        }
        min = itemMax + 1;
        KTVHCRange range = KTVHCMakeRange(item.offset, item.offset + item.length - 1);
        KTVHCRange readRange = KTVHCMakeRange(itemMin - item.offset, itemMax - item.offset);
        KTVHCDataFileSource * source = [[KTVHCDataFileSource alloc] initWithPath:item.absolutePath range:range readRange:readRange];
        [fileSources addObject:source];
    }
    [fileSources sortUsingComparator:^NSComparisonResult(KTVHCDataFileSource * obj1, KTVHCDataFileSource * obj2) {
        if (obj1.range.start < obj2.range.start) {
            return NSOrderedAscending;
        }
        return NSOrderedDescending;
    }];
    long long offset = self.request.range.start;
    long long length = KTVHCRangeIsFull(self.request.range) ? KTVHCRangeGetLength(self.request.range) : (self.request.range.end - offset + 1);
    for (KTVHCDataFileSource * obj in fileSources)
    {
        long long delta = obj.range.start + obj.readRange.start - offset;
        if (delta > 0)
        {
            KTVHCRange range = KTVHCMakeRange(offset, offset + delta - 1);
            KTVHCDataRequest * request = [self.request requestWithRange:range];
            KTVHCDataNetworkSource * source = [[KTVHCDataNetworkSource alloc] initWithRequest:request];
            [networkSources addObject:source];
            offset += delta;
            length -= delta;
        }
        offset += KTVHCRangeGetLength(obj.readRange);
        length -= KTVHCRangeGetLength(obj.readRange);
    }
    if (length > 0)
    {
        KTVHCRange range = KTVHCMakeRange(offset, self.request.range.end);
        KTVHCDataRequest * request = [self.request requestWithRange:range];
        KTVHCDataNetworkSource * source = [[KTVHCDataNetworkSource alloc] initWithRequest:request];
        [networkSources addObject:source];
    }
    for (KTVHCDataFileSource * obj in fileSources)
    {
        [self.sourceManager putSource:obj];
    }
    for (KTVHCDataNetworkSource * obj in networkSources)
    {
        [self.sourceManager putSource:obj];
    }
    [self.sourceManager prepare];
}

- (void)sourceManagerDidPrepared:(KTVHCDataSourceManager *)sourceManager
{
    [self lock];
    [self callbackForPrepared];
    [self unlock];
}

- (void)sourceManager:(KTVHCDataSourceManager *)sourceManager didReceiveResponse:(KTVHCDataResponse *)response
{
    [self lock];
    [self.unit updateResponseHeaders:response.headers totalLength:response.totalLength];
    [self callbackForPrepared];
    [self unlock];
}

- (void)sourceManagerHasAvailableData:(KTVHCDataSourceManager *)sourceManager
{
    [self lock];
    if (self.didClosed)
    {
        [self unlock];
        return;
    }
    if ([self.delegate respondsToSelector:@selector(readerHasAvailableData:)])
    {
        KTVHCLogDataReader(@"%p, Callback for has available data - Begin", self);
        [KTVHCDataCallback callbackWithQueue:self.delegateQueue block:^{
            KTVHCLogDataReader(@"%p, Callback for has available data - End", self);
            [self.delegate readerHasAvailableData:self];
        }];
    }
    [self unlock];
}

- (void)sourceManager:(KTVHCDataSourceManager *)sourceManager didFailed:(NSError *)error
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
    [self close];
    [[KTVHCLog log] addError:self.error];
    if ([self.delegate respondsToSelector:@selector(reader:didFailed:)])
    {
        KTVHCLogDataReader(@"%p, Callback for failed - Begin\nError : %@", self, self.error);
        [KTVHCDataCallback callbackWithQueue:self.delegateQueue block:^{
            KTVHCLogDataReader(@"%p, Callback for failed - End", self);
            [self.delegate reader:self didFailed:self.error];
        }];
    }
    [self unlock];
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
    if (self.sourceManager.didPrepared && self.unit.totalLength > 0)
    {
        long long totalLength = self.unit.totalLength;
        KTVHCRange range = KTVHCRangeWithEnsureLength(self.request.range, totalLength);
        NSDictionary * headers = KTVHCRangeFillToResponseHeaders(range, self.unit.responseHeaders, totalLength);
        _response = [[KTVHCDataResponse alloc] initWithURL:self.request.URL headers:headers];
        _didPrepared = YES;
        KTVHCLogDataReader(@"%p, Reader did prepared\nResponse : %@", self, self.response);
        if ([self.delegate respondsToSelector:@selector(readerDidPrepared:)])
        {
            KTVHCLogDataReader(@"%p, Callback for prepared - Begin", self);
            [KTVHCDataCallback callbackWithQueue:self.delegateQueue block:^{
                KTVHCLogDataReader(@"%p, Callback for prepared - End", self);
                [self.delegate readerDidPrepared:self];
            }];
        }
    }
}

- (void)lock
{
    if (!self.coreLock)
    {
        self.coreLock = [[NSRecursiveLock alloc] init];
    }
    [self.coreLock lock];
}

- (void)unlock
{
    [self.coreLock unlock];
}

@end
