//
//  DBLog.m
//  Dropbox
//
//  Created by Will Stockwell on 11/4/10.
//  Copyright 2010 Dropbox, Inc. All rights reserved.
//

#import "DBLog.h"

static DBLogLevel LogLevel = DBLogLevelWarning;
static DBLogCallback *callback = NULL;

NSString* DBStringFromLogLevel(DBLogLevel logLevel) {
	switch (logLevel) {
		case DBLogLevelInfo: return @"INFO";
		case DBLogLevelAnalytics: return @"ANALYTICS";
		case DBLogLevelWarning: return @"WARNING";
		case DBLogLevelError: return @"ERROR";
		case DBLogLevelFatal: return @"FATAL";
	}
	return @"";	
}

NSString * DBLogFilePath()
{
	static NSString *logFilePath;
	if (logFilePath == nil)
		logFilePath = [[NSHomeDirectory() stringByAppendingFormat: @"/tmp/run.log"] retain];
	return logFilePath;
}

void DBSetupLogToFile()
{
	freopen([DBLogFilePath() fileSystemRepresentation], "w", stderr);
}

static NSString * DBLogFormatPrefix(DBLogLevel logLevel) {
	return [NSString stringWithFormat: @"[%@] ", DBStringFromLogLevel(logLevel)];
}

void DBLogSetLevel(DBLogLevel logLevel) {
	LogLevel = logLevel;
}

void DBLogSetCallback(DBLogCallback *aCallback) {
	callback = aCallback;
}

static void DBLogv(DBLogLevel logLevel, NSString *format, va_list args) {
	if (logLevel >= LogLevel)
	{
		format = [DBLogFormatPrefix(logLevel) stringByAppendingString: format];
		NSLogv(format, args);
		if (callback)
			callback(logLevel, format, args);
	}
}

void DBLog(DBLogLevel logLevel, NSString *format, ...) {
	va_list argptr;
	va_start(argptr,format);
	DBLogv(logLevel, format, argptr);
	va_end(argptr);
}

void DBLogInfo(NSString *format, ...) {
	va_list argptr;
	va_start(argptr,format);
	DBLogv(DBLogLevelInfo, format, argptr);
	va_end(argptr);
}

void DBLogWarning(NSString *format, ...) {
	va_list argptr;
	va_start(argptr,format);
	DBLogv(DBLogLevelWarning, format, argptr);
	va_end(argptr);
}

void DBLogError(NSString *format, ...) {
	va_list argptr;
	va_start(argptr,format);
	DBLogv(DBLogLevelError, format, argptr);
	va_end(argptr);
}

void DBLogFatal(NSString *format, ...) {
	va_list argptr;
	va_start(argptr,format);
	DBLogv(DBLogLevelFatal, format, argptr);
	va_end(argptr);
}

