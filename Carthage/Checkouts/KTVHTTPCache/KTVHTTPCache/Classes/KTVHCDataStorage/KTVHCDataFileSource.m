//
//  KTVHCDataFileSource.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCDataFileSource.h"
#import "KTVHCDataCallback.h"
#import "KTVHCError.h"
#import "KTVHCLog.h"

@interface KTVHCDataFileSource () <NSLocking>

@property (nonatomic, strong) NSError * error;
@property (nonatomic, strong) NSLock * coreLock;
@property (nonatomic, strong) NSFileHandle * readingHandle;
@property (nonatomic, assign) long long readedLength;

@end

@implementation KTVHCDataFileSource

- (instancetype)initWithPath:(NSString *)path range:(KTVHCRange)range readRange:(KTVHCRange)readRange
{
    if (self = [super init])
    {
        KTVHCLogAlloc(self);
        _path = path;
        _range = range;
        _readRange = readRange;
        KTVHCLogDataFileSource(@"%p, Create file source\npath : %@\nrange : %@\nreadRange : %@", self, path, KTVHCStringFromRange(range), KTVHCStringFromRange(readRange));
    }
    return self;
}

- (void)dealloc
{
    KTVHCLogDealloc(self);
}

- (void)prepare
{
    [self lock];
    if (self.didPrepared)
    {
        [self unlock];
        return;
    }
    KTVHCLogDataFileSource(@"%p, Call prepare", self);
    self.readingHandle = [NSFileHandle fileHandleForReadingAtPath:self.path];
    @try
    {
        [self.readingHandle seekToFileOffset:self.readRange.start];
        _didPrepared = YES;
        if ([self.delegate respondsToSelector:@selector(fileSourceDidPrepared:)])
        {
            KTVHCLogDataFileSource(@"%p, Callback for prepared - Begin", self);
            [KTVHCDataCallback callbackWithQueue:self.delegateQueue block:^{
                KTVHCLogDataFileSource(@"%p, Callback for prepared - End", self);
                [self.delegate fileSourceDidPrepared:self];
            }];
        }
    }
    @catch (NSException * exception)
    {
        KTVHCLogDataFileSource(@"%p, Seek file exception\nname : %@\nreason : %@\nuserInfo : %@", self, exception.name, exception.reason, exception.userInfo);
        NSError * error = [KTVHCError errorForException:exception];
        [self callbackForFailed:error];
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
    KTVHCLogDataFileSource(@"%p, Call close", self);
    [self destoryReadingHandle];
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
    NSData * data = nil;
    @try
    {
        long long readLength = KTVHCRangeGetLength(self.readRange);
        length = (NSUInteger)MIN(readLength - self.readedLength, length);
        data = [self.readingHandle readDataOfLength:length];
        if (data.length > 0)
        {
            self.readedLength += data.length;
            KTVHCLogDataFileSource(@"%p, Read data : %lld, %lld, %lld", self, (long long)data.length, self.readedLength, readLength);
        }
        if (self.readedLength >= readLength)
        {
            KTVHCLogDataFileSource(@"%p, Read data did finished", self);
            [self destoryReadingHandle];
            _didFinished = YES;
        }
    }
    @catch (NSException * exception)
    {
        KTVHCLogDataFileSource(@"%p, Read exception\nname : %@\nreason : %@\nuserInfo : %@", self, exception.name, exception.reason, exception.userInfo);
        NSError * error = [KTVHCError errorForException:exception];
        [self callbackForFailed:error];
    }
    [self unlock];
    return data;
}

- (void)destoryReadingHandle
{
    if (self.readingHandle)
    {
        @try
        {
            [self.readingHandle closeFile];
        }
        @catch (NSException * exception)
        {
            KTVHCLogDataFileSource(@"%p, Close exception\nname : %@\nreason : %@\nuserInfo : %@", self, exception.name, exception.reason, exception.userInfo);
        }
        self.readingHandle = nil;
    }
}

- (void)callbackForFailed:(NSError *)error
{
    if (!error)
    {
        return;
    }
    if (self.error)
    {
        return;
    }
    self.error = error;
    if ([self.delegate respondsToSelector:@selector(fileSource:didFailed:)])
    {
        KTVHCLogDataFileSource(@"%p, Callback for prepared - Begin", self);
        [KTVHCDataCallback callbackWithQueue:self.delegateQueue block:^{
            KTVHCLogDataFileSource(@"%p, Callback for prepared - End", self);
            [self.delegate fileSource:self didFailed:self.error];
        }];
    }
}

- (void)setDelegate:(id <KTVHCDataFileSourceDelegate>)delegate delegateQueue:(dispatch_queue_t)delegateQueue
{
    _delegate = delegate;
    _delegateQueue = delegateQueue;
}

- (void)lock
{
    if (!self.coreLock)
    {
        self.coreLock = [[NSLock alloc] init];
    }
    [self.coreLock lock];
}

- (void)unlock
{
    [self.coreLock unlock];
}

@end
