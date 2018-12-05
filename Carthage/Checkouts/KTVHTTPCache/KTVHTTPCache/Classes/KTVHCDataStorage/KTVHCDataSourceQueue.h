//
//  KTVHCDataSourceQueue.h
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KTVHCDataSourceProtocol.h"

@class KTVHCDataFileSource;
@class KTVHCDataNetworkSource;

@protocol KTVHCDataFileSourceDelegate;
@protocol KTVHCDataNetworkSourceDelegate;

@interface KTVHCDataSourceQueue : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)sourceQueue;

- (void)putSource:(id<KTVHCDataSourceProtocol>)source;
- (void)popSource:(id<KTVHCDataSourceProtocol>)source;

- (void)setAllSourceDelegate:(id<KTVHCDataFileSourceDelegate, KTVHCDataNetworkSourceDelegate>)delegate delegateQueue:(dispatch_queue_t)delegateQueue;

- (void)sortSources;
- (void)closeAllSource;

- (id<KTVHCDataSourceProtocol>)firstSource;
- (id<KTVHCDataSourceProtocol>)nextSource:(id<KTVHCDataSourceProtocol>)currentSource;

- (KTVHCDataNetworkSource *)firstNetworkSource;
- (KTVHCDataNetworkSource *)nextNetworkSource:(KTVHCDataNetworkSource *)currentSource;

@end
