//
//  KTVHCDataSourceManager.h
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KTVHCDataFileSource.h"
#import "KTVHCDataNetworkSource.h"

@class KTVHCDataSourceManager;

@protocol KTVHCDataSourceManagerDelegate <NSObject>

- (void)sourceManagerDidPrepared:(KTVHCDataSourceManager *)sourceManager;
- (void)sourceManagerHasAvailableData:(KTVHCDataSourceManager *)sourceManager;
- (void)sourceManager:(KTVHCDataSourceManager *)sourceManager didFailed:(NSError *)error;
- (void)sourceManager:(KTVHCDataSourceManager *)sourceManager didReceiveResponse:(KTVHCDataResponse *)response;

@end

@interface KTVHCDataSourceManager : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithDelegate:(id <KTVHCDataSourceManagerDelegate>)delegate delegateQueue:(dispatch_queue_t)delegateQueue;

@property (nonatomic, weak, readonly) id <KTVHCDataSourceManagerDelegate> delegate;
@property (nonatomic, strong, readonly) dispatch_queue_t delegateQueue;

@property (nonatomic, strong, readonly) NSError * error;

@property (nonatomic, assign, readonly) BOOL didClosed;
@property (nonatomic, assign, readonly) BOOL didPrepared;
@property (nonatomic, assign, readonly) BOOL didFinished;

- (void)putSource:(id<KTVHCDataSourceProtocol>)source;

- (void)prepare;
- (void)close;

- (NSData *)readDataOfLength:(NSUInteger)length;

@end
