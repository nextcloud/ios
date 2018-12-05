//
//  KTVHCHTTPRequest.h
//  KTVHTTPCache
//
//  Created by Single on 2017/8/10.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KTVHCHTTPRequest : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithURL:(NSURL *)URL headers:(NSDictionary *)headers;

@property (nonatomic, copy, readonly) NSURL * URL;
@property (nonatomic, copy, readonly) NSDictionary * headers;
@property (nonatomic, copy) NSString * method;
@property (nonatomic, copy) NSString * version;

@end
