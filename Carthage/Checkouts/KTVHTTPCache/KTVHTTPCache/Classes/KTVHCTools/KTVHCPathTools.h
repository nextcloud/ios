//
//  KTVHCPathTools.h
//  KTVHTTPCache
//
//  Created by Single on 2017/8/12.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KTVHCPathTools : NSObject

+ (NSString *)logPath;
+ (NSString *)archivePath;

+ (NSString *)directoryPathWithURL:(NSURL *)URL;
+ (NSString *)completeFilePathWithURL:(NSURL *)URL;
+ (NSString *)unitItemPathWithURL:(NSURL *)URL offset:(long long)offset;

+ (BOOL)isRelativePath:(NSString *)path;
+ (BOOL)isAbsolutePath:(NSString *)path;

+ (NSString *)relativePathWithAbsoultePath:(NSString *)path;
+ (NSString *)absoultePathWithRelativePath:(NSString *)path;

+ (void)createFileAtPath:(NSString *)path;
+ (void)createDirectoryAtPath:(NSString *)path;

+ (NSError *)deleteFileAtPath:(NSString *)path;
+ (NSError *)deleteDirectoryAtPath:(NSString *)path;

+ (long long)sizeOfItemAtPath:(NSString *)path;

@end
