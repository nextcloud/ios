//
//  KTVHCDataFileSource.h
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KTVHCDataSourceProtocol.h"

@class KTVHCDataFileSource;

@protocol KTVHCDataFileSourceDelegate <NSObject>

- (void)fileSourceDidPrepared:(KTVHCDataFileSource *)fileSource;
- (void)fileSource:(KTVHCDataFileSource *)fileSource didFailed:(NSError *)error;

@end

@interface KTVHCDataFileSource : NSObject <KTVHCDataSourceProtocol>

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithPath:(NSString *)path range:(KTVHCRange)range readRange:(KTVHCRange)readRange;

@property (nonatomic, copy, readonly) NSString * path;
@property (nonatomic, assign, readonly) KTVHCRange range;
@property (nonatomic, assign, readonly) KTVHCRange readRange;

@property (nonatomic, assign, readonly) BOOL didPrepared;
@property (nonatomic, assign, readonly) BOOL didFinished;
@property (nonatomic, assign, readonly) BOOL didClosed;

- (void)prepare;
- (void)close;

- (NSData *)readDataOfLength:(NSUInteger)length;

@property (nonatomic, weak, readonly) id<KTVHCDataFileSourceDelegate> delegate;
@property (nonatomic, strong, readonly) dispatch_queue_t delegateQueue;

- (void)setDelegate:(id<KTVHCDataFileSourceDelegate>)delegate delegateQueue:(dispatch_queue_t)delegateQueue;

@end
