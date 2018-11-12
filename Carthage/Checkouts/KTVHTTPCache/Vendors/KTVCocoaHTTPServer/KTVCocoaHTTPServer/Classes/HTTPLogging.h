//
//  HTTPLogging.h
//  CocoaHTTPServer
//
//  Created by Single on 2018/5/18.
//  Copyright © 2018年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>

#define KTVCHSLog(level, frmt, ...) [HTTPLogging log:level format:frmt, ##__VA_ARGS__]

#define THIS_FILE   self
#define THIS_METHOD NSStringFromSelector(_cmd)

#define HTTP_LOG_FLAG_ERROR   (1 << 0)
#define HTTP_LOG_FLAG_WARN    (1 << 1)
#define HTTP_LOG_FLAG_INFO    (1 << 2)
#define HTTP_LOG_FLAG_VERBOSE (1 << 3)
#define HTTP_LOG_FLAG_TRACE   (1 << 4)

#define HTTP_LOG_LEVEL_OFF     0
#define HTTP_LOG_LEVEL_ERROR   (HTTP_LOG_LEVEL_OFF   | HTTP_LOG_FLAG_ERROR)
#define HTTP_LOG_LEVEL_WARN    (HTTP_LOG_LEVEL_ERROR | HTTP_LOG_FLAG_WARN)
#define HTTP_LOG_LEVEL_INFO    (HTTP_LOG_LEVEL_WARN  | HTTP_LOG_FLAG_INFO)
#define HTTP_LOG_LEVEL_VERBOSE (HTTP_LOG_LEVEL_INFO  | HTTP_LOG_FLAG_VERBOSE)

#define HTTP_LOG_ERROR   (httpLogLevel & HTTP_LOG_FLAG_ERROR)
#define HTTP_LOG_WARN    (httpLogLevel & HTTP_LOG_FLAG_WARN)
#define HTTP_LOG_INFO    (httpLogLevel & HTTP_LOG_FLAG_INFO)
#define HTTP_LOG_VERBOSE (httpLogLevel & HTTP_LOG_FLAG_VERBOSE)
#define HTTP_LOG_TRACE   (httpLogLevel & HTTP_LOG_FLAG_TRACE)

#define HTTPLogError(frmt, ...)    KTVCHSLog(HTTP_LOG_ERROR,   frmt, ##__VA_ARGS__)
#define HTTPLogWarn(frmt, ...)     KTVCHSLog(HTTP_LOG_WARN,    frmt, ##__VA_ARGS__)
#define HTTPLogInfo(frmt, ...)     KTVCHSLog(HTTP_LOG_INFO,    frmt, ##__VA_ARGS__)
#define HTTPLogVerbose(frmt, ...)  KTVCHSLog(HTTP_LOG_VERBOSE, frmt, ##__VA_ARGS__)
#define HTTPLogTrace()             KTVCHSLog(HTTP_LOG_TRACE,   @"%@ : %@", THIS_FILE, THIS_METHOD)
#define HTTPLogTrace2(frmt, ...)   KTVCHSLog(HTTP_LOG_TRACE,   frmt, ##__VA_ARGS__)


@interface HTTPLogging : NSObject

+ (void)log:(int)level format:(NSString *)format, ...;

@end
