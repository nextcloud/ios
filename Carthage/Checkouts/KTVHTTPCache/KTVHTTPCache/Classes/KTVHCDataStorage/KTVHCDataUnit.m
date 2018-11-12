//
//  KTVHCDataUnit.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCDataUnit.h"
#import "KTVHCURLTools.h"
#import "KTVHCPathTools.h"
#import "KTVHCLog.h"

@interface KTVHCDataUnit ()

@property (nonatomic, strong) NSRecursiveLock * coreLock;
@property (nonatomic, strong) NSMutableArray <KTVHCDataUnitItem *> * unitItemsInternal;
@property (nonatomic, strong) NSMutableArray <NSArray <KTVHCDataUnitItem *> *> * lockingUnitItems;

@end

@implementation KTVHCDataUnit

+ (instancetype)unitWithURL:(NSURL *)URL
{
    return [[self alloc] initWithURL:URL];
}

- (instancetype)initWithURL:(NSURL *)URL
{
    if (self = [super init])
    {
        KTVHCLogAlloc(self);
        _URL = URL;
        _key = [KTVHCURLTools keyWithURL:self.URL];
        _createTimeInterval = [NSDate date].timeIntervalSince1970;
        _valid = YES;
        [self prepare];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super init])
    {
        KTVHCLogAlloc(self);
        @try {
            _URL = [NSURL URLWithString:[aDecoder decodeObjectForKey:@"URLString"]];
            _key = [aDecoder decodeObjectForKey:@"uniqueIdentifier"];
            _valid = YES;
        } @catch (NSException * exception) {
            _valid = NO;
        }
        @try {
            _createTimeInterval = [[aDecoder decodeObjectForKey:@"createTimeInterval"] doubleValue];
            _requestHeaders = [aDecoder decodeObjectForKey:@"requestHeaderFields"];
            _responseHeaders = [aDecoder decodeObjectForKey:@"responseHeaderFields"];
            _totalLength = [[aDecoder decodeObjectForKey:@"totalContentLength"] longLongValue];
            self.unitItemsInternal = [aDecoder decodeObjectForKey:@"unitItems"];
            [self prepare];
            _valid = _valid && YES;
        } @catch (NSException * exception) {
            _valid = NO;
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [self lock];
    [aCoder encodeObject:self.URL.absoluteString forKey:@"URLString"];
    [aCoder encodeObject:self.key forKey:@"uniqueIdentifier"];
    [aCoder encodeObject:@(self.createTimeInterval) forKey:@"createTimeInterval"];
    [aCoder encodeObject:self.requestHeaders forKey:@"requestHeaderFields"];
    [aCoder encodeObject:self.responseHeaders forKey:@"responseHeaderFields"];
    [aCoder encodeObject:@(self.totalLength) forKey:@"totalContentLength"];
    [aCoder encodeObject:self.unitItemsInternal forKey:@"unitItems"];
    [self unlock];
}

- (void)dealloc
{
    KTVHCLogDealloc(self);
}

- (void)prepare
{
    [self lock];
    if (!self.unitItemsInternal)
    {
        self.unitItemsInternal = [NSMutableArray array];
    }
    if (self.unitItemsInternal.count > 0)
    {
        NSMutableArray * removeArray = [NSMutableArray array];
        for (KTVHCDataUnitItem * obj in self.unitItemsInternal)
        {
            if (obj.length <= 0)
            {
                [KTVHCPathTools deleteFileAtPath:obj.absolutePath];
                [removeArray addObject:obj];
            }
        }
        [self.unitItemsInternal removeObjectsInArray:removeArray];
        [removeArray removeAllObjects];
        [self sortUnitItems];
    }
    KTVHCLogDataUnit(@"%p, Create Unit\nURL : %@\nkey : %@\ntimeInterval : %@\ntotalLength : %lld\ncacheLength : %lld\nvaildLength : %lld\nrequestHeaders : %@\nresponseHeaders : %@\nunitItems : %@", self, self.URL, self.key, [NSDate dateWithTimeIntervalSince1970:self.createTimeInterval], self.totalLength, self.cacheLength, self.validLength, self.requestHeaders, self.responseHeaders, self.unitItemsInternal);
    [self unlock];
}

- (void)sortUnitItems
{
    [self lock];
    KTVHCLogDataSourceQueue(@"%p, Sort unitItems - Begin\n%@", self, self.unitItemsInternal);
    [self.unitItemsInternal sortUsingComparator:^NSComparisonResult(KTVHCDataUnitItem * obj1, KTVHCDataUnitItem * obj2) {
        NSComparisonResult result = NSOrderedDescending;
        if (obj1.offset < obj2.offset)
        {
            result = NSOrderedAscending;
        }
        else if ((obj1.offset == obj2.offset) && (obj1.length > obj2.length))
        {
            result = NSOrderedAscending;
        }
        return result;
    }];
    KTVHCLogDataSourceQueue(@"%p, Sort unitItems - End  \n%@", self, self.unitItemsInternal);
    [self unlock];
}

- (NSArray <KTVHCDataUnitItem *> *)unitItems
{
    [self lock];
    NSMutableArray * objs = [NSMutableArray array];
    for (KTVHCDataUnitItem * obj in self.unitItemsInternal)
    {
        [objs addObject:[obj copy]];
    }
    KTVHCLogDataSourceQueue(@"%p, Get unitItems\n%@", self, self.unitItemsInternal);
    [self unlock];
    return [objs copy];
}

- (void)insertUnitItem:(KTVHCDataUnitItem *)unitItem
{
    [self lock];
    [self.unitItemsInternal addObject:unitItem];
    [self sortUnitItems];
    KTVHCLogDataUnit(@"%p, Insert unitItem, %@", self, unitItem);
    [self unlock];
    [self.fileDelegate unitShouldRearchive:self];
}

- (void)updateRequestHeaders:(NSDictionary *)requestHeaders
{
    [self lock];
    _requestHeaders = requestHeaders;
    KTVHCLogDataUnit(@"%p, Update requestHeaders\n%@", self, self.requestHeaders);
    [self unlock];
    [self.fileDelegate unitShouldRearchive:self];
}

- (void)updateResponseHeaders:(NSDictionary *)responseHeaders totalLength:(long long)totalLength
{
    [self lock];
    _responseHeaders = responseHeaders;
    _totalLength = totalLength;
    KTVHCLogDataUnit(@"%p, Update responseHeaders\ntotalLength : %lld\n%@", self, self.totalLength, self.responseHeaders);
    [self unlock];
    [self.fileDelegate unitShouldRearchive:self];
}

- (NSURL *)fileURL
{
    [self lock];
    NSURL * fileURL = nil;
    KTVHCDataUnitItem * item = self.unitItemsInternal.firstObject;
    if (item.offset == 0 && item.length > 0 && item.length == self.totalLength)
    {
        fileURL = [NSURL fileURLWithPath:item.absolutePath];
        KTVHCLogDataUnit(@"%p, Get file path\n%@", self, fileURL);
    }
    [self unlock];
    return fileURL;
}

- (long long)cacheLength
{
    [self lock];
    long long length = 0;
    for (KTVHCDataUnitItem * obj in self.unitItemsInternal)
    {
        length += obj.length;
    }
    [self unlock];
    return length;
}

- (long long)validLength
{
    [self lock];
    long long offset = 0;
    long long length = 0;
    for (KTVHCDataUnitItem * obj in self.unitItemsInternal)
    {
        long long invalidLength = MAX(offset - obj.offset, 0);
        long long vaildLength = MAX(obj.length - invalidLength, 0);
        offset = MAX(offset, obj.offset + obj.length);
        length += vaildLength;
    }
    [self unlock];
    return length;
}

- (NSTimeInterval)lastItemCreateInterval
{
    [self lock];
    NSTimeInterval timeInterval = self.createTimeInterval;
    for (KTVHCDataUnitItem * obj in self.unitItemsInternal)
    {
        if (obj.createTimeInterval > timeInterval)
        {
            timeInterval = obj.createTimeInterval;
        }
    }
    [self unlock];
    return timeInterval;
}

- (void)workingRetain
{
    [self lock];
    _workingCount++;
    KTVHCLogDataUnit(@"%p, Working retain  : %ld", self, (long)self.workingCount);
    [self unlock];
}

- (void)workingRelease
{
    BOOL mergeSuccess = NO;
    [self lock];
    _workingCount--;
    KTVHCLogDataUnit(@"%p, Working release : %ld", self, (long)self.workingCount);
    if (self.workingCount <= 0)
    {
        mergeSuccess = [self mergeFilesIfNeeded];
    }
    [self unlock];
    if (mergeSuccess)
    {
        [self.fileDelegate unitShouldRearchive:self];
    }
}

- (void)deleteFiles
{
    if (!self.URL)
    {
        return;
    }
    [self lock];
    NSString * path = [KTVHCPathTools directoryPathWithURL:self.URL];
    [KTVHCPathTools deleteDirectoryAtPath:path];
    KTVHCLogDataUnit(@"%p, Delete files", self);
    [self unlock];
}

- (BOOL)mergeFilesIfNeeded
{
    [self lock];
    if (self.workingCount > 0 || self.totalLength <= 0 || self.unitItemsInternal.count <= 0)
    {
        [self unlock];
        return NO;
    }
    NSString * path = [KTVHCPathTools completeFilePathWithURL:self.URL];
    if ([self.unitItemsInternal.firstObject.absolutePath isEqualToString:path])
    {
        [self unlock];
        return NO;
    }
    if (self.totalLength != self.validLength)
    {
        [self unlock];
        return NO;
    }
    BOOL failed = NO;
    long long offset = 0;
    [KTVHCPathTools deleteFileAtPath:path];
    [KTVHCPathTools createFileAtPath:path];
    NSFileHandle * writingHandle = [NSFileHandle fileHandleForWritingAtPath:path];
    for (KTVHCDataUnitItem * obj in self.unitItemsInternal)
    {
        if (failed)
        {
            break;
        }
        NSAssert(offset >= obj.offset, @"invaild unit item.");
        if (offset >= (obj.offset + obj.length))
        {
            KTVHCLogDataUnit(@"%p, Merge files continue", self);
            continue;
        }
        NSFileHandle * readingHandle = [NSFileHandle fileHandleForReadingAtPath:obj.absolutePath];
        @try
        {
            [readingHandle seekToFileOffset:offset - obj.offset];
        }
        @catch (NSException * exception)
        {
            KTVHCLogDataUnit(@"%p, Merge files seek exception\n%@", self, exception);
            failed = YES;
        }
        if (failed)
        {
            break;
        }
        while (!failed)
        {
            @autoreleasepool
            {
                NSData * data = [readingHandle readDataOfLength:1024 * 1024 * 1];
                if (data.length <= 0)
                {
                    KTVHCLogDataUnit(@"%p, Merge files break", self);
                    break;
                }
                KTVHCLogDataUnit(@"%p, Merge write data : %lld", self, (long long)data.length);
                @try
                {
                    [writingHandle writeData:data];
                }
                @catch (NSException * exception)
                {
                    KTVHCLogDataUnit(@"%p, Merge files write exception\n%@", self, exception);
                    failed = YES;
                }
            }
        }
        [readingHandle closeFile];
        offset = obj.offset + obj.length;
        KTVHCLogDataUnit(@"%p, Merge next : %lld", self, offset);
    }
    @try
    {
        [writingHandle synchronizeFile];
        [writingHandle closeFile];
    }
    @catch (NSException * exception)
    {
        KTVHCLogDataUnit(@"%p, Merge files close exception, %d\n%@", self, failed, exception);
        failed = YES;
    }
    KTVHCLogDataUnit(@"%p, Merge finished\ntotalLength : %lld\noffset : %lld", self, self.totalLength, offset);
    if (failed || [KTVHCPathTools sizeOfItemAtPath:path] != self.totalLength)
    {
        [KTVHCPathTools deleteFileAtPath:path];
        [self unlock];
        return NO;
    }
    KTVHCLogDataUnit(@"%p, Merge replace items", self);
    KTVHCDataUnitItem * item = [[KTVHCDataUnitItem alloc] initWithPath:path offset:0];
    for (KTVHCDataUnitItem * obj in self.unitItemsInternal)
    {
        [KTVHCPathTools deleteFileAtPath:obj.absolutePath];
    }
    [self.unitItemsInternal removeAllObjects];
    [self.unitItemsInternal addObject:item];
    [self unlock];
    return YES;
}

- (void)lock
{
    if (!self.coreLock)
    {
        self.coreLock = [[NSRecursiveLock alloc] init];
    }
    [self.coreLock lock];
    if (!self.lockingUnitItems)
    {
        self.lockingUnitItems = [NSMutableArray array];
    }
    NSArray <KTVHCDataUnitItem *> * objs = [NSArray arrayWithArray:self.unitItemsInternal];
    [self.lockingUnitItems addObject:objs];
    for (KTVHCDataUnitItem * obj in objs)
    {
        [obj lock];
    }
}

- (void)unlock
{
    NSArray <KTVHCDataUnitItem *> * objs = self.lockingUnitItems.lastObject;
    [self.lockingUnitItems removeLastObject];
    if (self.lockingUnitItems.count <= 0)
    {
        self.lockingUnitItems = nil;
    }
    for (KTVHCDataUnitItem * obj in objs)
    {
        [obj unlock];
    }
    [self.coreLock unlock];
}

@end
