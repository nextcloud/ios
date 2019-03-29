//
//  KTVHCDataDownload.h
//  KTVHTTPCache
//
//  Created by Single on 2017/8/12.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KTVHCDataResponse.h"
#import "KTVHCDataRequest.h"
#import "KTVHCMacro.h"

KTVHTTPCACHE_EXTERN NSString * const KTVHCContentTypeVideo;
KTVHTTPCACHE_EXTERN NSString * const KTVHCContentTypeAudio;
KTVHTTPCACHE_EXTERN NSString * const KTVHCContentTypeApplicationMPEG4;
KTVHTTPCACHE_EXTERN NSString * const KTVHCContentTypeApplicationOctetStream;
KTVHTTPCACHE_EXTERN NSString * const KTVHCContentTypeBinaryOctetStream;

@class KTVHCDownload;

@protocol KTVHCDownloadDelegate <NSObject>

- (void)ktv_download:(KTVHCDownload *)download didCompleteWithError:(NSError *)error;
- (void)ktv_download:(KTVHCDownload *)download didReceiveResponse:(KTVHCDataResponse *)response;
- (void)ktv_download:(KTVHCDownload *)download didReceiveData:(NSData *)data;

@end

@interface KTVHCDownload : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)download;

@property (nonatomic) NSTimeInterval timeoutInterval;

/**
 *  Header Fields
 */
@property (nonatomic, copy) NSArray<NSString *> *whitelistHeaderKeys;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *additionalHeaders;

/**
 *  Content-Type
 */
@property (nonatomic, copy) NSArray<NSString *> *acceptableContentTypes;
@property (nonatomic, copy) BOOL (^unacceptableContentTypeDisposer)(NSURL *URL, NSString *contentType);

- (NSURLSessionTask *)downloadWithRequest:(KTVHCDataRequest *)request delegate:(id<KTVHCDownloadDelegate>)delegate;

@end
