//
//  KTVHCDataDownload.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/12.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCDownload.h"
#import "KTVHCDataUnitPool.h"
#import "KTVHCDataStorage.h"
#import "KTVHCError.h"
#import "KTVHCLog.h"

#import <UIKit/UIKit.h>

NSString * const KTVHCContentTypeVideo                  = @"video/";
NSString * const KTVHCContentTypeAudio                  = @"audio/";
NSString * const KTVHCContentTypeApplicationMPEG4       = @"application/mp4";
NSString * const KTVHCContentTypeApplicationOctetStream = @"application/octet-stream";
NSString * const KTVHCContentTypeBinaryOctetStream      = @"binary/octet-stream";

@interface KTVHCDownload () <NSURLSessionDataDelegate, NSLocking>

@property (nonatomic, strong) NSLock * coreLock;
@property (nonatomic, strong) NSURLSession * session;
@property (nonatomic, strong) NSOperationQueue * sessionDelegateQueue;
@property (nonatomic, strong) NSURLSessionConfiguration * sessionConfiguration;
@property (nonatomic, strong) NSMutableDictionary <NSURLSessionTask *, NSError *> * errorDictionary;
@property (nonatomic, strong) NSMutableDictionary <NSURLSessionTask *, KTVHCDataRequest *> * requestDictionary;
@property (nonatomic, strong) NSMutableDictionary <NSURLSessionTask *, id<KTVHCDownloadDelegate>> * delegateDictionary;

@end

@implementation KTVHCDownload

+ (instancetype)download
{
    static KTVHCDownload * obj = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        obj = [[self alloc] init];
    });
    return obj;
}

- (instancetype)init
{
    if (self = [super init])
    {
        KTVHCLogAlloc(self);
        self.timeoutInterval = 30.0f;
        self.errorDictionary = [NSMutableDictionary dictionary];
        self.requestDictionary = [NSMutableDictionary dictionary];
        self.delegateDictionary = [NSMutableDictionary dictionary];
        self.sessionDelegateQueue = [[NSOperationQueue alloc] init];
        self.sessionDelegateQueue.qualityOfService = NSQualityOfServiceUserInteractive;
        self.sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.sessionConfiguration.timeoutIntervalForRequest = self.timeoutInterval;
        self.sessionConfiguration.requestCachePolicy = NSURLRequestReloadIgnoringCacheData;
        self.session = [NSURLSession sessionWithConfiguration:self.sessionConfiguration
                                                     delegate:self
                                                delegateQueue:self.sessionDelegateQueue];
        self.acceptContentTypes = @[KTVHCContentTypeVideo,
                                    KTVHCContentTypeAudio,
                                    KTVHCContentTypeApplicationMPEG4,
                                    KTVHCContentTypeApplicationOctetStream,
                                    KTVHCContentTypeBinaryOctetStream];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:[UIApplication sharedApplication]];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:[UIApplication sharedApplication]];
    }
    return self;
}

- (void)dealloc
{
    KTVHCLogDealloc(self);
}

- (NSArray <NSString *> *)availableHeaderKeys
{
    static NSArray <NSString *> * availableHeaderKeys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        availableHeaderKeys = @[@"User-Agent",
                                @"Connection",
                                @"Accept",
                                @"Accept-Encoding",
                                @"Accept-Language",
                                @"Range"];
    });
    return availableHeaderKeys;
}

- (NSURLSessionTask *)downloadWithRequest:(KTVHCDataRequest *)request delegate:(id<KTVHCDownloadDelegate>)delegate
{
    [self lock];
    NSMutableURLRequest * HTTPRequest = [NSMutableURLRequest requestWithURL:request.URL];
    [request.headers enumerateKeysAndObjectsUsingBlock:^(NSString * key, NSString * obj, BOOL * stop) {
        if ([[self availableHeaderKeys] containsObject:key] || [self.whitelistHeaderKeys containsObject:key]) {
            [HTTPRequest setValue:obj forHTTPHeaderField:key];
        }
    }];
    HTTPRequest.timeoutInterval = self.timeoutInterval;
    HTTPRequest.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    [self.additionalHeaders enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
        [HTTPRequest setValue:obj forHTTPHeaderField:key];
    }];
    NSURLSessionDataTask * task = [self.session dataTaskWithRequest:HTTPRequest];
    task.priority = 1.0;
    [self.requestDictionary setObject:request forKey:task];
    [self.delegateDictionary setObject:delegate forKey:task];
    KTVHCLogDownload(@"%p, Add Request\nrequest : %@\nURL : %@\nheaders : %@\nHTTPRequest headers : %@\nCount : %d", self, request, request.URL, request.headers, HTTPRequest.allHTTPHeaderFields, (int)self.delegateDictionary.count);
    [task resume];
    [self unlock];
    return task;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    [self lock];
    KTVHCLogDownload(@"%p, Complete\nError : %@", self, error);
    id <KTVHCDownloadDelegate> delegate = [self.delegateDictionary objectForKey:task];
    NSError * cancelError = [self.errorDictionary objectForKey:task];
    if (cancelError)
    {
        error = cancelError;
    }
    [delegate download:self didCompleteWithError:error];
    [self.delegateDictionary removeObjectForKey:task];
    [self.requestDictionary removeObjectForKey:task];
    [self.errorDictionary removeObjectForKey:task];
    if (self.delegateDictionary.count <= 0)
    {
        [self cleanBackgroundTaskAsync];
    }
    [self unlock];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    [self lock];
    NSHTTPURLResponse * HTTPResponse = (NSHTTPURLResponse *)response;
    KTVHCDataRequest * dataRequest = [self.requestDictionary objectForKey:dataTask];
    KTVHCDataResponse * dataResponse = [[KTVHCDataResponse alloc] initWithURL:dataRequest.URL headers:HTTPResponse.allHeaderFields];
    KTVHCLogDownload(@"%p, Receive response\nrequest : %@\nresponse : %@\nHTTPResponse : %@", self, dataRequest, dataResponse, [(NSHTTPURLResponse *)response allHeaderFields]);
    NSError * error = nil;
    if (!error)
    {
        if (HTTPResponse.statusCode > 400)
        {
            error = [KTVHCError errorForResponseUnavailable:dataTask.currentRequest.URL request:dataTask.currentRequest response:dataTask.response];
        }
        if (!error)
        {
            BOOL contentTypeVaild = NO;
            if (dataResponse.contentType.length > 0)
            {
                for (NSString * obj in self.acceptContentTypes)
                {
                    if ([[dataResponse.contentType lowercaseString] containsString:[obj lowercaseString]])
                    {
                        contentTypeVaild = YES;
                    }
                }
                if (!contentTypeVaild && self.unsupportContentTypeFilter)
                {
                    contentTypeVaild = self.unsupportContentTypeFilter(dataRequest.URL, dataResponse.contentType);
                }
            }
            if (!contentTypeVaild)
            {
                error = [KTVHCError errorForUnsupportContentType:dataTask.currentRequest.URL request:dataTask.currentRequest response:dataTask.response];
            }
            if (!error)
            {
                if (dataResponse.currentLength <= 0 ||
                    (!KTVHCRangeIsFull(dataRequest.range) &&
                     (dataResponse.currentLength != KTVHCRangeGetLength(dataRequest.range))))
                {
                    error = [KTVHCError errorForUnsupportContentType:dataTask.currentRequest.URL request:dataTask.currentRequest response:dataTask.response];
                }
                if (!error)
                {
                    long long length = dataResponse.currentLength + [KTVHCDataStorage storage].totalCacheLength - [KTVHCDataStorage storage].maxCacheLength;
                    if (length > 0)
                    {
                        [[KTVHCDataUnitPool pool] deleteUnitsWithLength:length];
                        length = dataResponse.currentLength + [KTVHCDataStorage storage].totalCacheLength - [KTVHCDataStorage storage].maxCacheLength;
                        if (length > 0)
                        {
                            error = [KTVHCError errorForNotEnoughDiskSpace:dataResponse.totalLength request:dataResponse.currentLength totalCacheLength:[KTVHCDataStorage storage].totalCacheLength maxCacheLength:[KTVHCDataStorage storage].maxCacheLength];
                        }
                    }
                }
            }
        }
    }
    if (error)
    {
        KTVHCLogDownload(@"%p, Invaild response\nError : %@", self, error);
        [self.errorDictionary setObject:error forKey:dataTask];
        completionHandler(NSURLSessionResponseCancel);
    }
    else
    {
        id <KTVHCDownloadDelegate> delegate = [self.delegateDictionary objectForKey:dataTask];
        [delegate download:self didReceiveResponse:dataResponse];
        completionHandler(NSURLSessionResponseAllow);
    }
    [self unlock];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler
{
    [self lock];
    KTVHCLogDownload(@"%p, Perform HTTP redirection\nresponse : %@\nrequest : %@", self, response, request);
    completionHandler(request);
    [self unlock];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    [self lock];
    KTVHCLogDownload(@"%p, Receive data - Begin\nLength : %lld\nURL : %@", self, (long long)data.length, dataTask.originalRequest.URL.absoluteString);
    id <KTVHCDownloadDelegate> delegate = [self.delegateDictionary objectForKey:dataTask];
    [delegate download:self didReceiveData:data];
    KTVHCLogDownload(@"%p, Receive data - End\nLength : %lld\nURL : %@", self, (long long)data.length, dataTask.originalRequest.URL.absoluteString);
    [self unlock];
}

- (void)lock
{
    if (!self.coreLock)
    {
        self.coreLock = [[NSLock alloc] init];
    }
    [self.coreLock lock];
}

- (void)unlock
{
    [self.coreLock unlock];
}

#pragma mark - Background Task

static UIBackgroundTaskIdentifier backgroundTaskIdentifier = -1;

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    [self cleanBackgroundTask];
    [self lock];
    if (self.delegateDictionary.count > 0)
    {
        backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            [self cleanBackgroundTask];
        }];
        UIBackgroundTaskIdentifier blockIdentifier = backgroundTaskIdentifier;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(300 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (blockIdentifier == backgroundTaskIdentifier)
            {
                [self cleanBackgroundTask];
            }
        });
    }
    [self unlock];
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    [self cleanBackgroundTask];
}

- (void)cleanBackgroundTask
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    });
    if (backgroundTaskIdentifier != UIBackgroundTaskInvalid)
    {
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
        backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    }
}

- (void)cleanBackgroundTaskAsync
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self lock];
        if (self.delegateDictionary.count <= 0)
        {
            [self cleanBackgroundTask];
        }
        [self unlock];
    });
}

@end
