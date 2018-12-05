//
//  KTVHCDataUnitItem.h
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KTVHCDataUnitItem : NSObject <NSCopying, NSCoding, NSLocking>

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithPath:(NSString *)path offset:(long long)offset;

@property (nonatomic, assign, readonly) NSTimeInterval createTimeInterval;

@property (nonatomic, copy, readonly) NSString * relativePath;
@property (nonatomic, copy, readonly) NSString * absolutePath;

@property (nonatomic, assign, readonly) long long offset;
@property (nonatomic, assign, readonly) long long length;

- (void)setLength:(long long)length;

@end
