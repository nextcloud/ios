//
//  KTVHCHTTPURL.h
//  KTVHTTPCache
//
//  Created by Single on 2017/8/10.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, KTVHCHTTPURLType)
{
    KTVHCHTTPURLTypeUnknown,
    KTVHCHTTPURLTypeContent,
    KTVHCHTTPURLTypePing,
};

@interface KTVHCHTTPURL : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)pingURL;
- (instancetype)initWithProxyURL:(NSURL *)URL;
- (instancetype)initWithOriginalURL:(NSURL *)URL;

@property (nonatomic, assign, readonly) KTVHCHTTPURLType type;
@property (nonatomic, copy, readonly) NSURL * URL;

- (NSURL *)proxyURLWithPort:(NSInteger)port;

@end
