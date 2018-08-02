//
//  KTVHCDataLoader.h
//  KTVHTTPCache
//
//  Created by Single on 2018/6/7.
//  Copyright © 2018 Single. All rights reserved.
//

#import <Foundation/Foundation.h>

@class KTVHCDataLoader;
@class KTVHCDataRequest;
@class KTVHCDataResponse;

@protocol KTVHCDataLoaderDelegate <NSObject>

- (void)loaderDidFinished:(KTVHCDataLoader *)loader;
- (void)loader:(KTVHCDataLoader *)loader didFailed:(NSError *)error;
- (void)loader:(KTVHCDataLoader *)loader didChangeProgress:(double)progress;

@end

@interface KTVHCDataLoader : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)loaderWithRequest:(KTVHCDataRequest *)request;

@property (nonatomic, weak) id <KTVHCDataLoaderDelegate> delegate;

@property (nonatomic, strong) id object;

@property (nonatomic, strong, readonly) KTVHCDataRequest * request;
@property (nonatomic, strong, readonly) KTVHCDataResponse * response;

@property (nonatomic, strong, readonly) NSError * error;

@property (nonatomic, assign, readonly) BOOL didClosed;
@property (nonatomic, assign, readonly) BOOL didFinished;

@property (nonatomic, assign, readonly) double progress;

- (void)prepare;
- (void)close;

@end
