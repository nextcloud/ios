//
//  KTVHCURLTools.h
//  KTVHTTPCache
//
//  Created by Single on 2017/8/10.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NSURL * (^KTVHCURLFilter)(NSURL * URL);

@interface KTVHCURLTools : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)URLTools;

@property (nonatomic, copy) KTVHCURLFilter URLFilter;

+ (NSString *)keyWithURL:(NSURL *)URL;

+ (NSString *)URLEncode:(NSString *)URLString;
+ (NSString *)URLDecode:(NSString *)URLString;

@end
