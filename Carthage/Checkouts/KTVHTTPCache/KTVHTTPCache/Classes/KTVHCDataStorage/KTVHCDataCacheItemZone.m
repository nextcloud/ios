//
//  KTVHCDataCacheItemZone.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/13.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCDataCacheItemZone.h"
#import "KTVHCData+Internal.h"

@implementation KTVHCDataCacheItemZone

- (instancetype)initWithOffset:(long long)offset length:(long long)length
{
    if (self = [super init]) {
        self->_offset = offset;
        self->_length = length;
    }
    return self;
}

@end
