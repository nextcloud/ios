//
//  KTVHCDataNetworkSource.h
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KTVHCDataSourceProtocol.h"
#import "KTVHCDataRequest.h"
#import "KTVHCDataResponse.h"

@class KTVHCDataNetworkSource;

@protocol KTVHCDataNetworkSourceDelegate <NSObject>

- (void)networkSourceDidPrepared:(KTVHCDataNetworkSource *)networkSource;
- (void)networkSourceHasAvailableData:(KTVHCDataNetworkSource *)networkSource;
- (void)networkSourceDidFinishedDownload:(KTVHCDataNetworkSource *)networkSource;
- (void)networkSource:(KTVHCDataNetworkSource *)networkSource didFailed:(NSError *)error;

@end

@interface KTVHCDataNetworkSource : NSObject <KTVHCDataSourceProtocol>

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithRequest:(KTVHCDataRequest *)reqeust;

@property (nonatomic, strong, readonly) KTVHCDataRequest * request;
@property (nonatomic, strong, readonly) KTVHCDataResponse * response;
@property (nonatomic, assign, readonly) KTVHCRange range;

@property (nonatomic, assign, readonly) BOOL didPrepared;
@property (nonatomic, assign, readonly) BOOL didFinished;
@property (nonatomic, assign, readonly) BOOL didClosed;

- (void)prepare;
- (void)close;

- (NSData *)readDataOfLength:(NSUInteger)length;

@property (nonatomic, weak, readonly) id<KTVHCDataNetworkSourceDelegate> delegate;
@property (nonatomic, strong, readonly) dispatch_queue_t delegateQueue;

- (void)setDelegate:(id<KTVHCDataNetworkSourceDelegate>)delegate delegateQueue:(dispatch_queue_t)delegateQueue;

@end
