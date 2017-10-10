//
//  CCUtility.m
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 02/02/16.
//  Copyright (c) 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "CCUtility.h"
#import "CCGraphics.h"
#import "NCBridgeSwift.h"

#import <netinet/in.h>
#import <openssl/x509.h>
#import <openssl/bio.h>
#import <openssl/err.h>
#import <openssl/pem.h>

@implementation CCUtility

#pragma --------------------------------------------------------------------------------------------
#pragma mark ======================= KeyChainStore ==================================
#pragma --------------------------------------------------------------------------------------------

+ (void)deleteAllChainStore
{
    [UICKeyChainStore removeAllItems];
    [UICKeyChainStore removeAllItemsForService:k_serviceShareKeyChain];
}

+ (void)storeAllChainInService
{
    UICKeyChainStore *store = [UICKeyChainStore keyChainStore];
    
    NSArray *items = store.allItems;
    
    for (NSDictionary *item in items) {
        
        [UICKeyChainStore setString:[item objectForKey:@"value"] forKey:[item objectForKey:@"key"] service:k_serviceShareKeyChain];
        [UICKeyChainStore removeItemForKey:[item objectForKey:@"key"]];
    }
}

#pragma ------------------------------ ADMIN

+ (void)adminRemoveIntro
{
    NSString *version = [self getVersion];
    [UICKeyChainStore setString:nil forKey:version service:k_serviceShareKeyChain];
}

+ (void)adminRemovePasscode
{
    NSString *uuid = [self getUUID];
    [UICKeyChainStore setString:nil forKey:uuid service:k_serviceShareKeyChain];
}

+ (void)adminRemoveVersion
{
    [UICKeyChainStore setString:@"0.0" forKey:@"version" service:k_serviceShareKeyChain];
}

#pragma ------------------------------ SET

+ (void)setKeyChainPasscodeForUUID:(NSString *)uuid conPasscode:(NSString *)passcode
{
    [UICKeyChainStore setString:passcode forKey:uuid service:k_serviceShareKeyChain];
}

+ (NSString *)setVersion
{
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    
    [UICKeyChainStore setString:version forKey:@"version" service:k_serviceShareKeyChain];
    
    return version;
}

+ (NSString *)setBuild
{
    NSString *build = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    
    [UICKeyChainStore setString:build forKey:@"build" service:k_serviceShareKeyChain];
    
    return build;
}

+ (void)setBlockCode:(NSString *)blockcode
{
    [UICKeyChainStore setString:blockcode forKey:@"blockcode" service:k_serviceShareKeyChain];
}

+ (void)setSimplyBlockCode:(BOOL)simply
{
    NSString *sSimply = (simply) ? @"true" : @"false";
    [UICKeyChainStore setString:sSimply forKey:@"simplyblockcode" service:k_serviceShareKeyChain];
}

+ (void)setOnlyLockDir:(BOOL)lockDir
{
    NSString *sLockDir = (lockDir) ? @"true" : @"false";
    [UICKeyChainStore setString:sLockDir forKey:@"onlylockdir" service:k_serviceShareKeyChain];
}

+ (void)setOptimizedPhoto:(BOOL)resize
{
    NSString *sOptimizedPhoto = (resize) ? @"true" : @"false";
    [UICKeyChainStore setString:sOptimizedPhoto forKey:@"optimizedphoto" service:k_serviceShareKeyChain];
}

+ (void)setUploadAndRemovePhoto:(BOOL)remove
{
    NSString *sRemovePhoto = (remove) ? @"true" : @"false";
    [UICKeyChainStore setString:sRemovePhoto forKey:@"uploadremovephoto" service:k_serviceShareKeyChain];
}

+ (void)setOrderSettings:(NSString *)order
{
    [UICKeyChainStore setString:order forKey:@"order" service:k_serviceShareKeyChain];
}

+ (void)setAscendingSettings:(BOOL)ascendente
{
    NSString *sAscendente = (ascendente) ? @"true" : @"false";
    [UICKeyChainStore setString:sAscendente forKey:@"ascending" service:k_serviceShareKeyChain];
}

+ (void)setGroupBySettings:(NSString *)groupby
{
    [UICKeyChainStore setString:groupby forKey:@"groupby" service:k_serviceShareKeyChain];
}

+ (void)setIntro:(NSString *)version
{
    [UICKeyChainStore setString:@"true" forKey:version service:k_serviceShareKeyChain];
}

+ (void)setActiveAccountExt:(NSString *)activeAccount
{
    [UICKeyChainStore setString:activeAccount forKey:@"activeAccountExt" service:k_serviceShareKeyChain];
}

+ (void)setServerUrlExt:(NSString *)serverUrl
{
    [UICKeyChainStore setString:serverUrl forKey:@"serverUrlExt" service:k_serviceShareKeyChain];
}

+ (void)setTitleServerUrlExt:(NSString *)titleServerUrl
{
    [UICKeyChainStore setString:titleServerUrl forKey:@"titleServerUrlExt" service:k_serviceShareKeyChain];
}

+ (void)setFileNameExt:(NSString *)fileName
{
    [UICKeyChainStore setString:fileName forKey:@"fileNameExt" service:k_serviceShareKeyChain];
}

+ (void)setEmail:(NSString *)email
{
    [UICKeyChainStore setString:email forKey:@"email" service:k_serviceShareKeyChain];
}

+ (void)setHint:(NSString *)hint
{
    [UICKeyChainStore setString:hint forKey:@"hint" service:k_serviceShareKeyChain];
}

+ (void)setDirectoryOnTop:(BOOL)directoryOnTop
{
    NSString *sDirectoryOnTop = (directoryOnTop) ? @"true" : @"false";
    [UICKeyChainStore setString:sDirectoryOnTop forKey:@"directoryOnTop" service:k_serviceShareKeyChain];
}

+ (void)setFileNameMask:(NSString *)mask key:(NSString *)key
{
    [UICKeyChainStore setString:mask forKey:key service:k_serviceShareKeyChain];
}

+ (void)setFileNameType:(BOOL)prefix key:(NSString *)key
{
    NSString *sPrefix = (prefix) ? @"true" : @"false";
    [UICKeyChainStore setString:sPrefix forKey:key service:k_serviceShareKeyChain];
}

+ (void)setCreateMenuEncrypted:(BOOL)encrypted
{
    NSString *sEncrypted = (encrypted) ? @"true" : @"false";
    [UICKeyChainStore setString:sEncrypted forKey:@"createMenuEncrypted" service:k_serviceShareKeyChain];
}

+ (void)setFavoriteOffline:(BOOL)offline
{
    NSString *sFavoriteOffline = (offline) ? @"true" : @"false";
    [UICKeyChainStore setString:sFavoriteOffline forKey:@"favoriteOffline" service:k_serviceShareKeyChain];
}

+ (void)setActivityVerboseHigh:(BOOL)high
{
    NSString *sHigh = (high) ? @"true" : @"false";
    [UICKeyChainStore setString:sHigh forKey:@"activityVerboseHigh" service:k_serviceShareKeyChain];
}

+ (void)setShowHiddenFiles:(BOOL)show
{
    NSString *sShow = (show) ? @"true" : @"false";
    [UICKeyChainStore setString:sShow forKey:@"showHiddenFiles" service:k_serviceShareKeyChain];
}

#pragma ------------------------------ GET

+ (NSString *)getKeyChainPasscodeForUUID:(NSString *)uuid
{
    if (!uuid) return @"";
    
    NSString *passcode = [UICKeyChainStore stringForKey:uuid service:k_serviceShareKeyChain];
    
    if (!passcode)
        passcode = @"";
    
    return passcode;
}

+ (NSString *)getUUID
{
#if TARGET_IPHONE_SIMULATOR
    NSUUID *deviceId = [[NSUUID alloc]initWithUUIDString:k_UUID_SIM];
    return [deviceId UUIDString];
#else
    NSString *uuid = [[UIDevice currentDevice] identifierForVendor].UUIDString;
    return uuid;
#endif
}

+ (NSString *)getVersion
{
    return [UICKeyChainStore stringForKey:@"version" service:k_serviceShareKeyChain];
}

+ (NSString *)getBuild
{
    return [UICKeyChainStore stringForKey:@"build" service:k_serviceShareKeyChain];
}

+ (NSString *)getBlockCode
{
    return [UICKeyChainStore stringForKey:@"blockcode" service:k_serviceShareKeyChain];
}

+ (BOOL)getSimplyBlockCode
{
    NSString *simplyBlockCode = [UICKeyChainStore stringForKey:@"simplyblockcode" service:k_serviceShareKeyChain];
    
    if (simplyBlockCode == nil) {
        
        [self setSimplyBlockCode:YES];
        return YES;
    }
    
    return [simplyBlockCode boolValue];
}

+ (BOOL)getOnlyLockDir
{
    return [[UICKeyChainStore stringForKey:@"onlylockdir" service:k_serviceShareKeyChain] boolValue];
}

+ (BOOL)getOptimizedPhoto
{
    return [[UICKeyChainStore stringForKey:@"optimizedphoto" service:k_serviceShareKeyChain] boolValue];
}

+ (BOOL)getUploadAndRemovePhoto
{
    return [[UICKeyChainStore stringForKey:@"uploadremovephoto" service:k_serviceShareKeyChain] boolValue];
}

+ (NSString *)getOrderSettings
{
    NSString *order = [UICKeyChainStore stringForKey:@"order" service:k_serviceShareKeyChain];
    
    if (order == nil) {
        
        [self setOrderSettings:@"fileName"];
        return @"fileName";
    }
    
    return order;
}

+ (BOOL)getAscendingSettings
{
    NSString *ascending = [UICKeyChainStore stringForKey:@"ascending" service:k_serviceShareKeyChain];
    
    if (ascending == nil) {
        
        [self setAscendingSettings:YES];
        return YES;
    }
    
    return [ascending boolValue];
}

+ (NSString *)getGroupBySettings
{
    NSString *groupby = [UICKeyChainStore stringForKey:@"groupby" service:k_serviceShareKeyChain];
    
    if (groupby == nil) {
        
        [self setGroupBySettings:@"none"];
        return @"none";
    }
    
    return groupby;
}

+ (BOOL)getIntro:(NSString *)version
{
    return [[UICKeyChainStore stringForKey:version service:k_serviceShareKeyChain] boolValue];
}

+ (NSString *)getIncrementalNumber
{
    long number = [[UICKeyChainStore stringForKey:@"incrementalnumber" service:k_serviceShareKeyChain] intValue];
    
    number++;
    if (number >= 9999) number = 1;
    
    [UICKeyChainStore setString:[NSString stringWithFormat:@"%ld", number] forKey:@"incrementalnumber"];
    
    return [NSString stringWithFormat:@"%04ld", number];
}

+ (NSString *)getActiveAccountExt
{
    return [UICKeyChainStore stringForKey:@"activeAccountExt" service:k_serviceShareKeyChain];
}

+ (NSString *)getServerUrlExt
{
    return [UICKeyChainStore stringForKey:@"serverUrlExt" service:k_serviceShareKeyChain];
}

+ (NSString *)getTitleServerUrlExt
{
    return [UICKeyChainStore stringForKey:@"titleServerUrlExt" service:k_serviceShareKeyChain];
}

+ (NSString *)getFileNameExt
{
    return [UICKeyChainStore stringForKey:@"fileNameExt" service:k_serviceShareKeyChain];
}

+ (NSString *)getEmail
{
    return [UICKeyChainStore stringForKey:@"email" service:k_serviceShareKeyChain];
}

+ (NSString *)getHint
{
    return [UICKeyChainStore stringForKey:@"hint" service:k_serviceShareKeyChain];
}

+ (BOOL)getDirectoryOnTop
{
    return [[UICKeyChainStore stringForKey:@"directoryOnTop" service:k_serviceShareKeyChain] boolValue];
}

+ (NSString *)getFileNameMask:(NSString *)key
{
    NSString *mask = [UICKeyChainStore stringForKey:key service:k_serviceShareKeyChain];
    
    if (mask == nil)
        mask = @"";
        
    return mask;
}

+ (BOOL)getFileNameType:(NSString *)key
{
    return [[UICKeyChainStore stringForKey:key service:k_serviceShareKeyChain] boolValue];
}

+ (BOOL)getCreateMenuEncrypted
{
    return [[UICKeyChainStore stringForKey:@"createMenuEncrypted" service:k_serviceShareKeyChain] boolValue];
}

+ (BOOL)getFavoriteOffline
{
    return [[UICKeyChainStore stringForKey:@"favoriteOffline" service:k_serviceShareKeyChain] boolValue];
}

+ (BOOL)getActivityVerboseHigh
{
    return [[UICKeyChainStore stringForKey:@"activityVerboseHigh" service:k_serviceShareKeyChain] boolValue];
}

+ (BOOL)getShowHiddenFiles
{
    return [[UICKeyChainStore stringForKey:@"showHiddenFiles" service:k_serviceShareKeyChain] boolValue];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Varius =====
#pragma --------------------------------------------------------------------------------------------

+ (NSString *)getUserAgent
{
    NSString *appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    
    return [NSString stringWithFormat:@"%@%@",@"Mozilla/5.0 (iOS) Nextcloud-iOS/",appVersion];
}

+ (NSString *)dateDiff:(NSDate *) convertedDate
{
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setFormatterBehavior:NSDateFormatterBehavior10_4];
    [df setDateFormat:@"EEE, dd MMM yy HH:mm:ss VVVV"];
    //NSDate *convertedDate = [df dateFromString:origDate];
    //NSDate *convertedDate = [NSDate dateWithTimeIntervalSince1970:origDate];
    NSDate *todayDate = [NSDate date];
    double ti = [convertedDate timeIntervalSinceDate:todayDate];
    ti = ti * -1;
    if (ti < 60) {
        return NSLocalizedString(@"_less_a_minute_", nil);
    } else if (ti < 3600) {
        int diff = round(ti / 60);
        return [NSString stringWithFormat:NSLocalizedString(@"_minutes_ago_", nil), diff];
    } else if (ti < 86400) {
        int diff = round(ti / 60 / 60);
        return[NSString stringWithFormat:NSLocalizedString(@"_hours_ago_", nil), diff];
    } else if (ti < 2629743) {
        int diff = round(ti / 60 / 60 / 24);
        return[NSString stringWithFormat:NSLocalizedString(@"_days_ago_", nil), diff];
    } else {
        return NSLocalizedString(@"_over_30_days_", nil);
    }
}


+ (NSDate *)dateEnUsPosixFromCloud:(NSString *)dateString
{
    NSDate *date = [NSDate date];
    NSError *error;
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    [dateFormatter setLocale:enUSPOSIXLocale];
    [dateFormatter setDateFormat:@"EEE, dd MMM y HH:mm:ss zzz"];

    if (![dateFormatter getObjectValue:&date forString:dateString range:nil error:&error]) {
        NSLog(@"Date '%@' could not be parsed: %@", dateString, error);
        date = [NSDate date];
    }

    return date;
}

+ (NSString *)transformedSize:(double)value
{
    int multiplicationFactor = 0;
    NSArray *tokens = [NSArray arrayWithObjects:@"bytes",@"KB",@"MB",@"GB",@"TB",nil];
    while (value > 1024 && multiplicationFactor < tokens.count - 1) {
        value /= 1024;
        multiplicationFactor++;
    }
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setMaximumFractionDigits:2];
    return [NSString stringWithFormat:@"%@ %@", [formatter stringFromNumber:[NSNumber numberWithDouble:value]], [tokens objectAtIndex:multiplicationFactor]];
}

// Remove do not forbidden characters for Nextcloud Server
+ (NSString *)removeForbiddenCharactersServer:(NSString *)fileName
{
    NSArray *arrayForbiddenCharacters = [NSArray arrayWithObjects:@"/", nil];
    
    for (NSString *currentCharacter in arrayForbiddenCharacters) {
        fileName = [fileName stringByReplacingOccurrencesOfString:currentCharacter withString:@""];
    }
    
    return fileName;
}

// Remove do not forbidden characters for File System Server
+ (NSString *)removeForbiddenCharactersFileSystem:(NSString *)fileName
{
    NSArray *arrayForbiddenCharacters = [NSArray arrayWithObjects:@"\\",@"<",@">",@":",@"\"",@"|",@"?",@"*",@"/", nil];
    
    for (NSString *currentCharacter in arrayForbiddenCharacters) {
        fileName = [fileName stringByReplacingOccurrencesOfString:currentCharacter withString:@""];
    }
    
    return fileName;
}

+ (NSString*)stringAppendServerUrl:(NSString *)serverUrl addFileName:(NSString *)addFileName
{
    NSString *result;
    
    if (serverUrl == nil || addFileName == nil) return nil;
    if ([addFileName isEqualToString:@""]) return serverUrl;
    
    if ([serverUrl isEqualToString:@"/"]) result = [serverUrl stringByAppendingString:addFileName];
    else result = [NSString stringWithFormat:@"%@/%@", serverUrl, addFileName];
    
    return result;
}

+ (NSString *)createRandomString:(int)numChars
{
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *randomString = [NSMutableString stringWithCapacity: numChars];
    
    for (int i=0; i < numChars; i++) {
        [randomString appendFormat: @"%C", [letters characterAtIndex: arc4random_uniform((unsigned int)[letters length]) % [letters length]]];
    }
    
    return [NSString stringWithFormat:@"%@", randomString];
}

+ (NSString *)createFileName:fileName fileDate:(NSDate *)fileDate fileType:(PHAssetMediaType)fileType keyFileName:(NSString *)keyFileName keyFileNameType:(NSString *)keyFileNameType
{
    BOOL addFileNameType = NO;
    
    NSString *numberFileName;
    if ([fileName length] > 8) numberFileName = [fileName substringWithRange:NSMakeRange(04, 04)];
    else numberFileName = [CCUtility getIncrementalNumber];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yy-MM-dd HH-mm-ss"];
    NSString *fileNameDate = [formatter stringFromDate:fileDate];
    
    NSString *fileNameType = @"";
    if (fileType == PHAssetMediaTypeImage)
        fileNameType = NSLocalizedString(@"_photo_", nil);
    if (fileType == PHAssetMediaTypeVideo)
        fileNameType = NSLocalizedString(@"_video_", nil);
    if (fileType == PHAssetMediaTypeAudio)
        fileNameType = NSLocalizedString(@"_audio_", nil);
    if (fileType == PHAssetMediaTypeUnknown)
        fileNameType = NSLocalizedString(@"_unknown_", nil);

    // Use File Name Type
    if (keyFileNameType)
        addFileNameType = [CCUtility getFileNameType:keyFileNameType];
    
    NSString *fileNameExt = [[fileName pathExtension] lowercaseString];
    
    if (keyFileName) {
        
        fileName = [CCUtility getFileNameMask:keyFileName];
        
        if ([fileName length] > 0) {
            
            [formatter setDateFormat:@"dd"];
            NSString *dayNumber = [formatter stringFromDate:fileDate];
            [formatter setDateFormat:@"MMM"];
            NSString *month = [formatter stringFromDate:fileDate];
            [formatter setDateFormat:@"MM"];
            NSString *monthNumber = [formatter stringFromDate:fileDate];
            [formatter setDateFormat:@"yyyy"];
            NSString *year = [formatter stringFromDate:fileDate];
            [formatter setDateFormat:@"yy"];
            NSString *yearNumber = [formatter stringFromDate:fileDate];
            [formatter setDateFormat:@"HH"];
            NSString *hour24 = [formatter stringFromDate:fileDate];
            [formatter setDateFormat:@"hh"];
            NSString *hour12 = [formatter stringFromDate:fileDate];
            [formatter setDateFormat:@"mm"];
            NSString *minute = [formatter stringFromDate:fileDate];
            [formatter setDateFormat:@"ss"];
            NSString *second = [formatter stringFromDate:fileDate];
            [formatter setDateFormat:@"a"];
            NSString *ampm = [formatter stringFromDate:fileDate];
            
            // Replace string with date

            fileName = [fileName stringByReplacingOccurrencesOfString:@"DD" withString:dayNumber];
            fileName = [fileName stringByReplacingOccurrencesOfString:@"MMM" withString:month];
            fileName = [fileName stringByReplacingOccurrencesOfString:@"MM" withString:monthNumber];
            fileName = [fileName stringByReplacingOccurrencesOfString:@"YYYY" withString:year];
            fileName = [fileName stringByReplacingOccurrencesOfString:@"YY" withString:yearNumber];

            fileName = [fileName stringByReplacingOccurrencesOfString:@"HH" withString:hour24];
            fileName = [fileName stringByReplacingOccurrencesOfString:@"hh" withString:hour12];
            fileName = [fileName stringByReplacingOccurrencesOfString:@"mm" withString:minute];
            fileName = [fileName stringByReplacingOccurrencesOfString:@"ss" withString:second];
            fileName = [fileName stringByReplacingOccurrencesOfString:@"ampm" withString:ampm];

            if (addFileNameType)
                fileName = [NSString stringWithFormat:@"%@ %@-%@.%@", fileNameType, fileName, numberFileName, fileNameExt];
            else
                fileName = [NSString stringWithFormat:@"%@-%@.%@", fileName, numberFileName, fileNameExt];
            
        } else {
            
            if (addFileNameType)
                fileName = [NSString stringWithFormat:@"%@ %@ %@.%@", fileNameType, fileNameDate, numberFileName, fileNameExt];
            else
                fileName = [NSString stringWithFormat:@"%@ %@.%@", fileNameDate, numberFileName, fileNameExt];
        }
        
    } else {
        
        if (addFileNameType)
            fileName = [NSString stringWithFormat:@"%@ %@ %@.%@", fileNameType, fileNameDate, numberFileName, fileNameExt];
        else
            fileName = [NSString stringWithFormat:@"%@ %@.%@", fileNameDate, numberFileName, fileNameExt];

    }
    
    return fileName;
}

+ (NSString *)getHomeServerUrlActiveUrl:(NSString *)activeUrl
{
    if (activeUrl == nil) return nil;
    
    return [activeUrl stringByAppendingString:webDAV];
}

// Return path of User
+ (NSString *)getDirectoryActiveUser:(NSString *)activeUser activeUrl:(NSString *)activeUrl
{
    NSURL *dirGroup = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[NCBrandOptions sharedInstance].capabilitiesGroups];
    NSString *user = activeUser;
    NSString *baseUrl = [activeUrl lowercaseString];
    NSString *dirUserBaseUrl = nil;
    NSString *dirApplicationUserGroup = nil;
    
    if ([user length] && [baseUrl length]) {
        
        if ([baseUrl hasPrefix:@"https://"]) baseUrl = [baseUrl substringFromIndex:8];
        if ([baseUrl hasPrefix:@"http://"]) baseUrl = [baseUrl substringFromIndex:7];
        
        dirUserBaseUrl = [NSString stringWithFormat:@"%@-%@", user, baseUrl];
        dirUserBaseUrl = [[self removeForbiddenCharactersFileSystem:dirUserBaseUrl] lowercaseString];
    } else return @"";
    
    dirApplicationUserGroup = [[dirGroup URLByAppendingPathComponent:appApplicationSupport] path];
    dirUserBaseUrl = [NSString stringWithFormat:@"%@/%@", dirApplicationUserGroup, dirUserBaseUrl];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath: dirUserBaseUrl]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:dirUserBaseUrl withIntermediateDirectories:YES attributes:nil error:nil];
    }
        
    return dirUserBaseUrl;
}

+ (NSString *)getOLDDirectoryActiveUser:(NSString *)activeUser activeUrl:(NSString *)activeUrl
{
    NSString *user = activeUser;
    NSString *baseUrl = [activeUrl lowercaseString];
    NSString *dirUserBaseUrl = nil;
    
    if ([user length] && [baseUrl length]) {
        
        if ([baseUrl hasPrefix:@"https://"]) baseUrl = [baseUrl substringFromIndex:8];
        if ([baseUrl hasPrefix:@"http://"]) baseUrl = [baseUrl substringFromIndex:7];
        
        dirUserBaseUrl = [NSString stringWithFormat:@"%@-%@", user, baseUrl];
        dirUserBaseUrl = [[self removeForbiddenCharactersFileSystem:dirUserBaseUrl] lowercaseString];
    } else return @"";
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    dirUserBaseUrl = [NSString stringWithFormat:@"%@/%@", [paths objectAtIndex:0], dirUserBaseUrl];
    
    return dirUserBaseUrl;
}

// Return the path of directory Local -> NSDocumentDirectory
+ (NSString *)getDirectoryLocal
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    return [paths objectAtIndex:0];
}

// Return the path of directory Audio
+ (NSString *)getDirectoryAudio
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    
    return [NSString stringWithFormat:@"%@/%@", [paths objectAtIndex:0], @"audio"];
}

// Return the path of directory Cetificates
+ (NSString *)getDirectoryCerificates
{
    NSURL *dirGroup = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[NCBrandOptions sharedInstance].capabilitiesGroups];
    
    NSString *dir = [[dirGroup URLByAppendingPathComponent:appCertificates] path];
    if (![[NSFileManager defaultManager] fileExistsAtPath:dir])
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    
    return dir;
}

+ (NSString *)getTitleSectionDate:(NSDate *)date
{
    NSString * title;
    
    if ([date isEqualToDate:[CCUtility datetimeWithOutTime:[NSDate distantPast]]]) {
        
        title =  NSLocalizedString(@"_no_date_", nil);
        
    } else {
        
        title = [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterFullStyle timeStyle:0];
        
        if ([date isEqualToDate:[CCUtility datetimeWithOutTime:[NSDate date]]])
            title = [NSString stringWithFormat:NSLocalizedString(@"_today_", nil)];
    }
    
    return title;
}

+ (void)moveFileAtPath:(NSString *)atPath toPath:(NSString *)toPath
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:atPath]) {
        
        [[NSFileManager defaultManager] removeItemAtPath:toPath error:nil];
        [[NSFileManager defaultManager] copyItemAtPath:atPath toPath:toPath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:atPath error:nil];
    }
}

+ (void)copyFileAtPath:(NSString *)atPath toPath:(NSString *)toPath
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:atPath]) {
        
        [[NSFileManager defaultManager] removeItemAtPath:toPath error:nil];
        [[NSFileManager defaultManager] copyItemAtPath:atPath toPath:toPath error:nil];
    }
}

+ (void)removeAllFileID_UPLOAD_ActiveUser:(NSString *)activeUser activeUrl:(NSString *)activeUrl
{
    NSString *file;
    NSString *dir;
    
    dir = [self getDirectoryActiveUser:activeUser activeUrl:activeUrl];
    
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:dir];
    
    while (file = [enumerator nextObject]) {
        
        if ([file rangeOfString:@"ID_UPLOAD_"].location != NSNotFound)
            [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", dir, file] error:nil];
    }
}

+ (NSString *)deletingLastPathComponentFromServerUrl:(NSString *)serverUrl
{
    //NSURL *url = [[NSURL URLWithString:[serverUrl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]] URLByDeletingLastPathComponent]; DEPRECATED iOS9
    
    NSURL *url = [[NSURL URLWithString:[serverUrl stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLFragmentAllowedCharacterSet]]] URLByDeletingLastPathComponent];
    
    NSString *pather = [[url absoluteString] stringByRemovingPercentEncoding];
    
    return [pather substringToIndex: [pather length] - 1];
}

+ (NSString *)returnFileNamePathFromFileName:(NSString *)metadataFileName serverUrl:(NSString *)serverUrl activeUrl:(NSString *)activeUrl
{
    NSString *fileName = [NSString stringWithFormat:@"%@/%@", [serverUrl stringByReplacingOccurrencesOfString:[CCUtility getHomeServerUrlActiveUrl:activeUrl] withString:@""], metadataFileName];
    
    if ([fileName hasPrefix:@"/"]) fileName = [fileName substringFromIndex:1];
    
    return fileName;
}

+ (void)sendMailEncryptPass:(NSString *)recipient validateEmail:(BOOL)validateEmail form:(id)form nameImage:(NSString *)nameImage
{
    BOOL error = NO;
    
    if (validateEmail)
        error = ![self isValidEmail:recipient];
    
    if (!error)
        error = ![MFMailComposeViewController canSendMail];
    
    if (!error) {
        
        NSString *key = [CCUtility getKeyChainPasscodeForUUID:[CCUtility getUUID]];
        
        MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
        mc.mailComposeDelegate = form;
        
        [mc setSubject:NSLocalizedString(@"_title_mail_encryptpass_", nil)];
        
        NSString *htmlMsg =[NSString stringWithFormat:@"<html><body><p>%@ : %@ , %@</p></body></html>", NSLocalizedString(@"_text1_mail_encryptpass_", nil), key, NSLocalizedString(@"_text2_mail_encryptpass_", nil)];
        
        NSData *jpegData = UIImageJPEGRepresentation([UIImage imageNamed:nameImage], 1.0);
        [mc addAttachmentData:jpegData mimeType:@"image/jpeg" fileName:@"cryptocloud.png"];
        [mc setMessageBody:htmlMsg isHTML:YES];
        
        if ([self isValidEmail:recipient])
            [mc setToRecipients:@[recipient]];
        
        [form presentViewController:mc animated:YES completion:NULL];
        
    } else {
        
        UIAlertController * alert= [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_error_", nil) message:NSLocalizedString(@"_mail_not_can_send_mail_", nil) preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil)  style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * action) {
                                                       [alert dismissViewControllerAnimated:YES completion:nil];
                                                   }];
        [alert addAction:ok];
        [form presentViewController:alert animated:YES completion:nil];
    }
}

+ (NSArray *)createNameSubFolder:(PHFetchResult *)alassets
{
    NSMutableOrderedSet *datesSubFolder = [NSMutableOrderedSet new];
    
    for (PHAsset *asset in alassets) {
        
        NSDate *assetDate = asset.creationDate;
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy"];
        NSString *yearString = [formatter stringFromDate:assetDate];
        if (yearString)
            [datesSubFolder addObject:yearString];
        
        [formatter setDateFormat:@"MM"];
        NSString *monthString = [formatter stringFromDate:assetDate];
        monthString = [NSString stringWithFormat:@"%@/%@", yearString, monthString];
        if (monthString)
            [datesSubFolder addObject:monthString];
    }
    
    return (NSArray *)datesSubFolder;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== CCMetadata =====
#pragma --------------------------------------------------------------------------------------------

+ (tableMetadata *)createMetadataWithAccount:(NSString *)account date:(NSDate *)date directory:(BOOL)directory fileID:(NSString *)fileID directoryID:(NSString *)directoryID fileName:(NSString *)fileName etag:(NSString *)etag size:(double)size status:(double)status
{
    tableMetadata *metadata = [tableMetadata new];
    
    metadata.account = account;
    metadata.date = date;
    metadata.directory = directory;
    metadata.directoryID = directoryID;
    metadata.etag = etag;
    metadata.fileID = fileID;
    metadata.fileName = fileName;
    metadata.size = size;
    metadata.status = status;
    
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:directoryID];
    NSString *autoUploadFileName = [[NCManageDatabase sharedInstance] getAccountAutoUploadFileName];
    NSString *autoUploadDirectory = [[NCManageDatabase sharedInstance] getAccountAutoUploadDirectory:serverUrl];
    
    [self insertTypeFileIconName:metadata serverUrl:serverUrl autoUploadFileName:autoUploadFileName autoUploadDirectory:autoUploadDirectory];
    
    return metadata;
}

+ (tableMetadata *)trasformedOCFileToCCMetadata:(OCFileDto *)itemDto fileName:(NSString *)fileName serverUrl:(NSString *)serverUrl directoryID:(NSString *)directoryID autoUploadFileName:(NSString *)autoUploadFileName autoUploadDirectory:(NSString *)autoUploadDirectory activeAccount:(NSString *)activeAccount directoryUser:(NSString *)directoryUser
{
    tableMetadata *metadata = [tableMetadata new];
    
    fileName = [CCUtility removeForbiddenCharactersServer:fileName];
    
    metadata.account = activeAccount;
    metadata.date = [NSDate dateWithTimeIntervalSince1970:itemDto.date];
    metadata.directory = itemDto.isDirectory;
    metadata.favorite = itemDto.isFavorite;
    metadata.fileID = itemDto.ocId;
    metadata.directoryID = directoryID;
    metadata.fileName = fileName;
    metadata.iconName = @"";
    metadata.permissions = itemDto.permissions;
    metadata.etag = itemDto.etag;
    metadata.size = itemDto.size;
    metadata.sessionTaskIdentifier = k_taskIdentifierDone;
    metadata.typeFile = @"";
    
    [self insertTypeFileIconName:metadata serverUrl:serverUrl autoUploadFileName:autoUploadFileName autoUploadDirectory:autoUploadDirectory];
    
    return metadata;
}

+ (tableMetadata *)insertTypeFileIconName:(tableMetadata *)metadata serverUrl:(NSString *)serverUrl autoUploadFileName:(NSString *)autoUploadFileName autoUploadDirectory:(NSString *)autoUploadDirectory
{
    if ([metadata.fileName isEqualToString:@"."]) {
        
        metadata.typeFile = k_metadataTypeFile_unknown;
        metadata.iconName = @"file";
        
    } else if (!metadata.directory) {
        
        CFStringRef fileExtension = (__bridge CFStringRef)[metadata.fileName pathExtension];
        CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension, NULL);
        NSString *ext = (__bridge NSString *)fileExtension;
        ext = ext.uppercaseString;
        
        // thumbnailExists
            
        if([ext isEqualToString:@"JPG"] || [ext isEqualToString:@"PNG"] || [ext isEqualToString:@"JPEG"] || [ext isEqualToString:@"GIF"] || [ext isEqualToString:@"BMP"] || [ext isEqualToString:@"MP3"]  || [ext isEqualToString:@"MOV"]  || [ext isEqualToString:@"MP4"]  || [ext isEqualToString:@"M4V"] || [ext isEqualToString:@"3GP"])
            metadata.thumbnailExists = YES;
        else
            metadata.thumbnailExists = NO;
        
        // Type compress
        if (UTTypeConformsTo(fileUTI, kUTTypeZipArchive) && [(__bridge NSString *)fileUTI containsString:@"org.openxmlformats"] == NO && [(__bridge NSString *)fileUTI containsString:@"oasis"] == NO) {
            metadata.typeFile = k_metadataTypeFile_compress;
            metadata.iconName = @"file_compress";
        }
        // Type image
        else if (UTTypeConformsTo(fileUTI, kUTTypeImage)) {
            metadata.typeFile = k_metadataTypeFile_image;
            metadata.iconName = @"file_photo";
        }
        // Type Video
        else if (UTTypeConformsTo(fileUTI, kUTTypeMovie)) {
            metadata.typeFile = k_metadataTypeFile_video;
            metadata.iconName = @"file_movie";
        }
        // Type Audio
        else if (UTTypeConformsTo(fileUTI, kUTTypeAudio)) {
            metadata.typeFile = k_metadataTypeFile_audio;
            metadata.iconName = @"file_audio";
        }
        // Type Document [DOC] [PDF] [XLS] [TXT] (RTF = "public.rtf" - ODT = "org.oasis-open.opendocument.text") [MD]
        else if (UTTypeConformsTo(fileUTI, kUTTypeContent) || [ext isEqualToString:@"MD"]) {
            
            metadata.typeFile = k_metadataTypeFile_document;
            metadata.iconName = @"document";
            
            NSString *typeFile = (__bridge NSString *)fileUTI;
            
            if ([typeFile isEqualToString:@"com.adobe.pdf"]) {
                metadata.iconName = @"file_pdf";
            }
            
            if ([typeFile isEqualToString:@"org.openxmlformats.spreadsheetml.sheet"]) {
                metadata.iconName = @"file_xls";
            }
            
            if ([typeFile isEqualToString:@"com.microsoft.excel.xls"]) {
                metadata.iconName = @"file_xls";
            }
            
            if ([typeFile isEqualToString:@"public.plain-text"] || [ext isEqualToString:@"MD"]) {
                metadata.iconName = @"file_txt";
            }
            
            if ([typeFile isEqualToString:@"public.html"]) {
                metadata.iconName = @"file_code";
            }
            
        } else {
            
            // Type unknown
            metadata.typeFile = k_metadataTypeFile_unknown;
            
            // icon uTorrent
            if ([ext isEqualToString:@"TORRENT"]) {
                
                metadata.iconName = @"utorrent";
                
            } else {
            
                metadata.iconName = @"file";
            }
        }
        
        if (fileUTI)
            CFRelease(fileUTI);
        
    } else {
        // icon directory
        metadata.typeFile = k_metadataTypeFile_directory;
        
        metadata.iconName = @"folder";
        
        if([metadata.fileName isEqualToString:autoUploadFileName] && [serverUrl isEqualToString:autoUploadDirectory])
            metadata.iconName = @"folderphotocamera";
    }
    
    return metadata;
}

+ (tableMetadata *)insertFileSystemInMetadata:(NSString *)fileName directory:(NSString *)directory activeAccount:(NSString *)activeAccount autoUploadFileName:(NSString *)autoUploadFileName autoUploadDirectory:(NSString *)autoUploadDirectory
{
    tableMetadata *metadata = [[tableMetadata alloc] init];
    
    NSString *fileNamePath = [NSString stringWithFormat:@"%@/%@", directory, fileName];
    
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fileNamePath error:nil];
    
    metadata.account = activeAccount;
    metadata.date = attributes[NSFileModificationDate];
    
    BOOL isDirectory;
    [[NSFileManager defaultManager] fileExistsAtPath:fileNamePath isDirectory:&isDirectory];
    metadata.directory = isDirectory;
    
    metadata.fileID = fileName;
    metadata.directoryID = directory;
    metadata.fileName = fileName;
    metadata.size = [attributes[NSFileSize] longValue];
    metadata.thumbnailExists = false;
    
    [self insertTypeFileIconName:metadata serverUrl:directory autoUploadFileName:autoUploadFileName autoUploadDirectory:autoUploadDirectory];
    
    return metadata;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Third parts =====
#pragma --------------------------------------------------------------------------------------------

+ (NSString *)stringValueForKey:(id)key conDictionary:(NSDictionary *)dictionary
{
    id obj = [dictionary objectForKey:key];
    
    if ([obj isEqual:[NSNull null]]) return @"";
    
    if ([obj isKindOfClass:[NSString class]]) {
        return obj;
    }
    else if ([obj isKindOfClass:[NSNumber class]]) {
        return [obj stringValue];
    }
    else {
        return [obj description];
    }
}

+ (NSString *)currentDevice
{
    struct utsname systemInfo;
    uname(&systemInfo);
    
    NSString *deviceName=[NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    //NSLog(@"[LOG] Device Name :%@",deviceName);
    
    return deviceName;
}

+ (NSString *)getExtension:(NSString*)fileName
{
    NSMutableArray *fileNameArray =[[NSMutableArray alloc] initWithArray: [fileName componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"."]]];
    NSString *extension = [NSString stringWithFormat:@"%@",[fileNameArray lastObject]];
    extension = [extension uppercaseString];
    //If the file has a ZIP extension obtain the previous one for check if it is a .pages.zip / .numbers.zip / .key.zip extension
    if ([extension isEqualToString:@"ZIP"]) {
        [fileNameArray removeLastObject];
        NSString *secondExtension = [NSString stringWithFormat:@"%@",[fileNameArray lastObject]];
        secondExtension = [secondExtension uppercaseString];
        if ([secondExtension isEqualToString:@"PAGES"] || [secondExtension isEqualToString:@"NUMBERS"] || [secondExtension isEqualToString:@"KEY"]) {
            extension = [NSString stringWithFormat:@"%@.%@",secondExtension,extension];
            return extension;
        }
    }
    return extension;
}

/*
 * Util method to make a NSDate object from a string from xml
 * @dateString -> Data string from xml
 */
+ (NSDate*)parseDateString:(NSString*)dateString
{
    //Parse the date in all the formats
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    /*In most cases the best locale to choose is "en_US_POSIX", a locale that's specifically designed to yield US English results regardless of both user and system preferences. "en_US_POSIX" is also invariant in time (if the US, at some point in the future, changes the way it formats dates, "en_US" will change to reflect the new behaviour, but "en_US_POSIX" will not). It will behave consistently for all users.*/
    [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    //This is the format for the concret locale used
    [dateFormatter setDateFormat:@"EEE, dd MMM y HH:mm:ss zzz"];
    
    NSDate *theDate = nil;
    NSError *error = nil;
    if (![dateFormatter getObjectValue:&theDate forString:dateString range:nil error:&error]) {
        NSLog(@"[LOG] Date '%@' could not be parsed: %@", dateString, error);
    }
    
    return theDate;
}

+ (NSDate *)datetimeWithOutTime:(NSDate *)datDate
{
    if (datDate == nil) return nil;
    
    NSDateComponents* comps = [[NSCalendar currentCalendar] components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:datDate];
    datDate = [[NSCalendar currentCalendar] dateFromComponents:comps];
    
    return datDate;
}

+ (NSDate *)datetimeWithOutDate:(NSDate *)datDate
{
    if (datDate == nil) return nil;
    
    NSDateComponents* comps = [[NSCalendar currentCalendar] components:NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond fromDate:datDate];
    return [[NSCalendar currentCalendar] dateFromComponents:comps];
}

+ (BOOL)isValidEmail:(NSString *)checkString
{
    checkString = [checkString lowercaseString];
    BOOL stricterFilter = YES;
    NSString *stricterFilterString = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}";
    NSString *laxString = @".+@.+\\.[A-Za-z]{2}[A-Za-z]*";
    
    NSString *emailRegex = stricterFilter ? stricterFilterString : laxString;
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    
    return [emailTest evaluateWithObject:checkString];
}

@end
