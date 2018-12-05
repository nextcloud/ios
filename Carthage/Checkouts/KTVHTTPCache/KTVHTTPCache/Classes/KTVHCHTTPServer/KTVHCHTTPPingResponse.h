//
//  KTVHCHTTPPingResponse.h
//  KTVHTTPCache
//
//  Created by Single on 2017/10/23.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KTVHCHTTPHeader.h"
#import "KTVHCCommon.h"

@class KTVHCHTTPConnection;

KTVHTTPCACHE_EXTERN NSString * const KTVHCHTTPPingResponseResponseValue;

@interface KTVHCHTTPPingResponse : NSObject <HTTPResponse>

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)responseWithConnection:(KTVHCHTTPConnection *)connection;

@end
