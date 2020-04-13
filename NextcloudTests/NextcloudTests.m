//
//  NextcloudTests.m
//  NextcloudTests
//
//  Created by James Stout on 12/4/20.
//  Copyright (c) 2020, James Stout (stoutyhk@gmail.com) All rights reserved.
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

@import Foundation;
@import UIKit;
#import <XCTest/XCTest.h>

#import "NSDate+NCUtil.h"
#import "NCBridgeSwift.h"
#import "NCAutoUpload.h"
#import "AppDelegate.h"
#import "NCAutoUpload+NCUtil.h"

//#import <Nexcloud/Nexcloud-Swift.h>
@class tableAccount;

#define TICK   NSDate *startTime = [NSDate date]
#define TOCK NSLog(@"%s Time: %f", __func__, -[startTime timeIntervalSinceNow])

@interface NextcloudTests : XCTestCase

@property (class, readonly, copy) NSArray<XCTPerformanceMetric> *defaultPerformanceMetrics;

@end

@implementation NextcloudTests

//override metrics used by measureBlock
+(NSArray<XCTPerformanceMetric> *)defaultPerformanceMetrics{
    
    return @[XCTPerformanceMetric_WallClockTime,
             @"com.apple.XCTPerformanceMetric_TemporaryHeapAllocationsKilobytes",
             @"com.apple.XCTPerformanceMetric_UserTime"];
}

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

// here we are testing the date formatting code from NSDate+NCUtil.m
// which uses a static NSDateFormatter
// 10000 iterations = 0.0775s, heap allocs: 27800KB (around 27MB)
// vs existing code: 1200% faster, 2100% fewer kb heap allocs (for 10000 iterations)
- (void)testPerformanceNC_stringWithFormat {
    // This is an example of a performance test case.
    [self measureBlock:^{
        int const iterations = 10000;
        NSDate *date = [NSDate date];
        
        for (int i = 0; i < iterations; i++) {
            @autoreleasepool {
                NSString __unused *yearString = [date NC_stringFromDateWithFormat:@"yyyy"];
                NSString __unused *monthString = [date NC_stringFromDateWithFormat:@"MM"];
            }
        }
    }];
}

// here we are testing the date formatting code from NCAutoUpload.m
// which, when uploading entire camera roll, will be called 1000s of times
// 10000 iterations = 1.0s,  heap allocs: 598000 KB (~580MB)
- (void)testPerformanceCurrentDateFormatter {
    
    [self measureBlock:^{
        int const iterations = 10000;
        NSDate *date = [NSDate date];

        for (int i = 0; i < iterations; i++) {
            @autoreleasepool {
                NSDateFormatter *formatter = [NSDateFormatter new];
                
                [formatter setDateFormat:@"yyyy"];
                NSString __unused *yearString = [formatter stringFromDate:date];
                
                [formatter setDateFormat:@"MM"];
                NSString __unused *monthString = [formatter stringFromDate:date];
            }
        }
    }];
}

// test NC_stringWithFormat returns the same date string as using a formatter and stringFromDate
// for 10000 random dates
- (void)testDateFormattersReturnSame {

    int const iterations = 10000;
    
    for (int i = 0; i < iterations; i++) {

        NSDate *assetDate = [self generateRandomDateWithinDaysBeforeToday:i];

        NSDateFormatter *formatter = [NSDateFormatter new];
        
        [formatter setDateFormat:@"yyyy"];
        NSString *yearString = [formatter stringFromDate:assetDate];
        
        [formatter setDateFormat:@"MM"];
        NSString *monthString = [formatter stringFromDate:assetDate];
        
        NSString *yearStringNEW = [assetDate NC_stringFromDateWithFormat:@"yyyy"];
        NSString *monthStringNEW = [assetDate NC_stringFromDateWithFormat:@"MM"];
        
        XCTAssertTrue([yearString isEqualToString:yearStringNEW]);
        XCTAssertTrue([monthString isEqualToString:monthStringNEW]);
        
        // also test @"yy-MM-dd HH-mm-ss" for createFileNameDate in CCUtility.m
        [formatter setDateFormat:@"yy-MM-dd HH-mm-ss"];
        NSString *fileNameDate = [formatter stringFromDate:assetDate];
        NSString *fileNameDateNEW = [assetDate NC_stringFromDateWithFormat:@"yy-MM-dd HH-mm-ss"];
        XCTAssertTrue([fileNameDate isEqualToString:fileNameDateNEW]);
        
        // also test formats in createFileName in CCUtility.m
        [formatter setDateFormat:@"dd"];
        NSString *dayNumber = [formatter stringFromDate:assetDate];
        NSString *dayNumberNEW = [assetDate NC_stringFromDateWithFormat:@"dd"];
        XCTAssertTrue([dayNumber isEqualToString:dayNumberNEW]);

        [formatter setDateFormat:@"MMM"];
        NSString *month = [formatter stringFromDate:assetDate];
        NSString *monthNEW = [assetDate NC_stringFromDateWithFormat:@"MMM"];
        XCTAssertTrue([month isEqualToString:monthNEW]);

        [formatter setDateFormat:@"MM"];
        NSString *monthNumber = [formatter stringFromDate:assetDate];
        NSString *monthNumberNEW = [assetDate NC_stringFromDateWithFormat:@"MM"];
        XCTAssertTrue([monthNumber isEqualToString:monthNumberNEW]);
        
        [formatter setDateFormat:@"yyyy"];
        NSString *year = [formatter stringFromDate:assetDate];
        NSString *yearNEW = [assetDate NC_stringFromDateWithFormat:@"yyyy"];
        XCTAssertTrue([year isEqualToString:yearNEW]);
        
        [formatter setDateFormat:@"yy"];
        NSString *yearNumber = [formatter stringFromDate:assetDate];
        NSString *yearNumberNEW = [assetDate NC_stringFromDateWithFormat:@"yy"];
        XCTAssertTrue([yearNumber isEqualToString:yearNumberNEW]);
        
        [formatter setDateFormat:@"HH"];
        NSString *hour24 = [formatter stringFromDate:assetDate];
        NSString *hour24NEW = [assetDate NC_stringFromDateWithFormat:@"HH"];
        XCTAssertTrue([hour24 isEqualToString:hour24NEW]);
        
        [formatter setDateFormat:@"hh"];
        NSString *hour12 = [formatter stringFromDate:assetDate];
        NSString *hour12NEW = [assetDate NC_stringFromDateWithFormat:@"hh"];
        XCTAssertTrue([hour12 isEqualToString:hour12NEW]);
        
        [formatter setDateFormat:@"mm"];
        NSString *minute = [formatter stringFromDate:assetDate];
        NSString *minuteNEW = [assetDate NC_stringFromDateWithFormat:@"mm"];
        XCTAssertTrue([minute isEqualToString:minuteNEW]);
        
        [formatter setDateFormat:@"ss"];
        NSString *second = [formatter stringFromDate:assetDate];
        NSString *secondNEW = [assetDate NC_stringFromDateWithFormat:@"ss"];
        XCTAssertTrue([second isEqualToString:secondNEW]);
        
        [formatter setDateFormat:@"a"];
        NSString *ampm = [formatter stringFromDate:assetDate];
        NSString *ampmNEW = [assetDate NC_stringFromDateWithFormat:@"a"];
        XCTAssertTrue([ampm isEqualToString:ampmNEW]);
        
//        NSLog(@"date: %@", assetDate.description);
        
    }
}

// this is not ideal, I wanted to mock getCameraRollAssets and fill with random assets
// but couldn't figure it out.
// run this one a device with nextcloud logged in and photos in the lib
// run time for ~28000 assets: 476.030864s (8 mins)
// vs old method: 545.543996 (9 mins) - so around a 14% improvement.
// uncomment the interval/progress lines to see your progress through your lib
-(void)testCreatingNewAssetsToUploadNewMethod{
    
    TICK;
    
    [[NCAutoUpload sharedInstance] initStateAutoUpload];
    
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountActive];
    
    NSString *autoUploadPath = ((AppDelegate *)UIApplication.sharedApplication.delegate).activeUrl;
    NSString *serverUrl;
    
    PHFetchResult *newAssetToUpload = [[NCAutoUpload sharedInstance] getCameraRollAssets:tableAccount selector:selectorUploadAutoUploadAll alignPhotoLibrary:NO];
    
//    float interval = 100/(float)newAssetToUpload.count;
//    float progress = 0.0f;
//
//    int maxInt = 0;
//
    for (PHAsset *asset in newAssetToUpload) {
        
        NSDate *assetDate = asset.creationDate;
        PHAssetMediaType assetMediaType = asset.mediaType;
        NSString *session;
        NSString __unused *fileName = [CCUtility createFileName:[asset valueForKey:@"filename"] fileDate:asset.creationDate fileType:asset.mediaType keyFileName:k_keyFileNameAutoUploadMask keyFileNameType:k_keyFileNameAutoUploadType keyFileNameOriginal:k_keyFileNameOriginalAutoUpload];
        
        // Select type of session
        if (assetMediaType == PHAssetMediaTypeImage && tableAccount.autoUploadWWAnPhoto == NO) session = k_upload_session;
        if (assetMediaType == PHAssetMediaTypeVideo && tableAccount.autoUploadWWAnVideo == NO) session = k_upload_session;
        if (assetMediaType == PHAssetMediaTypeImage && tableAccount.autoUploadWWAnPhoto) session = k_upload_session_wwan;
        if (assetMediaType == PHAssetMediaTypeVideo && tableAccount.autoUploadWWAnVideo) session = k_upload_session_wwan;
        
        NSString *yearString = [assetDate NC_stringFromDateWithFormat:@"yyyy"];
        NSString *monthString = [assetDate NC_stringFromDateWithFormat:@"MM"];
        
        if (tableAccount.autoUploadCreateSubfolder){
            serverUrl = [NSString stringWithFormat:@"%@/%@/%@", autoUploadPath, yearString, monthString];
        }
        else{
            serverUrl = autoUploadPath;
        }
        
//        progress += interval;
//
//        if((int)progress > maxInt){
//            NSLog(@"Progress = %@", [NSString stringWithFormat:@"%.2f\%%", progress]);
//            maxInt = (int)progress;
//        }
    }
        
    TOCK;
}

// run this one a device with nextcloud logged in and photos in the lib
// TOCK gives you the run time
-(void)testCreatingNewAssetsToUploadOldMethod{
    
    TICK;
    
    [[NCAutoUpload sharedInstance] initStateAutoUpload];
    
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountActive];
    
    NSString *autoUploadPath = ((AppDelegate *)UIApplication.sharedApplication.delegate).activeUrl;
    NSString *serverUrl;
    
    PHFetchResult *newAssetToUpload = [[NCAutoUpload sharedInstance] getCameraRollAssets:tableAccount selector:selectorUploadAutoUploadAll alignPhotoLibrary:NO];
    
//    float interval = 100/(float)newAssetToUpload.count;
//    float progress = 0.0f;
//
//    int maxInt = 0;
//
    for (PHAsset *asset in newAssetToUpload) {
        
        NSDate *assetDate = asset.creationDate;
        PHAssetMediaType assetMediaType = asset.mediaType;
        NSString *session;
        NSString __unused *fileName = [CCUtility createFileName:[asset valueForKey:@"filename"] fileDate:asset.creationDate fileType:asset.mediaType keyFileName:k_keyFileNameAutoUploadMask keyFileNameType:k_keyFileNameAutoUploadType keyFileNameOriginal:k_keyFileNameOriginalAutoUpload];
        
        // Select type of session
        if (assetMediaType == PHAssetMediaTypeImage && tableAccount.autoUploadWWAnPhoto == NO) session = k_upload_session;
        if (assetMediaType == PHAssetMediaTypeVideo && tableAccount.autoUploadWWAnVideo == NO) session = k_upload_session;
        if (assetMediaType == PHAssetMediaTypeImage && tableAccount.autoUploadWWAnPhoto) session = k_upload_session_wwan;
        if (assetMediaType == PHAssetMediaTypeVideo && tableAccount.autoUploadWWAnVideo) session = k_upload_session_wwan;
        
        NSDateFormatter *formatter = [NSDateFormatter new];
        
        [formatter setDateFormat:@"yyyy"];
        NSString *yearString = [formatter stringFromDate:assetDate];
        
        [formatter setDateFormat:@"MM"];
        NSString *monthString = [formatter stringFromDate:assetDate];
        
        if (tableAccount.autoUploadCreateSubfolder){
            serverUrl = [NSString stringWithFormat:@"%@/%@/%@", autoUploadPath, yearString, monthString];
        }
        else{
            serverUrl = autoUploadPath;
        }
        
//        progress += interval;
//
//        if((int)progress > maxInt){
//            NSLog(@"Progress = %@", [NSString stringWithFormat:@"%.2f\%%", progress]);
//            maxInt = (int)progress;
//        }
    }
        
    TOCK;
}


#pragma mark - Helpers
/**
 Generate a random date sometime between now and n days before day.
 
 Also, generate a random time to go with the day while we are at it.
 @param daysBack date range between today and minimum date to generate
 @return random date
 @see http://stackoverflow.com/questions/10092468/how-do-you-generate-a-random-date-in-objective-c
 */
- (NSDate *)generateRandomDateWithinDaysBeforeToday:(NSUInteger)daysBack {
    NSUInteger day = arc4random_uniform((u_int32_t)daysBack);  // explisit cast
    NSUInteger hour = arc4random_uniform(23);
    NSUInteger minute = arc4random_uniform(59);

    NSDate *today = [NSDate new];
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];

    NSDateComponents *offsetComponents = [NSDateComponents new];
    [offsetComponents setDay:(day * -1)];
    [offsetComponents setHour:hour];
    [offsetComponents setMinute:minute];

    NSDate *randomDate = [gregorian dateByAddingComponents:offsetComponents
                                                    toDate:today
                                                   options:0];

    return randomDate;
}

@end
