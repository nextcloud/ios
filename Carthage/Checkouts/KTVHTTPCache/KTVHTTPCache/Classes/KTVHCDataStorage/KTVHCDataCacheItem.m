//
//  KTVHCDataCacheItem.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/13.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCDataCacheItem.h"
#import "KTVHCData+Internal.h"

@implementation KTVHCDataCacheItem

- (instancetype)initWithURL:(NSURL *)URL
                      zones:(NSArray<KTVHCDataCacheItemZone *> *)zones
                totalLength:(long long)totalLength
                cacheLength:(long long)cacheLength
                vaildLength:(long long)vaildLength
{
    if (self = [super init]) {
        self->_URL = [URL copy];
        self->_zones = [zones copy];
        self->_totalLength = totalLength;
        self->_cacheLength = cacheLength;
        self->_vaildLength = vaildLength;
    }
    return self;
}

@end
