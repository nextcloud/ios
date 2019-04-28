//
//  KTVHCDataManager.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCDataStorage.h"
#import "KTVHCData+Internal.h"
#import "KTVHCDataUnitPool.h"
#import "KTVHCLog.h"

@implementation KTVHCDataStorage

+ (instancetype)storage
{
    static KTVHCDataStorage *obj = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        obj = [[self alloc] init];
    });
    return obj;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.maxCacheLength = 500 * 1024 * 1024;
    }
    return self;
}

- (NSURL *)completeFileURLWithURL:(NSURL *)URL
{
    KTVHCDataUnit *unit = [[KTVHCDataUnitPool pool] unitWithURL:URL];
    NSURL *completeURL = unit.completeURL;
    [unit workingRelease];
    return completeURL;
}

- (KTVHCDataReader *)readerWithRequest:(KTVHCDataRequest *)request
{
    if (!request || request.URL.absoluteString.length <= 0) {
        KTVHCLogDataStorage(@"Invaild reader request, %@", request.URL);
        return nil;
    }
    KTVHCDataReader *reader = [[KTVHCDataReader alloc] initWithRequest:request];
    return reader;
}

- (KTVHCDataLoader *)loaderWithRequest:(KTVHCDataRequest *)request
{
    if (!request || request.URL.absoluteString.length <= 0) {
        KTVHCLogDataStorage(@"Invaild loader request, %@", request.URL);
        return nil;
    }
    KTVHCDataLoader *loader = [[KTVHCDataLoader alloc] initWithRequest:request];
    return loader;
}

- (KTVHCDataCacheItem *)cacheItemWithURL:(NSURL *)URL
{
    return [[KTVHCDataUnitPool pool] cacheItemWithURL:URL];
}

- (NSArray<KTVHCDataCacheItem *> *)allCacheItems
{
    return [[KTVHCDataUnitPool pool] allCacheItem];
}

- (long long)totalCacheLength
{
    return [[KTVHCDataUnitPool pool] totalCacheLength];
}

- (void)deleteCacheWithURL:(NSURL *)URL
{
    [[KTVHCDataUnitPool pool] deleteUnitWithURL:URL];
}

- (void)deleteAllCaches
{
    [[KTVHCDataUnitPool pool] deleteAllUnits];
}

@end
