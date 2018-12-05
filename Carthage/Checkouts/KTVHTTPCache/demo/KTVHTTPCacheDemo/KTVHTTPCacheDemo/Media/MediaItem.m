//
//  MediaItem.m
//  KTVHTTPCacheDemo
//
//  Created by Single on 2017/8/13.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "MediaItem.h"

@implementation MediaItem

- (instancetype)initWithTitle:(NSString *)title URLString:(NSString *)URLString
{
    if (self = [super init])
    {
        self.title = title;
        self.URLString = URLString;
    }
    return self;
}

@end
