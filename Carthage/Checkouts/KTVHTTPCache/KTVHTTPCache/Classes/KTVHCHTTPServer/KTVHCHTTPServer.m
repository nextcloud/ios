//
//  KTVHCHTTPServer.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/10.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCHTTPServer.h"
#import "KTVHCHTTPHeader.h"
#import "KTVHCHTTPConnection.h"
#import "KTVHCHTTPURL.h"
#import "KTVHCLog.h"

@interface KTVHCHTTPServer ()

@property (nonatomic, strong) HTTPServer * coreHTTPServer;

@property (nonatomic, assign) BOOL pinging;
@property (nonatomic, assign) BOOL pingResult;
@property (nonatomic, strong) NSCondition * pingCondition;
@property (nonatomic, strong) NSURLSession * pingSession;
@property (nonatomic, strong) NSURLSessionDataTask * pingTask;

@end

@implementation KTVHCHTTPServer

+ (instancetype)server
{
    static KTVHCHTTPServer * obj = nil;
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
    }
    return self;
}

- (void)dealloc
{
    KTVHCLogDealloc(self);
    [self stop];
}

- (BOOL)restart
{
    KTVHCLogHTTPServer(@"%p, Restart connection count : %lld", self, (long long)[self.coreHTTPServer numberOfHTTPConnections]);
    [self.coreHTTPServer stop];
    NSError * error = nil;
    [self.coreHTTPServer start:&error];
    if (error) {
        KTVHCLogHTTPServer(@"%p, Restart server failed : %@", self, error);
    } else {
        KTVHCLogHTTPServer(@"%p, Restart server success", self);
    }
    return error == nil;
}

- (void)start:(NSError * __autoreleasing *)error
{
    self.coreHTTPServer = [[HTTPServer alloc] init];
    [self.coreHTTPServer setConnectionClass:[KTVHCHTTPConnection class]];
    [self.coreHTTPServer setType:@"_http._tcp."];
    NSError * tempError = nil;
    [self.coreHTTPServer start:&tempError];
    if (tempError) {
        * error = tempError;
        KTVHCLogHTTPServer(@"%p, Start server failed : %@", self, tempError);
    } else {
        KTVHCLogHTTPServer(@"%p, Start server success", self);
    }
}

- (void)stop
{
    if (self.running)
    {
        [self.coreHTTPServer stop];
        [self.pingSession invalidateAndCancel];
        [self.pingTask cancel];
        self.pingTask = nil;
        self.pingSession = nil;
        KTVHCLogHTTPServer(@"%p, Stop server", self);
    }
}

- (NSURL *)URLWithOriginalURL:(NSURL *)URL
{
    BOOL success = NO;
    for (int i = 0; i < 2 && !success && self.running && [URL.scheme hasPrefix:@"http"]; i++)
    {
        if (i > 0)
        {
            [self restart];
        }
        success = [self ping];
        KTVHCLogHTTPServer(@"%p, Ping\nsuccess : %d\nindex : %d", self, success, i);
    }
    if (success)
    {
        KTVHCHTTPURL * HCURL = [[KTVHCHTTPURL alloc] initWithOriginalURL:URL];
        URL = [HCURL proxyURLWithPort:self.coreHTTPServer.listeningPort];
    }
    KTVHCLogHTTPServer(@"%p, Return URL\nURL : %@", self, URL);
    return URL;
}

- (BOOL)ping
{
    if (self.running)
    {
        if (!self.pingCondition)
        {
            self.pingCondition = [[NSCondition alloc] init];
        }
        [self.pingCondition lock];
        if (self.pinging)
        {
            [self.pingCondition wait];
        }
        else
        {
            NSURL * pingURL = [[KTVHCHTTPURL pingURL] proxyURLWithPort:self.coreHTTPServer.listeningPort];
            if (!self.pingSession)
            {
                NSURLSessionConfiguration * sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
                sessionConfiguration.timeoutIntervalForRequest = 3;
                self.pingSession = [NSURLSession sessionWithConfiguration:sessionConfiguration];
            }
            self.pingTask = [self.pingSession dataTaskWithURL:pingURL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                [self.pingCondition lock];
                if (!error && data.length > 0) {
                    NSString * pang = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    self.pingResult = [pang isEqualToString:[KTVHCHTTPConnection pingResponseValue]];
                } else {
                    self.pingResult = NO;
                }
                self.pinging = NO;
                [self.pingCondition broadcast];
                [self.pingCondition unlock];
            }];
            self.pinging = YES;
            [self.pingTask resume];
            [self.pingCondition wait];
        }
        [self.pingCondition unlock];
    }
    KTVHCLogHTTPServer(@"%p, Ping result : %d", self, self.pingResult);
    return self.pingResult;
}

- (BOOL)running
{
    return self.coreHTTPServer.isRunning;
}

@end
