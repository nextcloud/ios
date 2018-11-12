//
//  KTVHCDataReader.h
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>

@class KTVHCDataReader;
@class KTVHCDataRequest;
@class KTVHCDataResponse;

@protocol KTVHCDataReaderDelegate <NSObject>

- (void)readerDidPrepared:(KTVHCDataReader *)reader;
- (void)readerHasAvailableData:(KTVHCDataReader *)reader;
- (void)reader:(KTVHCDataReader *)reader didFailed:(NSError *)error;

@end

@interface KTVHCDataReader : NSObject <NSLocking>

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)readerWithRequest:(KTVHCDataRequest *)request;

@property (nonatomic, weak) id <KTVHCDataReaderDelegate> delegate;

@property (nonatomic, strong) id object;

@property (nonatomic, strong, readonly) KTVHCDataRequest * request;
@property (nonatomic, strong, readonly) KTVHCDataResponse * response;

@property (nonatomic, strong, readonly) NSError * error;

@property (nonatomic, assign, readonly) BOOL didClosed;
@property (nonatomic, assign, readonly) BOOL didPrepared;
@property (nonatomic, assign, readonly) BOOL didFinished;

@property (nonatomic, assign, readonly) long long readOffset;

- (void)prepare;
- (void)close;

- (NSData *)readDataOfLength:(NSUInteger)length;

@end
