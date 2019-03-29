//
//  KTVHCDataManager.h
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KTVHCDataReader.h"
#import "KTVHCDataLoader.h"
#import "KTVHCDataRequest.h"
#import "KTVHCDataResponse.h"
#import "KTVHCDataCacheItem.h"

@interface KTVHCDataStorage : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)storage;

/**
 *  Return file path if the content did finished cache.
 */
- (NSURL *)completeFileURLWithURL:(NSURL *)URL;

/**
 *  Reader for certain request.
 */
- (KTVHCDataReader *)readerWithRequest:(KTVHCDataRequest *)request;

/**
 *  Loader for certain request.
 */
- (KTVHCDataLoader *)loaderWithRequest:(KTVHCDataRequest *)request;

/**
 *  Get cache item.
 */
- (KTVHCDataCacheItem *)cacheItemWithURL:(NSURL *)URL;
- (NSArray<KTVHCDataCacheItem *> *)allCacheItems;

/**
 *  Get cache length.
 */
@property (nonatomic) long long maxCacheLength;     // Default is 500M.
- (long long)totalCacheLength;

/**
 *  Delete cache.
 */
- (void)deleteCacheWithURL:(NSURL *)URL;
- (void)deleteAllCaches;

@end
