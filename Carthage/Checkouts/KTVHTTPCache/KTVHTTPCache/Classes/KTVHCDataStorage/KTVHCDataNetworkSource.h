//
//  KTVHCDataNetworkSource.h
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KTVHCDataSource.h"
#import "KTVHCDataRequest.h"
#import "KTVHCDataResponse.h"

@class KTVHCDataNetworkSource;

@protocol KTVHCDataNetworkSourceDelegate <NSObject>

- (void)ktv_networkSourceDidPrepare:(KTVHCDataNetworkSource *)networkSource;
- (void)ktv_networkSourceHasAvailableData:(KTVHCDataNetworkSource *)networkSource;
- (void)ktv_networkSourceDidFinisheDownload:(KTVHCDataNetworkSource *)networkSource;
- (void)ktv_networkSource:(KTVHCDataNetworkSource *)networkSource didFailWithError:(NSError *)error;

@end

@interface KTVHCDataNetworkSource : NSObject <KTVHCDataSource>

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithRequest:(KTVHCDataRequest *)reqeust NS_DESIGNATED_INITIALIZER;

@property (nonatomic, strong, readonly) KTVHCDataRequest *request;
@property (nonatomic, strong, readonly) KTVHCDataResponse *response;

@property (nonatomic, weak, readonly) id<KTVHCDataNetworkSourceDelegate> delegate;
@property (nonatomic, strong, readonly) dispatch_queue_t delegateQueue;

- (void)setDelegate:(id<KTVHCDataNetworkSourceDelegate>)delegate delegateQueue:(dispatch_queue_t)delegateQueue;

@end
