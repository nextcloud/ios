//
//  KTVHCDataCacheItem.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/13.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCDataCacheItem.h"
#import "KTVHCDataPrivate.h"

@implementation KTVHCDataCacheItem

+ (instancetype)itemWithURL:(NSURL *)URL
                totalLength:(long long)totalLength
                cacheLength:(long long)cacheLength
                vaildLength:(long long)vaildLength
                      zones:(NSArray <KTVHCDataCacheItemZone *> *)zones
{
    return [[self alloc] initWithURL:URL
                         totalLength:totalLength
                         cacheLength:cacheLength
                         vaildLength:vaildLength
                               zones:zones];
}

- (instancetype)initWithURL:(NSURL *)URL
                totalLength:(long long)totalLength
                cacheLength:(long long)cacheLength
                vaildLength:(long long)vaildLength
                      zones:(NSArray <KTVHCDataCacheItemZone *> *)zones
{
    if (self = [super init])
    {
        _URL = URL;
        _totalLength = totalLength;
        _cacheLength = cacheLength;
        _vaildLength = vaildLength;
        _zones = zones;
    }
    return self;
}

@end
