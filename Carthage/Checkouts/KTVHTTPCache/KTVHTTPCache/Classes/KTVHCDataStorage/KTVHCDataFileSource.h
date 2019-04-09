//
//  KTVHCDataFileSource.h
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KTVHCDataSource.h"

@class KTVHCDataFileSource;

@protocol KTVHCDataFileSourceDelegate <NSObject>

- (void)ktv_fileSourceDidPrepare:(KTVHCDataFileSource *)fileSource;
- (void)ktv_fileSource:(KTVHCDataFileSource *)fileSource didFailWithError:(NSError *)error;

@end

@interface KTVHCDataFileSource : NSObject <KTVHCDataSource>

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithPath:(NSString *)path range:(KTVHCRange)range readRange:(KTVHCRange)readRange NS_DESIGNATED_INITIALIZER;

@property (nonatomic, copy, readonly) NSString *path;
@property (nonatomic, readonly) KTVHCRange readRange;

@property (nonatomic, weak, readonly) id<KTVHCDataFileSourceDelegate> delegate;
@property (nonatomic, strong, readonly) dispatch_queue_t delegateQueue;

- (void)setDelegate:(id<KTVHCDataFileSourceDelegate>)delegate delegateQueue:(dispatch_queue_t)delegateQueue;

@end
