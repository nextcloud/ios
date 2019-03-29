//
//  KTVHCDataUnitPool.h
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KTVHCDataUnit.h"
#import "KTVHCDataCacheItem.h"

@interface KTVHCDataUnitPool : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)pool;

- (KTVHCDataUnit *)unitWithURL:(NSURL *)URL;

- (long long)totalCacheLength;

- (NSArray <KTVHCDataCacheItem *> *)allCacheItem;
- (KTVHCDataCacheItem *)cacheItemWithURL:(NSURL *)URL;

- (void)deleteUnitWithURL:(NSURL *)URL;
- (void)deleteUnitsWithLength:(long long)length;
- (void)deleteAllUnits;

@end
