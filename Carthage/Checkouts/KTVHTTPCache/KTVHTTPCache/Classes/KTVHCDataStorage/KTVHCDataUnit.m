//
//  KTVHCDataUnit.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCDataUnit.h"
#import "KTVHCPathTool.h"
#import "KTVHCURLTool.h"
#import "KTVHCError.h"
#import "KTVHCLog.h"

@interface KTVHCDataUnit ()

@property (nonatomic, strong) NSRecursiveLock *coreLock;
@property (nonatomic, strong) NSMutableArray<KTVHCDataUnitItem *> *unitItemsInternal;
@property (nonatomic, strong) NSMutableArray<NSArray<KTVHCDataUnitItem *> *> *lockingUnitItems;

@end

@implementation KTVHCDataUnit

- (instancetype)initWithURL:(NSURL *)URL
{
    if (self = [super init]) {
        self->_URL = [URL copy];
        self->_key = [[KTVHCURLTool tool] keyWithURL:self.URL];
        self->_createTimeInterval = [NSDate date].timeIntervalSince1970;
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super init]) {
        @try {
            self->_URL = [NSURL URLWithString:[aDecoder decodeObjectForKey:@"URLString"]];
            self->_key = [aDecoder decodeObjectForKey:@"uniqueIdentifier"];
        } @catch (NSException *exception) {
            self->_error = [KTVHCError errorForException:exception];
        }
        @try {
            self->_createTimeInterval = [[aDecoder decodeObjectForKey:@"createTimeInterval"] doubleValue];
            self->_responseHeaders = [aDecoder decodeObjectForKey:@"responseHeaderFields"];
            self->_totalLength = [[aDecoder decodeObjectForKey:@"totalContentLength"] longLongValue];
            self->_unitItemsInternal = [[aDecoder decodeObjectForKey:@"unitItems"] mutableCopy];
            [self commonInit];
        } @catch (NSException *exception) {
            self->_error = [KTVHCError errorForException:exception];
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
    [aCoder encodeObject:self.responseHeaders forKey:@"responseHeaderFields"];
    [aCoder encodeObject:@(self.totalLength) forKey:@"totalContentLength"];
    [aCoder encodeObject:self.unitItemsInternal forKey:@"unitItems"];
    [self unlock];
}

- (void)dealloc
{
    KTVHCLogDealloc(self);
}

- (void)commonInit
{
    KTVHCLogAlloc(self);
    [self lock];
    if (!self.unitItemsInternal) {
        self.unitItemsInternal = [NSMutableArray array];
    }
    NSMutableArray *removal = [NSMutableArray array];
    for (KTVHCDataUnitItem *obj in self.unitItemsInternal) {
        if (obj.length == 0) {
            [KTVHCPathTool deleteFileAtPath:obj.absolutePath];
            [removal addObject:obj];
        }
    }
    [self.unitItemsInternal removeObjectsInArray:removal];
    [self sortUnitItems];
    KTVHCLogDataUnit(@"%p, Create Unit\nURL : %@\nkey : %@\ntimeInterval : %@\ntotalLength : %lld\ncacheLength : %lld\nvaildLength : %lld\nresponseHeaders : %@\nunitItems : %@", self, self.URL, self.key, [NSDate dateWithTimeIntervalSince1970:self.createTimeInterval], self.totalLength, self.cacheLength, self.validLength, self.responseHeaders, self.unitItemsInternal);
    [self unlock];
}

- (void)sortUnitItems
{
    [self lock];
    KTVHCLogDataUnit(@"%p, Sort unitItems - Begin\n%@", self, self.unitItemsInternal);
    [self.unitItemsInternal sortUsingComparator:^NSComparisonResult(KTVHCDataUnitItem *obj1, KTVHCDataUnitItem *obj2) {
        NSComparisonResult result = NSOrderedDescending;
        if (obj1.offset < obj2.offset) {
            result = NSOrderedAscending;
        } else if ((obj1.offset == obj2.offset) && (obj1.length > obj2.length)) {
            result = NSOrderedAscending;
        }
        return result;
    }];
    KTVHCLogDataUnit(@"%p, Sort unitItems - End  \n%@", self, self.unitItemsInternal);
    [self unlock];
}

- (NSArray<KTVHCDataUnitItem *> *)unitItems
{
    [self lock];
    NSMutableArray *objs = [NSMutableArray array];
    for (KTVHCDataUnitItem *obj in self.unitItemsInternal) {
        [objs addObject:[obj copy]];
    }
    KTVHCLogDataUnit(@"%p, Get unitItems\n%@", self, self.unitItemsInternal);
    [self unlock];
    return objs;
}

- (void)insertUnitItem:(KTVHCDataUnitItem *)unitItem
{
    [self lock];
    [self.unitItemsInternal addObject:unitItem];
    [self sortUnitItems];
    KTVHCLogDataUnit(@"%p, Insert unitItem, %@", self, unitItem);
    [self unlock];
    [self.delegate ktv_unitDidChangeMetadata:self];
}

- (void)updateResponseHeaders:(NSDictionary *)responseHeaders totalLength:(long long)totalLength
{
    [self lock];
    BOOL needs = NO;
    static NSArray *whiteList = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        whiteList = @[@"Accept-Ranges",
                      @"Connection",
                      @"Content-Type",
                      @"Server"];
    });
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    for (NSString *key in whiteList) {
        NSString *value = [responseHeaders objectForKey:key];
        if (value) {
            [headers setObject:value forKey:key];
        }
    }
    if (self.totalLength != totalLength || ![self.responseHeaders isEqualToDictionary:headers]) {
        self->_responseHeaders = headers;
        self->_totalLength = totalLength;
        needs = YES;
    }
    KTVHCLogDataUnit(@"%p, Update responseHeaders\ntotalLength : %lld\n%@", self, self.totalLength, self.responseHeaders);
    [self unlock];
    if (needs) {
        [self.delegate ktv_unitDidChangeMetadata:self];
    }
}

- (NSURL *)completeURL
{
    [self lock];
    NSURL *completeURL = nil;
    KTVHCDataUnitItem *item = self.unitItemsInternal.firstObject;
    if (item.offset == 0 && item.length > 0 && item.length == self.totalLength) {
        completeURL = [NSURL fileURLWithPath:item.absolutePath];
        KTVHCLogDataUnit(@"%p, Get file path\n%@", self, completeURL);
    }
    [self unlock];
    return completeURL;
}

- (long long)cacheLength
{
    [self lock];
    long long length = 0;
    for (KTVHCDataUnitItem *obj in self.unitItemsInternal) {
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
    for (KTVHCDataUnitItem *obj in self.unitItemsInternal) {
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
    for (KTVHCDataUnitItem *obj in self.unitItemsInternal) {
        if (obj.createTimeInterval > timeInterval) {
            timeInterval = obj.createTimeInterval;
        }
    }
    [self unlock];
    return timeInterval;
}

- (void)workingRetain
{
    [self lock];
    self->_workingCount += 1;
    KTVHCLogDataUnit(@"%p, Working retain  : %ld", self, (long)self.workingCount);
    [self unlock];
}

- (void)workingRelease
{
    [self lock];
    self->_workingCount -= 1;
    KTVHCLogDataUnit(@"%p, Working release : %ld", self, (long)self.workingCount);
    BOOL needs = [self mergeFilesIfNeeded];
    [self unlock];
    if (needs) {
        [self.delegate ktv_unitDidChangeMetadata:self];
    }
}

- (void)deleteFiles
{
    if (!self.URL) {
        return;
    }
    [self lock];
    NSString *path = [KTVHCPathTool directoryPathWithURL:self.URL];
    [KTVHCPathTool deleteDirectoryAtPath:path];
    KTVHCLogDataUnit(@"%p, Delete files", self);
    [self unlock];
}

- (BOOL)mergeFilesIfNeeded
{
    [self lock];
    if (self.workingCount > 0 || self.totalLength == 0 || self.unitItemsInternal.count == 0) {
        [self unlock];
        return NO;
    }
    NSString *path = [KTVHCPathTool completeFilePathWithURL:self.URL];
    if ([self.unitItemsInternal.firstObject.absolutePath isEqualToString:path]) {
        [self unlock];
        return NO;
    }
    if (self.totalLength != self.validLength) {
        [self unlock];
        return NO;
    }
    NSError *error = nil;
    long long offset = 0;
    [KTVHCPathTool deleteFileAtPath:path];
    [KTVHCPathTool createFileAtPath:path];
    NSFileHandle *writingHandle = [NSFileHandle fileHandleForWritingAtPath:path];
    for (KTVHCDataUnitItem *obj in self.unitItemsInternal) {
        if (error) {
            break;
        }
        NSAssert(offset >= obj.offset, @"invaild unit item.");
        if (offset >= (obj.offset + obj.length)) {
            KTVHCLogDataUnit(@"%p, Merge files continue", self);
            continue;
        }
        NSFileHandle *readingHandle = [NSFileHandle fileHandleForReadingAtPath:obj.absolutePath];
        @try {
            [readingHandle seekToFileOffset:offset - obj.offset];
        } @catch (NSException *exception) {
            KTVHCLogDataUnit(@"%p, Merge files seek exception\n%@", self, exception);
            error = [KTVHCError errorForException:exception];
        }
        if (error) {
            break;
        }
        while (!error) {
            @autoreleasepool {
                NSData *data = [readingHandle readDataOfLength:1024 * 1024 * 1];
                if (data.length == 0) {
                    KTVHCLogDataUnit(@"%p, Merge files break", self);
                    break;
                }
                KTVHCLogDataUnit(@"%p, Merge write data : %lld", self, (long long)data.length);
                @try {
                    [writingHandle writeData:data];
                } @catch (NSException *exception) {
                    KTVHCLogDataUnit(@"%p, Merge files write exception\n%@", self, exception);
                    error = [KTVHCError errorForException:exception];
                }
            }
        }
        [readingHandle closeFile];
        offset = obj.offset + obj.length;
        KTVHCLogDataUnit(@"%p, Merge next : %lld", self, offset);
    }
    @try {
        [writingHandle synchronizeFile];
        [writingHandle closeFile];
    } @catch (NSException *exception) {
        KTVHCLogDataUnit(@"%p, Merge files close exception, %@", self, exception);
        error = [KTVHCError errorForException:exception];
    }
    KTVHCLogDataUnit(@"%p, Merge finished\ntotalLength : %lld\noffset : %lld", self, self.totalLength, offset);
    if (error || [KTVHCPathTool sizeAtPath:path] != self.totalLength) {
        [KTVHCPathTool deleteFileAtPath:path];
        [self unlock];
        return NO;
    }
    KTVHCLogDataUnit(@"%p, Merge replace items", self);
    KTVHCDataUnitItem *item = [[KTVHCDataUnitItem alloc] initWithPath:path];
    for (KTVHCDataUnitItem *obj in self.unitItemsInternal) {
        [KTVHCPathTool deleteFileAtPath:obj.absolutePath];
    }
    [self.unitItemsInternal removeAllObjects];
    [self.unitItemsInternal addObject:item];
    [self unlock];
    return YES;
}

- (void)lock
{
    if (!self.coreLock) {
        self.coreLock = [[NSRecursiveLock alloc] init];
    }
    [self.coreLock lock];
    if (!self.lockingUnitItems) {
        self.lockingUnitItems = [NSMutableArray array];
    }
    NSArray<KTVHCDataUnitItem *> *objs = [NSArray arrayWithArray:self.unitItemsInternal];
    [self.lockingUnitItems addObject:objs];
    for (KTVHCDataUnitItem *obj in objs) {
        [obj lock];
    }
}

- (void)unlock
{
    NSArray<KTVHCDataUnitItem *> *objs = self.lockingUnitItems.lastObject;
    [self.lockingUnitItems removeLastObject];
    if (self.lockingUnitItems.count <= 0) {
        self.lockingUnitItems = nil;
    }
    for (KTVHCDataUnitItem *obj in objs) {
        [obj unlock];
    }
    [self.coreLock unlock];
}

@end
