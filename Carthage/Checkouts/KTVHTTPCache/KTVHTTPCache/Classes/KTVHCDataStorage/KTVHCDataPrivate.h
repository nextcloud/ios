//
//  KTVHCDataReaderPrivate.h
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KTVHCDataCacheItem.h"
#import "KTVHCDataCacheItemZone.h"

@interface KTVHCDataCacheItem (Private)

+ (instancetype)itemWithURL:(NSURL *)URL
                totalLength:(long long)totalLength
                cacheLength:(long long)cacheLength
                vaildLength:(long long)vaildLength
                      zones:(NSArray <KTVHCDataCacheItemZone *> *)zones;

@end

@interface KTVHCDataCacheItemZone (Private)

+ (instancetype)itemZoneWithOffset:(long long)offset length:(long long)length;

@end
