//
//  KTVHCError.h
//  KTVHTTPCache
//
//  Created by Single on 2017/8/17.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, KTVHCErrorCode) {
    KTVHCErrorCodeResponseUnavailable  = -192700,
    KTVHCErrorCodeUnsupportContentType = -192701,
    KTVHCErrorCodeNotEnoughDiskSpace   = -192702,
    KTVHCErrorCodeException            = -192703,
};

@interface KTVHCError : NSObject

+ (NSError *)errorForResponseUnavailable:(NSURL *)URL
                                 request:(NSURLRequest *)request
                                response:(NSURLResponse *)response;

+ (NSError *)errorForUnsupportContentType:(NSURL *)URL
                                  request:(NSURLRequest *)request
                                 response:(NSURLResponse *)response;

+ (NSError *)errorForNotEnoughDiskSpace:(long long)totlaContentLength
                                request:(long long)currentContentLength
                       totalCacheLength:(long long)totalCacheLength
                         maxCacheLength:(long long)maxCacheLength;

+ (NSError *)errorForException:(NSException *)exception;

@end
