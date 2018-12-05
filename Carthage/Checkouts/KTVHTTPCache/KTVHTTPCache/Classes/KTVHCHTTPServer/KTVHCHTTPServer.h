//
//  KTVHCHTTPServer.h
//  KTVHTTPCache
//
//  Created by Single on 2017/8/10.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KTVHCHTTPServer : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)server;

@property (nonatomic, assign, readonly) BOOL running;

- (void)start:(NSError **)error;
- (void)stop;

- (NSURL *)URLWithOriginalURL:(NSURL *)URL;

@end
