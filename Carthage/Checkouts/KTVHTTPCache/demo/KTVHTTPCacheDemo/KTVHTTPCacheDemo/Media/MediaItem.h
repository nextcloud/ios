//
//  MediaItem.h
//  KTVHTTPCacheDemo
//
//  Created by Single on 2017/8/13.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MediaItem : NSObject

- (instancetype)initWithTitle:(NSString *)title URLString:(NSString *)URLString;

@property (nonatomic, copy) NSString * title;
@property (nonatomic, copy) NSString * URLString;

@end
