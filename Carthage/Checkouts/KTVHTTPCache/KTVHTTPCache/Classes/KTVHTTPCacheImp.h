//
//  KTVHTTPCacheImp.h
//  KTVHTTPCache
//
//  Created by Single on 2017/8/13.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>

@class KTVHCDataReader;
@class KTVHCDataLoader;
@class KTVHCDataRequest;
@class KTVHCDataCacheItem;

@interface KTVHTTPCache : NSObject

#pragma mark - HTTP Server

/**
 *  Start & Stop HTTP Server.
 */
+ (void)proxyStart:(NSError **)error;
+ (void)proxyStop;

+ (BOOL)proxyIsRunning;

/**
 *  Return the URL string for local server.
 */
+ (NSURL *)proxyURLWithOriginalURL:(NSURL *)URL;
+ (NSString *)proxyURLStringWithOriginalURLString:(NSString *)URLString;

#pragma mark - Data Storage

/**
 *  If the content of the URL is finish cached, return the file path for the content. Otherwise return nil.
 */
+ (NSURL *)cacheCompleteFileURLIfExistedWithURL:(NSURL *)URL;
+ (NSString *)cacheCompleteFilePathIfExistedWithURLString:(NSString *)URLString;

/**
 *  Data Reader.
 */
+ (KTVHCDataReader *)cacheReaderWithRequest:(KTVHCDataRequest *)request;

/**
 *  Data Loader.
 */
+ (KTVHCDataLoader *)cacheLoaderWithRequest:(KTVHCDataRequest *)request;

/**
 *  Cache State.
 */
+ (void)cacheSetMaxCacheLength:(long long)maxCacheLength;
+ (long long)cacheMaxCacheLength;
+ (long long)cacheTotalCacheLength;

/**
 *  Cache Item.
 */
+ (KTVHCDataCacheItem *)cacheCacheItemWithURL:(NSURL *)URL;
+ (KTVHCDataCacheItem *)cacheCacheItemWithURLString:(NSString *)URLString;
+ (NSArray <KTVHCDataCacheItem *> *)cacheAllCacheItems;

/**
 *  Delete Cache.
 */
+ (void)cacheDeleteCacheWithURL:(NSURL *)URL;
+ (void)cacheDeleteCacheWithURLString:(NSString *)URLString;
+ (void)cacheDeleteAllCaches;

#pragma mark - Token

/**
 *  URL Filter.
 *
 *  High frequency call. Make it simple.
 */
+ (void)tokenSetURLFilter:(NSURL * (^)(NSURL * URL))URLFilter;

#pragma mark - Download

+ (void)downloadSetTimeoutInterval:(NSTimeInterval)timeoutInterval;
+ (NSTimeInterval)downloadTimeoutInterval;

/**
 *  Whitelist Header Fields.
 */
+ (void)downloadSetWhitelistHeaderKeys:(NSArray <NSString *> *)whitelistHeaderKeys;
+ (NSArray <NSString *> *)downloadWhitelistHeaderKeys;

/**
 *  Additional Header Fields.
 */
+ (void)downloadSetAdditionalHeaders:(NSDictionary <NSString *, NSString *> *)additionalHeaders;
+ (NSDictionary <NSString *, NSString *> *)downloadAdditionalHeaders;

/**
 *  Default values: 'video/x', 'audio/x', 'application/mp4', 'application/octet-stream', 'binary/octet-stream'
 */
+ (void)downloadSetAcceptContentTypes:(NSArray <NSString *> *)acceptContentTypes;
+ (NSArray <NSString *> *)downloadAcceptContentTypes;

/**
 *  If the receive response's Content-Type not included in acceptContentTypes, this method will be called.
 *  The return value of block to decide whether to continue to load resources. Otherwise the HTTP task will be rejected.
 */
+ (void)downloadSetUnsupportContentTypeFilter:(BOOL(^)(NSURL * URL, NSString * contentType))contentTypeFilter;

#pragma mark - Log

/**
 *  Console & Record.
 */
+ (void)logAddLog:(NSString *)log;

/**
 *  DEBUG & RELEASE : Default is NO.
 */
+ (void)logSetConsoleLogEnable:(BOOL)consoleLogEnable;
+ (BOOL)logConsoleLogEnable;

/**
 *  DEBUG & RELEASE : Default is NO.
 */
+ (void)logSetRecordLogEnable:(BOOL)recordLogEnable;
+ (BOOL)logRecordLogEnable;

+ (NSString *)logRecordLogFilePath;      // nullable
+ (void)logDeleteRecordLog;

/**
 *  Error
 */
+ (NSArray <NSError *> *)logAllErrors;
+ (NSError *)logLastError;

@end
