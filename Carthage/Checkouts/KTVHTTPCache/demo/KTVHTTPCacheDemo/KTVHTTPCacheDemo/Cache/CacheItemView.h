//
//  CacheItemView.h
//  KTVHTTPCacheDemo
//
//  Created by Single on 2017/8/13.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CacheItemView;

@protocol  CacheItemViewDelegate <NSObject>

- (void)cacheItemView:(CacheItemView *)view deleteButtonDidClick:(NSString *)URLString;

@end

@interface CacheItemView : UIView

- (instancetype)initWithURLString:(NSString *)URLString
                      totalLength:(long long)totalLength
                      cacheLength:(long long)cacheLength;

@property (nonatomic, weak) id <CacheItemViewDelegate> delegate;

@end
