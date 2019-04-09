//
//  KTVHCLog.h
//  KTVHTTPCache
//
//  Created by Single on 2017/8/17.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  Log Enable Config
 */
#define KTVHCLogEnable(target, console_log_enable, record_log_enable)               \
static BOOL const KTVHCLog_##target##_ConsoleLogEnable = console_log_enable;        \
static BOOL const KTVHCLog_##target##_RecordLogEnable = record_log_enable;

#define KTVHCLogEnableValueConsoleLog(target)       KTVHCLog_##target##_ConsoleLogEnable
#define KTVHCLogEnableValueRecordLog(target)        KTVHCLog_##target##_RecordLogEnable

/**
 *  Common
 */
KTVHCLogEnable(Common,            YES, YES)

/**
 *  HTTP Server
 */
KTVHCLogEnable(HTTPServer,        YES, YES)
KTVHCLogEnable(HTTPConnection,    YES, YES)
KTVHCLogEnable(HTTPResponse,      YES, YES)

/**
 *  Data Storage
 */
KTVHCLogEnable(DataStorage,       YES, YES)
KTVHCLogEnable(DataRequest,       YES, YES)
KTVHCLogEnable(DataResponse,      YES, YES)
KTVHCLogEnable(DataReader,        YES, YES)
KTVHCLogEnable(DataLoader,        YES, YES)

KTVHCLogEnable(DataUnit,          YES, YES)
KTVHCLogEnable(DataUnitItem,      YES, YES)
KTVHCLogEnable(DataUnitPool,      YES, YES)
KTVHCLogEnable(DataUnitQueue,     YES, YES)

KTVHCLogEnable(DataSourceManager, YES, YES)
KTVHCLogEnable(DataFileSource,    YES, YES)
KTVHCLogEnable(DataNetworkSource, YES, YES)

/**
 *  Download
 */
KTVHCLogEnable(Download,          YES, YES)

/**
 *  Alloc & Dealloc
 */
KTVHCLogEnable(Alloc,             YES, YES)
KTVHCLogEnable(Dealloc,           YES, YES)

/**
 *  Log
 */
#define KTVHCLogging(target, console_log_enable, record_log_enable, ...)            \
if (([KTVHCLog log].consoleLogEnable && console_log_enable) || ([KTVHCLog log].recordLogEnable && record_log_enable))       \
{                                                                                   \
    NSString *va_args = [NSString stringWithFormat:__VA_ARGS__];                    \
    NSString *log = [NSString stringWithFormat:@"%@  :   %@", target, va_args];     \
    if ([KTVHCLog log].recordLogEnable && record_log_enable) {                      \
        [[KTVHCLog log] addRecordLog:log];                                          \
    }                                                                               \
    if ([KTVHCLog log].consoleLogEnable && console_log_enable) {                    \
        NSLog(@"%@", log);                                                          \
    }                                                                               \
}


/**
 *  Common
 */
#define KTVHCLogCommon(...)                 KTVHCLogging(@"KTVHCMacro           ", KTVHCLogEnableValueConsoleLog(Common),            KTVHCLogEnableValueRecordLog(Common),            ##__VA_ARGS__)

/**
 *  HTTP Server
 */
#define KTVHCLogHTTPServer(...)             KTVHCLogging(@"KTVHCHTTPServer       ", KTVHCLogEnableValueConsoleLog(HTTPServer),        KTVHCLogEnableValueRecordLog(HTTPServer),        ##__VA_ARGS__)
#define KTVHCLogHTTPConnection(...)         KTVHCLogging(@"KTVHCHTTPConnection   ", KTVHCLogEnableValueConsoleLog(HTTPConnection),    KTVHCLogEnableValueRecordLog(HTTPConnection),    ##__VA_ARGS__)
#define KTVHCLogHTTPResponse(...)           KTVHCLogging(@"KTVHCHTTPResponse     ", KTVHCLogEnableValueConsoleLog(HTTPResponse),      KTVHCLogEnableValueRecordLog(HTTPResponse),      ##__VA_ARGS__)

/**
 *  Data Storage
 */
#define KTVHCLogDataStorage(...)            KTVHCLogging(@"KTVHCDataStorage      ", KTVHCLogEnableValueConsoleLog(DataStorage),       KTVHCLogEnableValueRecordLog(DataStorage),       ##__VA_ARGS__)
#define KTVHCLogDataRequest(...)            KTVHCLogging(@"KTVHCDataRequest      ", KTVHCLogEnableValueConsoleLog(DataRequest),       KTVHCLogEnableValueRecordLog(DataRequest),       ##__VA_ARGS__)
#define KTVHCLogDataResponse(...)           KTVHCLogging(@"KTVHCDataResponse     ", KTVHCLogEnableValueConsoleLog(DataResponse),      KTVHCLogEnableValueRecordLog(DataResponse),      ##__VA_ARGS__)
#define KTVHCLogDataReader(...)             KTVHCLogging(@"KTVHCDataReader       ", KTVHCLogEnableValueConsoleLog(DataReader),        KTVHCLogEnableValueRecordLog(DataReader),        ##__VA_ARGS__)
#define KTVHCLogDataLoader(...)             KTVHCLogging(@"KTVHCDataLoader       ", KTVHCLogEnableValueConsoleLog(DataLoader),        KTVHCLogEnableValueRecordLog(DataLoader),        ##__VA_ARGS__)

#define KTVHCLogDataUnit(...)               KTVHCLogging(@"KTVHCDataUnit         ", KTVHCLogEnableValueConsoleLog(DataUnit),          KTVHCLogEnableValueRecordLog(DataUnit),          ##__VA_ARGS__)
#define KTVHCLogDataUnitItem(...)           KTVHCLogging(@"KTVHCDataUnitItem     ", KTVHCLogEnableValueConsoleLog(DataUnitItem),      KTVHCLogEnableValueRecordLog(DataUnitItem),      ##__VA_ARGS__)
#define KTVHCLogDataUnitPool(...)           KTVHCLogging(@"KTVHCDataUnitPool     ", KTVHCLogEnableValueConsoleLog(DataUnitPool),      KTVHCLogEnableValueRecordLog(DataUnitPool),      ##__VA_ARGS__)
#define KTVHCLogDataUnitQueue(...)          KTVHCLogging(@"KTVHCDataUnitQueue    ", KTVHCLogEnableValueConsoleLog(DataUnitQueue),     KTVHCLogEnableValueRecordLog(DataUnitQueue),     ##__VA_ARGS__)

#define KTVHCLogDataSourceManager(...)      KTVHCLogging(@"KTVHCDataSourceManager", KTVHCLogEnableValueConsoleLog(DataSourceManager), KTVHCLogEnableValueRecordLog(DataSourceManager), ##__VA_ARGS__)
#define KTVHCLogDataFileSource(...)         KTVHCLogging(@"KTVHCDataFileSource   ", KTVHCLogEnableValueConsoleLog(DataFileSource),    KTVHCLogEnableValueRecordLog(DataFileSource),    ##__VA_ARGS__)
#define KTVHCLogDataNetworkSource(...)      KTVHCLogging(@"KTVHCDataNetworkSource", KTVHCLogEnableValueConsoleLog(DataNetworkSource), KTVHCLogEnableValueRecordLog(DataNetworkSource), ##__VA_ARGS__)

/**
 *  Download
 */
#define KTVHCLogDownload(...)               KTVHCLogging(@"KTVHCDownload         ", KTVHCLogEnableValueConsoleLog(Download),          KTVHCLogEnableValueRecordLog(Download),          ##__VA_ARGS__)

/**
 *  Alloc & Dealloc
 */
#define KTVHCLogAlloc(obj)                  KTVHCLogging(obj, KTVHCLogEnableValueConsoleLog(Alloc),   KTVHCLogEnableValueRecordLog(Alloc),   @"alloc")
#define KTVHCLogDealloc(obj)                KTVHCLogging(obj, KTVHCLogEnableValueConsoleLog(Dealloc), KTVHCLogEnableValueRecordLog(Dealloc), @"dealloc")

@interface KTVHCLog : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)log;

/**
 *  DEBUG   : default is NO.
 *  RELEASE : default is NO.
 */
@property (nonatomic) BOOL consoleLogEnable;

/**
 *  DEBUG   : default is NO.
 *  RELEASE : default is NO.
 */
@property (nonatomic) BOOL recordLogEnable;

- (void)addRecordLog:(NSString *)log;

- (NSURL *)recordLogFileURL;
- (void)deleteRecordLogFile;

/**
 *  Error
 */
- (void)addError:(NSError *)error forURL:(NSURL *)URL;
- (NSDictionary<NSURL *, NSError *> *)errors;
- (NSError *)errorForURL:(NSURL *)URL;
- (void)cleanErrorForURL:(NSURL *)URL;

@end
