//
//  CCUtility.m
//  Nextcloud
//
//  Created by Marino Faggiana on 02/02/16.
//  Copyright (c) 2016 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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
#import "NCBridgeSwift.h"
#import "NSNotificationCenter+MainThread.h"
#import <OpenSSL/OpenSSL.h>
#import <CoreLocation/CoreLocation.h>
#include <sys/stat.h>

@implementation CCUtility

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Various =====
#pragma --------------------------------------------------------------------------------------------

+ (NSString *)dateDiff:(NSDate *) convertedDate
{
    NSDate *todayDate = [NSDate date];
    double ti = [convertedDate timeIntervalSinceDate:todayDate];
    ti = ti * -1;
    if (ti < 60) {
        return NSLocalizedString(@"_less_a_minute_", nil);
    } else if (ti < 3600) {
        int diff = round(ti / 60);
        if (diff == 1) {
            return NSLocalizedString(@"_a_minute_ago_", nil);
        } else {
            return [NSString stringWithFormat:NSLocalizedString(@"_minutes_ago_", nil), diff];
        }
    } else if (ti < 86400) {
        int diff = round(ti / 60 / 60);
        if (diff == 1) {
            return NSLocalizedString(@"_an_hour_ago_", nil);
        } else {
            return[NSString stringWithFormat:NSLocalizedString(@"_hours_ago_", nil), diff];
        }
    } else if (ti < 86400 * 30) {
        int diff = round(ti / 60 / 60 / 24);
        if (diff == 1) {
            return NSLocalizedString(@"_a_day_ago_", nil);
        } else {
            return[NSString stringWithFormat:NSLocalizedString(@"_days_ago_", nil), diff];
        }
    } else {
        // Older than one month
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setFormatterBehavior:NSDateFormatterBehavior10_4];
        [df setDateStyle:NSDateFormatterMediumStyle];
        return [df stringFromDate:convertedDate];
    }
}

+ (NSString *)createFileNameDate:(NSString *)fileName extension:(NSString *)extension
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yy-MM-dd HH-mm-ss"];
    NSString *fileNameDate = [formatter stringFromDate:[NSDate date]];
    NSString *returnFileName;

    if ([fileName isEqualToString:@""] && ![extension isEqualToString:@""]) {
        returnFileName = [NSString stringWithFormat:@"%@.%@", fileNameDate, extension];
    }

    if (![fileName isEqualToString:@""] && [extension isEqualToString:@""]) {
        returnFileName = [NSString stringWithFormat:@"%@ %@", fileName, fileNameDate];
    }

    if ([fileName isEqualToString:@""] && [extension isEqualToString:@""]) {
        returnFileName = fileNameDate;
    }

    if (![fileName isEqualToString:@""] && ![extension isEqualToString:@""]) {
        returnFileName = [NSString stringWithFormat:@"%@ %@.%@", fileName, fileNameDate, extension];
    }

    return returnFileName;
}

+ (NSString *)createFileName:(NSString *)fileName fileDate:(NSDate *)fileDate fileType:(PHAssetMediaType)fileType keyFileName:(NSString *)keyFileName keyFileNameType:(NSString *)keyFileNameType keyFileNameOriginal:(NSString *)keyFileNameOriginal forcedNewFileName:(BOOL)forcedNewFileName
{
    BOOL addFileNameType = NO;

    // Original FileName ?
    if ([[[NCKeychain alloc] init] getOriginalFileNameWithKey:keyFileNameOriginal] && !forcedNewFileName) {
        return fileName;
    }

    NSString *numberFileName;
    if ([fileName length] > 8) numberFileName = [fileName substringWithRange:NSMakeRange(04, 04)];
    else numberFileName = [[NCKeychain alloc] init].incrementalNumber;

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
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
        addFileNameType = [[[NCKeychain alloc] init] getFileNameTypeWithKey:keyFileNameType];

    NSString *fileNameExt = [[fileName pathExtension] lowercaseString];

    if (keyFileName) {

        fileName = [[[NCKeychain alloc] init] getFileNameMaskWithKey:keyFileName];

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
                fileName = [NSString stringWithFormat:@"%@%@%@.%@", fileNameType, fileName, numberFileName, fileNameExt];
            else
                fileName = [NSString stringWithFormat:@"%@%@.%@", fileName, numberFileName, fileNameExt];

            fileName = [fileName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

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

+ (NSString *)getTitleSectionDate:(NSDate *)date
{
    NSString *title;
    NSDate *today = [NSDate date];
    NSDate *yesterday = [today dateByAddingTimeInterval: -86400.0];

    if ([date isEqualToDate:[CCUtility datetimeWithOutTime:[NSDate distantPast]]]) {

        title =  NSLocalizedString(@"_no_date_", nil);

    } else {

        title = [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterLongStyle timeStyle:0];

        if ([date isEqualToDate:[CCUtility datetimeWithOutTime:today]])
            title = [NSString stringWithFormat:NSLocalizedString(@"_today_", nil)];

        if ([date isEqualToDate:[CCUtility datetimeWithOutTime:yesterday]])
            title = [NSString stringWithFormat:NSLocalizedString(@"_yesterday_", nil)];
    }

    return title;
}

+ (NSString *)returnPathfromServerUrl:(NSString *)serverUrl urlBase:(NSString *)urlBase userId:(NSString *)userId account:(NSString *)account
{
    NSString *homeServer = [[NCUtilityFileSystem shared] getHomeServerWithUrlBase:urlBase userId:userId];
    NSString *path = [serverUrl stringByReplacingOccurrencesOfString:homeServer withString:@""];
    return path;
}

+ (NSString *)returnFileNamePathFromFileName:(NSString *)metadataFileName serverUrl:(NSString *)serverUrl urlBase:(NSString *)urlBase userId:(NSString *)userId account:(NSString *)account
{
    if (metadataFileName == nil || serverUrl == nil || urlBase == nil) {
        return @"";
    }

    NSString *homeServer = [[NCUtilityFileSystem shared] getHomeServerWithUrlBase:urlBase userId:userId];
    NSString *fileName = [NSString stringWithFormat:@"%@/%@", [serverUrl stringByReplacingOccurrencesOfString:homeServer withString:@""], metadataFileName];

    if ([fileName hasPrefix:@"/"]) fileName = [fileName substringFromIndex:1];

    return fileName;
}

+ (NSString *)getMimeType:(NSString *)fileNameView
{
    CFStringRef fileUTI = nil;
    NSString *returnFileUTI = nil;

    if ([fileNameView isEqualToString:@"."]) {

        return returnFileUTI;

    } else {
        CFStringRef fileExtension = (__bridge CFStringRef)[fileNameView pathExtension];
        NSString *ext = (__bridge NSString *)fileExtension;
        ext = ext.uppercaseString;
        fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension, NULL);

        if (fileUTI != nil) {
            returnFileUTI = (__bridge NSString *)fileUTI;
            CFRelease(fileUTI);
        }
    }

    return returnFileUTI;
}


#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Share Permissions =====
#pragma --------------------------------------------------------------------------------------------

+ (NSInteger) getPermissionsValueByCanEdit:(BOOL)canEdit andCanCreate:(BOOL)canCreate andCanChange:(BOOL)canChange andCanDelete:(BOOL)canDelete andCanShare:(BOOL)canShare andIsFolder:(BOOL) isFolder
{
    NSInteger permissionsValue = NCGlobal.shared.permissionReadShare;

    if (canEdit && !isFolder) {
        permissionsValue = permissionsValue + NCGlobal.shared.permissionUpdateShare;
    }
    if (canCreate & isFolder) {
        permissionsValue = permissionsValue + NCGlobal.shared.permissionCreateShare;
    }
    if (canChange && isFolder) {
        permissionsValue = permissionsValue + NCGlobal.shared.permissionUpdateShare;
    }
    if (canDelete & isFolder) {
        permissionsValue = permissionsValue + NCGlobal.shared.permissionDeleteShare;
    }
    if (canShare) {
        permissionsValue = permissionsValue + NCGlobal.shared.permissionShareShare;
    }

    return permissionsValue;
}

+ (BOOL) isPermissionToCanCreate:(NSInteger) permissionValue {
    BOOL canCreate = ((permissionValue & NCGlobal.shared.permissionCreateShare) > 0);
    return canCreate;
}

+ (BOOL) isPermissionToCanChange:(NSInteger) permissionValue {
    BOOL canChange = ((permissionValue & NCGlobal.shared.permissionUpdateShare) > 0);
    return canChange;
}

+ (BOOL) isPermissionToCanDelete:(NSInteger) permissionValue {
    BOOL canDelete = ((permissionValue & NCGlobal.shared.permissionDeleteShare) > 0);
    return canDelete;
}

+ (BOOL) isPermissionToCanShare:(NSInteger) permissionValue {
    BOOL canShare = ((permissionValue & NCGlobal.shared.permissionShareShare) > 0);
    return canShare;
}

+ (BOOL) isAnyPermissionToEdit:(NSInteger) permissionValue {

    BOOL canCreate = [self isPermissionToCanCreate:permissionValue];
    BOOL canChange = [self isPermissionToCanChange:permissionValue];
    BOOL canDelete = [self isPermissionToCanDelete:permissionValue];


    BOOL canEdit = (canCreate || canChange || canDelete);

    return canEdit;

}

+ (BOOL) isPermissionToRead:(NSInteger) permissionValue {
    BOOL canRead = ((permissionValue & NCGlobal.shared.permissionReadShare) > 0);
    return canRead;
}

+ (BOOL) isPermissionToReadCreateUpdate:(NSInteger) permissionValue {

    BOOL canRead   = [self isPermissionToRead:permissionValue];
    BOOL canCreate = [self isPermissionToCanCreate:permissionValue];
    BOOL canChange = [self isPermissionToCanChange:permissionValue];


    BOOL canEdit = (canCreate && canChange && canRead);

    return canEdit;

}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Third parts =====
#pragma --------------------------------------------------------------------------------------------

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

+ (NSDate *)datetimeWithOutTime:(NSDate *)datDate
{
    if (datDate == nil) return nil;

    NSDateComponents* comps = [[NSCalendar currentCalendar] components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:datDate];
    datDate = [[NSCalendar currentCalendar] dateFromComponents:comps];

    return datDate;
}

+ (NSString *)valueForKey:(NSString *)key fromQueryItems:(NSArray *)queryItems
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name=%@", key];
    NSURLQueryItem *queryItem = [[queryItems filteredArrayUsingPredicate:predicate] firstObject];
    return queryItem.value;
}

+ (NSDate *)getATime:(const char *)path
{
    struct stat st;
    stat(path, &st);
    time_t accessed = st.st_atime;
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:accessed];
    return date;
}
@end
