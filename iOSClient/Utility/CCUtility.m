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
#import <OpenSSL/OpenSSL.h>
#import <CoreLocation/CoreLocation.h>
#include <sys/stat.h>

@implementation CCUtility

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Various =====
#pragma --------------------------------------------------------------------------------------------

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

@end
