//
//  KTVHCDataUnitPool.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCDataUnitPool.h"
#import "KTVHCDataUnitQueue.h"
#import "KTVHCData+Internal.h"
#import "KTVHCPathTool.h"
#import "KTVHCURLTool.h"
#import "KTVHCLog.h"

#import <UIKit/UIKit.h>

@interface KTVHCDataUnitPool () <NSLocking, KTVHCDataUnitDelegate>

@property (nonatomic, strong) NSRecursiveLock *coreLock;
@property (nonatomic, strong) KTVHCDataUnitQueue *unitQueue;
@property (nonatomic, strong) dispatch_queue_t archiveQueue;
@property (nonatomic) int64_t expectArchiveIndex;
@property (nonatomic) int64_t actualArchiveIndex;

@end

@implementation KTVHCDataUnitPool

+ (instancetype)pool
{
    static KTVHCDataUnitPool *obj = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        obj = [[self alloc] init];
    });
    return obj;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.unitQueue = [[KTVHCDataUnitQueue alloc] initWithPath:[KTVHCPathTool archivePath]];
        for (KTVHCDataUnit *obj in self.unitQueue.allUnits) {
            obj.delegate = self;
        }
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
        [[NSNotificationCenter defaultCenter]  addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter]  addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        KTVHCLogDataUnitPool(@"%p, Create Pool\nUnits : %@", self, self.unitQueue.allUnits);
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (KTVHCDataUnit *)unitWithURL:(NSURL *)URL
{
    if (URL.absoluteString.length <= 0) {
        return nil;
    }
    [self lock];
    NSString *key = [[KTVHCURLTool tool] keyWithURL:URL];
    KTVHCDataUnit *unit = [self.unitQueue unitWithKey:key];
    if (!unit) {
        unit = [[KTVHCDataUnit alloc] initWithURL:URL];
        unit.delegate = self;
        KTVHCLogDataUnitPool(@"%p, Insert Unit, %@", self, unit);
        [self.unitQueue putUnit:unit];
        [self setNeedsArchive];
    }
    [unit workingRetain];
    [self unlock];
    return unit;
}

- (long long)totalCacheLength
{
    [self lock];
    long long length = 0;
    NSArray<KTVHCDataUnit *> *units = [self.unitQueue allUnits];
    for (KTVHCDataUnit *obj in units) {
        length += obj.cacheLength;
    }
    [self unlock];
    return length;
}

- (KTVHCDataCacheItem *)cacheItemWithURL:(NSURL *)URL
{
    if (URL.absoluteString.length <= 0) {
        return nil;
    }
    [self lock];
    KTVHCDataCacheItem *cacheItem = nil;
    NSString *key = [[KTVHCURLTool tool] keyWithURL:URL];
    KTVHCDataUnit *obj = [self.unitQueue unitWithKey:key];
    if (obj) {
        NSArray *items = obj.unitItems;
        NSMutableArray *zones = [NSMutableArray array];
        for (KTVHCDataUnitItem *item in items) {
            KTVHCDataCacheItemZone *zone = [[KTVHCDataCacheItemZone alloc] initWithOffset:item.offset length:item.length];
            [zones addObject:zone];
        }
        if (zones.count == 0) {
            zones = nil;
        }
        cacheItem = [[KTVHCDataCacheItem alloc] initWithURL:obj.URL
                                                      zones:zones
                                                totalLength:obj.totalLength
                                                cacheLength:obj.cacheLength
                                                vaildLength:obj.validLength];
    }
    [self unlock];
    return cacheItem;
}

- (NSArray<KTVHCDataCacheItem *> *)allCacheItem
{
    [self lock];
    NSMutableArray *cacheItems = [NSMutableArray array];
    NSArray<KTVHCDataUnit *> *units = [self.unitQueue allUnits];
    for (KTVHCDataUnit *obj in units) {
        KTVHCDataCacheItem *cacheItem = [self cacheItemWithURL:obj.URL];
        if (cacheItem) {
            [cacheItems addObject:cacheItem];
        }
    }
    if (cacheItems.count == 0) {
        cacheItems = nil;
    }
    [self unlock];
    return cacheItems;
}

- (void)deleteUnitWithURL:(NSURL *)URL
{
    if (URL.absoluteString.length <= 0) {
        return;
    }
    [self lock];
    NSString *key = [[KTVHCURLTool tool] keyWithURL:URL];
    KTVHCDataUnit *obj = [self.unitQueue unitWithKey:key];
    if (obj && obj.workingCount <= 0) {
        KTVHCLogDataUnit(@"%p, Delete Unit\nUnit : %@\nFunc : %s", self, obj, __func__);
        [obj deleteFiles];
        [self.unitQueue popUnit:obj];
        [self setNeedsArchive];
    }
    [self unlock];
}

- (void)deleteUnitsWithLength:(long long)length
{
    if (length <= 0) {
        return;
    }
    [self lock];
    BOOL needArchive = NO;
    long long currentLength = 0;
    NSArray<KTVHCDataUnit *> *units = [self.unitQueue allUnits];
    [units sortedArrayUsingComparator:^NSComparisonResult(KTVHCDataUnit *obj1, KTVHCDataUnit *obj2) {
        NSComparisonResult result = NSOrderedDescending;
        [obj1 lock];
        [obj2 lock];
        NSTimeInterval timeInterval1 = obj1.lastItemCreateInterval;
        NSTimeInterval timeInterval2 = obj2.lastItemCreateInterval;
        if (timeInterval1 < timeInterval2) {
            result = NSOrderedAscending;
        } else if (timeInterval1 == timeInterval2 && obj1.createTimeInterval < obj2.createTimeInterval) {
            result = NSOrderedAscending;
        }
        [obj1 unlock];
        [obj2 unlock];
        return result;
    }];
    for (KTVHCDataUnit *obj in units) {
        if (obj.workingCount <= 0) {
            [obj lock];
            currentLength += obj.cacheLength;
            KTVHCLogDataUnit(@"%p, Delete Unit\nUnit : %@\nFunc : %s", self, obj, __func__);
            [obj deleteFiles];
            [obj unlock];
            [self.unitQueue popUnit:obj];
            needArchive = YES;
        }
        if (currentLength >= length) {
            break;
        }
    }
    if (needArchive) {
        [self setNeedsArchive];
    }
    [self unlock];
}

- (void)deleteAllUnits
{
    [self lock];
    BOOL needArchive = NO;
    NSArray<KTVHCDataUnit *> *units = [self.unitQueue allUnits];
    for (KTVHCDataUnit *obj in units) {
        if (obj.workingCount <= 0) {
            KTVHCLogDataUnit(@"%p, Delete Unit\nUnit : %@\nFunc : %s", self, obj, __func__);
            [obj deleteFiles];
            [self.unitQueue popUnit:obj];
            needArchive = YES;
        }
    }
    if (needArchive) {
        [self setNeedsArchive];
    }
    [self unlock];
}

- (void)setNeedsArchive
{
    [self lock];
    self.expectArchiveIndex += 1;
    int64_t expectArchiveIndex = self.expectArchiveIndex;
    [self unlock];
    if (!self.archiveQueue) {
        self.archiveQueue = dispatch_queue_create("KTVHTTPCache-archiveQueue", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), self.archiveQueue, ^{
        [self lock];
        if (self.expectArchiveIndex == expectArchiveIndex) {
            [self archiveIfNeeded];
        }
        [self unlock];
    });
}

- (void)archiveIfNeeded
{
    [self lock];
    if (self.actualArchiveIndex != self.expectArchiveIndex) {
        self.actualArchiveIndex = self.expectArchiveIndex;
        [self.unitQueue archive];
    }
    [self unlock];
}

#pragma mark - KTVHCDataUnitDelegate

- (void)ktv_unitDidChangeMetadata:(KTVHCDataUnit *)unit
{
    [self setNeedsArchive];
}

#pragma mark - UIApplicationWillTerminateNotification

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [self archiveIfNeeded];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    [self archiveIfNeeded];
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    [self archiveIfNeeded];
}

#pragma mark - NSLocking

- (void)lock
{
    if (!self.coreLock) {
        self.coreLock = [[NSRecursiveLock alloc] init];
    }
    [self.coreLock lock];
}

- (void)unlock
{
    [self.coreLock unlock];
}

@end
