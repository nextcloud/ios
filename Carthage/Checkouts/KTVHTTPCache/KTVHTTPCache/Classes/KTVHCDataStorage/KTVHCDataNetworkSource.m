//
//  KTVHCDataNetworkSource.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCDataNetworkSource.h"
#import "KTVHCDataUnitPool.h"
#import "KTVHCDataCallback.h"
#import "KTVHCPathTool.h"
#import "KTVHCDownload.h"
#import "KTVHCError.h"
#import "KTVHCLog.h"

@interface KTVHCDataNetworkSource () <NSLocking, KTVHCDownloadDelegate>

@property (nonatomic, strong) NSLock *coreLock;
@property (nonatomic, strong) NSFileHandle *readingHandle;
@property (nonatomic, strong) NSFileHandle *writingHandle;
@property (nonatomic, strong) KTVHCDataUnitItem *unitItem;
@property (nonatomic, strong) NSURLSessionTask *downlaodTask;

@property (nonatomic) long long downloadLength;
@property (nonatomic) BOOL downloadCalledComplete;
@property (nonatomic) BOOL callHasAvailableData;
@property (nonatomic) BOOL calledPrepare;

@end

@implementation KTVHCDataNetworkSource

@synthesize error = _error;
@synthesize range = _range;
@synthesize closed = _closed;
@synthesize prepared = _prepared;
@synthesize finished = _finished;
@synthesize readedLength = _readedLength;

- (instancetype)initWithRequest:(KTVHCDataRequest *)reqeust
{
    if (self = [super init])
    {
        KTVHCLogAlloc(self);
        self->_request = reqeust;
        self->_range = reqeust.range;
        KTVHCLogDataNetworkSource(@"%p, Create network source\nrequest : %@\nrange : %@", self, self.request, KTVHCStringFromRange(self.range));
    }
    return self;
}

- (void)dealloc
{
    KTVHCLogDealloc(self);
    KTVHCLogDataNetworkSource(@"%p, Destory network source\nError : %@\ndownloadLength : %lld\nreadedLength : %lld", self, self.error, self.downloadLength, self.readedLength);
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
    KTVHCLogDataNetworkSource(@"%p, Call prepare", self);
    self.downlaodTask = [[KTVHCDownload download] downloadWithRequest:self.request delegate:self];
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
    KTVHCLogDataNetworkSource(@"%p, Call close", self);
    if (!self.downloadCalledComplete) {
        KTVHCLogDataNetworkSource(@"%p, Cancel download task", self);
        [self.downlaodTask cancel];
        self.downlaodTask = nil;
    }
    [self destoryReadingHandle];
    [self destoryWritingHandle];
    [self unlock];
}

- (NSData *)readDataOfLength:(NSUInteger)length
{
    [self lock];
    if (self.isClosed || self.isFinished || self.error) {
        [self unlock];
        return nil;
    }
    if (self.readedLength >= self.downloadLength) {
        if (self.downloadCalledComplete) {
            KTVHCLogDataNetworkSource(@"%p, Read data failed\ndownloadLength : %lld\nreadedLength : %lld", self, self.readedLength, self.downloadLength);
            [self destoryReadingHandle];
        } else {
            KTVHCLogDataNetworkSource(@"%p, Read data wait callback", self);
            self.callHasAvailableData = YES;
        }
        [self unlock];
        return nil;
    }
    NSData *data = nil;
    @try {
        data = [self.readingHandle readDataOfLength:(NSUInteger)MIN(self.downloadLength - self.readedLength, length)];
        self->_readedLength += data.length;
        KTVHCLogDataNetworkSource(@"%p, Read data\nLength : %lld\ndownloadLength : %lld\nreadedLength : %lld", self, (long long)data.length, self.readedLength, self.downloadLength);
        if (self.readedLength >= KTVHCRangeGetLength(self.response.contentRange)) {
            self->_finished = YES;
            KTVHCLogDataNetworkSource(@"%p, Read data did finished", self);
            [self destoryReadingHandle];
        }
    } @catch (NSException *exception) {
        KTVHCLogDataFileSource(@"%p, Read exception\nname : %@\nreason : %@\nuserInfo : %@", self, exception.name, exception.reason, exception.userInfo);
        NSError *error = [KTVHCError errorForException:exception];
        [self callbackForFailed:error];
    }
    [self unlock];
    return data;
}

- (void)setDelegate:(id <KTVHCDataNetworkSourceDelegate>)delegate delegateQueue:(dispatch_queue_t)delegateQueue
{
    self->_delegate = delegate;
    self->_delegateQueue = delegateQueue;
}

- (void)ktv_download:(KTVHCDownload *)download didCompleteWithError:(NSError *)error
{
    [self lock];
    self.downloadCalledComplete = YES;
    [self destoryWritingHandle];
    if (self.isClosed) {
        KTVHCLogDataNetworkSource(@"%p, Complete but did closed\nError : %@", self, error);
    } else if (self.error) {
        KTVHCLogDataNetworkSource(@"%p, Complete but did failed\nself.error : %@\nerror : %@", self, self.error, error);
    } else if (error) {
        if (error.code != NSURLErrorCancelled) {
            [self callbackForFailed:error];
        } else {
            KTVHCLogDataNetworkSource(@"%p, Complete with cancel\nError : %@", self, error);
        }
    } else if (self.downloadLength >= KTVHCRangeGetLength(self.response.contentRange)) {
        KTVHCLogDataNetworkSource(@"%p, Complete and finisehed", self);
        if ([self.delegate respondsToSelector:@selector(ktv_networkSourceDidFinisheDownload:)]) {
            [KTVHCDataCallback callbackWithQueue:self.delegateQueue block:^{
                [self.delegate ktv_networkSourceDidFinisheDownload:self];
            }];
        }
    } else {
        KTVHCLogDataNetworkSource(@"%p, Complete but not finisehed\ndownloadLength : %lld", self, self.downloadLength);
    }
    [self unlock];
}

- (void)ktv_download:(KTVHCDownload *)download didReceiveResponse:(KTVHCDataResponse *)response
{
    [self lock];
    if (self.isClosed || self.error) {
        [self unlock];
        return;
    }
    self->_response = response;
    NSString *path = [KTVHCPathTool filePathWithURL:self.request.URL offset:self.request.range.start];
    self.unitItem = [[KTVHCDataUnitItem alloc] initWithPath:path offset:self.request.range.start];
    KTVHCDataUnit *unit = [[KTVHCDataUnitPool pool] unitWithURL:self.request.URL];
    [unit insertUnitItem:self.unitItem];
    KTVHCLogDataNetworkSource(@"%p, Receive response\nResponse : %@\nUnit : %@\nUnitItem : %@", self, response, unit, self.unitItem);
    [unit workingRelease];
    self.writingHandle = [NSFileHandle fileHandleForWritingAtPath:self.unitItem.absolutePath];
    self.readingHandle = [NSFileHandle fileHandleForReadingAtPath:self.unitItem.absolutePath];
    [self callbackForPrepared];
    [self unlock];
}

- (void)ktv_download:(KTVHCDownload *)download didReceiveData:(NSData *)data
{
    [self lock];
    if (self.isClosed || self.error) {
        [self unlock];
        return;
    }
    @try {
        [self.writingHandle writeData:data];
        self.downloadLength += data.length;
        [self.unitItem updateLength:self.downloadLength];
        KTVHCLogDataNetworkSource(@"%p, Receive data : %lld, %lld, %lld", self, (long long)data.length, self.downloadLength, self.unitItem.length);
        [self callbackForHasAvailableData];
    } @catch (NSException *exception) {
        NSError *error = [KTVHCError errorForException:exception];
        KTVHCLogDataNetworkSource(@"%p, write exception\nError : %@", self, error);
        [self callbackForFailed:error];
        if (!self.downloadCalledComplete) {
            KTVHCLogDataNetworkSource(@"%p, Cancel download task when write exception", self);
            [self.downlaodTask cancel];
            self.downlaodTask = nil;
        }
    }
    [self unlock];
}

- (void)destoryReadingHandle
{
    if (self.readingHandle) {
        @try {
            [self.readingHandle closeFile];
        } @catch (NSException *exception) {
            KTVHCLogDataFileSource(@"%p, Close reading handle exception\nname : %@\nreason : %@\nuserInfo : %@", self, exception.name, exception.reason, exception.userInfo);
        }
        self.readingHandle = nil;
    }
}

- (void)destoryWritingHandle
{
    if (self.writingHandle) {
        @try {
            [self.writingHandle synchronizeFile];
            [self.writingHandle closeFile];
        } @catch (NSException *exception) {
            KTVHCLogDataFileSource(@"%p, Close writing handle exception\nname : %@\nreason : %@\nuserInfo : %@", self, exception.name, exception.reason, exception.userInfo);
        }
        self.writingHandle = nil;
    }
}

- (void)callbackForPrepared
{
    if (self.isClosed) {
        return;
    }
    if (self.isPrepared) {
        return;
    }
    self->_prepared = YES;
    if ([self.delegate respondsToSelector:@selector(ktv_networkSourceDidPrepare:)]) {
        KTVHCLogDataNetworkSource(@"%p, Callback for prepared - Begin", self);
        [KTVHCDataCallback callbackWithQueue:self.delegateQueue block:^{
            KTVHCLogDataNetworkSource(@"%p, Callback for prepared - End", self);
            [self.delegate ktv_networkSourceDidPrepare:self];
        }];
    }
}

- (void)callbackForHasAvailableData
{
    if (self.isClosed) {
        return;
    }
    if (!self.callHasAvailableData) {
        return;
    }
    self.callHasAvailableData = NO;
    if ([self.delegate respondsToSelector:@selector(ktv_networkSourceHasAvailableData:)]) {
        KTVHCLogDataNetworkSource(@"%p, Callback for has available data - Begin", self);
        [KTVHCDataCallback callbackWithQueue:self.delegateQueue block:^{
            KTVHCLogDataNetworkSource(@"%p, Callback for has available data - End", self);
            [self.delegate ktv_networkSourceHasAvailableData:self];
        }];
    }
}

- (void)callbackForFailed:(NSError *)error
{
    if (self.isClosed || !error || self.error) {
        return;
    }
    self->_error = error;
    KTVHCLogDataNetworkSource(@"%p, Callback for failed\nError : %@", self, self.error);
    if ([self.delegate respondsToSelector:@selector(ktv_networkSource:didFailWithError:)]) {
        [KTVHCDataCallback callbackWithQueue:self.delegateQueue block:^{
            [self.delegate ktv_networkSource:self didFailWithError:self.error];
        }];
    }
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
