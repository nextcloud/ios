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

- (instancetype)initWithPath:(NSString *)path;
- (instancetype)initWithPath:(NSString *)path offset:(uint64_t)offset;

@property (nonatomic, copy, readonly) NSString *relativePath;
@property (nonatomic, copy, readonly) NSString *absolutePath;
@property (nonatomic, readonly) NSTimeInterval createTimeInterval;
@property (nonatomic, readonly) long long offset;
@property (nonatomic, readonly) long long length;

- (void)updateLength:(long long)length;

@end
