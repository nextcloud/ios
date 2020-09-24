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
#import "CCGraphics.h"
#import "NCBridgeSwift.h"
#import <OpenSSL/OpenSSL.h>

#define INTRO_MessageType       @"MessageType_"

#define E2E_PublicKey           @"EndToEndPublicKey_"
#define E2E_PrivateKey          @"EndToEndPrivateKey_"
#define E2E_Passphrase          @"EndToEndPassphrase_"
#define E2E_PublicKeyServer     @"EndToEndPublicKeyServer_"

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

#pragma ------------------------------ GET/SET

+ (NSString *)getPasscode
{
    return [UICKeyChainStore stringForKey:@"passcodeBlock" service:k_serviceShareKeyChain];
}

+ (void)setPasscode:(NSString *)passcode
{
    [UICKeyChainStore setString:passcode forKey:@"passcodeBlock" service:k_serviceShareKeyChain];
}

+ (BOOL)getNotPasscodeAtStart
{
    return [[UICKeyChainStore stringForKey:@"notPasscodeAtStart" service:k_serviceShareKeyChain] boolValue];
}

+ (void)setNotPasscodeAtStart:(BOOL)set
{
    NSString *sSet = (set) ? @"true" : @"false";
    [UICKeyChainStore setString:sSet forKey:@"notPasscodeAtStart" service:k_serviceShareKeyChain];
}

+ (BOOL)getEnableTouchFaceID
{
    NSString *valueString = [UICKeyChainStore stringForKey:@"enableTouchFaceID" service:k_serviceShareKeyChain];
    
    // Default TRUE
    if (valueString == nil) {
        [self setEnableTouchFaceID:YES];
        return true;
    }
    
    return [valueString boolValue];
}

+ (void)setEnableTouchFaceID:(BOOL)set
{
    NSString *sSet = (set) ? @"true" : @"false";
    [UICKeyChainStore setString:sSet forKey:@"enableTouchFaceID" service:k_serviceShareKeyChain];
}

+ (NSString *)getGroupBySettings
{
    NSString *groupby = [UICKeyChainStore stringForKey:@"groupby" service:k_serviceShareKeyChain];
    
    if (groupby == nil) {
        
        [self setGroupBySettings:@"none"];
        return @"none";
    }
    
    return @"none";
    
    //return groupby;
}

+ (void)setGroupBySettings:(NSString *)groupby
{
    [UICKeyChainStore setString:groupby forKey:@"groupby" service:k_serviceShareKeyChain];
}

+ (BOOL)getIntro
{
    // Set compatibility old version don't touch me
    if ([[UICKeyChainStore stringForKey:[INTRO_MessageType stringByAppendingString:@"Intro"] service:k_serviceShareKeyChain] boolValue] == YES) {
        [CCUtility setIntro:YES];
        return YES;
    }
    
    return [[UICKeyChainStore stringForKey:@"intro" service:k_serviceShareKeyChain] boolValue];
}

+ (BOOL)getIntroMessageOldVersion
{
    NSString *key = [INTRO_MessageType stringByAppendingString:@"Intro"];
    
    return [[UICKeyChainStore stringForKey:key service:k_serviceShareKeyChain] boolValue];
}

+ (void)setIntro:(BOOL)set
{
    NSString *sIntro = (set) ? @"true" : @"false";
    [UICKeyChainStore setString:sIntro forKey:@"intro" service:k_serviceShareKeyChain];

}

+ (NSString *)getIncrementalNumber
{
    long number = [[UICKeyChainStore stringForKey:@"incrementalnumber" service:k_serviceShareKeyChain] intValue];
    
    number++;
    if (number >= 9999) number = 1;
    
    [UICKeyChainStore setString:[NSString stringWithFormat:@"%ld", number] forKey:@"incrementalnumber" service:k_serviceShareKeyChain];
    
    return [NSString stringWithFormat:@"%04ld", number];
}

+ (NSString *)getAccountExt
{
    return [UICKeyChainStore stringForKey:@"accountExt" service:k_serviceShareKeyChain];
}

+ (void)setAccountExt:(NSString *)account
{
    [UICKeyChainStore setString:account forKey:@"accountExt" service:k_serviceShareKeyChain];
}

+ (NSString *)getServerUrlExt
{
    return [UICKeyChainStore stringForKey:@"serverUrlExt" service:k_serviceShareKeyChain];
}

+ (void)setServerUrlExt:(NSString *)serverUrl
{
    [UICKeyChainStore setString:serverUrl forKey:@"serverUrlExt" service:k_serviceShareKeyChain];
}

+ (NSString *)getTitleServerUrlExt
{
    return [UICKeyChainStore stringForKey:@"titleServerUrlExt" service:k_serviceShareKeyChain];
}

+ (void)setTitleServerUrlExt:(NSString *)titleServerUrl
{
    [UICKeyChainStore setString:titleServerUrl forKey:@"titleServerUrlExt" service:k_serviceShareKeyChain];
}

+ (NSString *)getFileNameExt
{
    return [UICKeyChainStore stringForKey:@"fileNameExt" service:k_serviceShareKeyChain];
}

+ (void)setFileNameExt:(NSString *)fileName
{
    [UICKeyChainStore setString:fileName forKey:@"fileNameExt" service:k_serviceShareKeyChain];
}

+ (NSString *)getEmail
{
    return [UICKeyChainStore stringForKey:@"email" service:k_serviceShareKeyChain];
}

+ (void)setEmail:(NSString *)email
{
    [UICKeyChainStore setString:email forKey:@"email" service:k_serviceShareKeyChain];
}

+ (NSString *)getHint
{
    return [UICKeyChainStore stringForKey:@"hint" service:k_serviceShareKeyChain];
}

+ (void)setHint:(NSString *)hint
{
    [UICKeyChainStore setString:hint forKey:@"hint" service:k_serviceShareKeyChain];
}

+ (BOOL)getOriginalFileName:(NSString *)key
{
    return [[UICKeyChainStore stringForKey:key service:k_serviceShareKeyChain] boolValue];
}

+ (void)setOriginalFileName:(BOOL)value key:(NSString *)key
{
    NSString *sValue = (value) ? @"true" : @"false";
    [UICKeyChainStore setString:sValue forKey:key service:k_serviceShareKeyChain];
}

+ (NSString *)getFileNameMask:(NSString *)key
{
    NSString *mask = [UICKeyChainStore stringForKey:key service:k_serviceShareKeyChain];
    
    if (mask == nil)
        mask = @"";
    
    return mask;
}

+ (void)setFileNameMask:(NSString *)mask key:(NSString *)key
{
    [UICKeyChainStore setString:mask forKey:key service:k_serviceShareKeyChain];
}

+ (BOOL)getFileNameType:(NSString *)key
{
    return [[UICKeyChainStore stringForKey:key service:k_serviceShareKeyChain] boolValue];
}

+ (void)setFileNameType:(BOOL)prefix key:(NSString *)key
{
    NSString *sPrefix = (prefix) ? @"true" : @"false";
    [UICKeyChainStore setString:sPrefix forKey:key service:k_serviceShareKeyChain];
}

+ (BOOL)getFavoriteOffline
{
    return [[UICKeyChainStore stringForKey:@"favoriteOffline" service:k_serviceShareKeyChain] boolValue];
}

+ (void)setFavoriteOffline:(BOOL)offline
{
    NSString *sFavoriteOffline = (offline) ? @"true" : @"false";
    [UICKeyChainStore setString:sFavoriteOffline forKey:@"favoriteOffline" service:k_serviceShareKeyChain];
}

+ (BOOL)getActivityVerboseHigh
{
    return [[UICKeyChainStore stringForKey:@"activityVerboseHigh" service:k_serviceShareKeyChain] boolValue];
}

+ (void)setActivityVerboseHigh:(BOOL)high
{
    NSString *sHigh = (high) ? @"true" : @"false";
    [UICKeyChainStore setString:sHigh forKey:@"activityVerboseHigh" service:k_serviceShareKeyChain];
}

+ (BOOL)getShowHiddenFiles
{
    return [[UICKeyChainStore stringForKey:@"showHiddenFiles" service:k_serviceShareKeyChain] boolValue];
}

+ (void)setShowHiddenFiles:(BOOL)show
{
    NSString *sShow = (show) ? @"true" : @"false";
    [UICKeyChainStore setString:sShow forKey:@"showHiddenFiles" service:k_serviceShareKeyChain];
}

+ (BOOL)getFormatCompatibility
{
    NSString *valueString = [UICKeyChainStore stringForKey:@"formatCompatibility" service:k_serviceShareKeyChain];
    
    // Default TRUE
    if (valueString == nil) {
        [self setFormatCompatibility:YES];
        return true;
    }
    
    return [valueString boolValue];
}

+ (void)setFormatCompatibility:(BOOL)set
{
    NSString *sSet = (set) ? @"true" : @"false";
    [UICKeyChainStore setString:sSet forKey:@"formatCompatibility" service:k_serviceShareKeyChain];
}

+ (NSString *)getEndToEndPublicKey:(NSString *)account
{
    NSString *key = [E2E_PublicKey stringByAppendingString:account];
    return [UICKeyChainStore stringForKey:key service:k_serviceShareKeyChain];
}

+ (void)setEndToEndPublicKey:(NSString *)account publicKey:(NSString *)publicKey
{
    NSString *key = [E2E_PublicKey stringByAppendingString:account];
    [UICKeyChainStore setString:publicKey forKey:key service:k_serviceShareKeyChain];
}

+ (NSString *)getEndToEndPrivateKey:(NSString *)account
{
    NSString *key = [E2E_PrivateKey stringByAppendingString:account];
    return [UICKeyChainStore stringForKey:key service:k_serviceShareKeyChain];
}

+ (void)setEndToEndPrivateKey:(NSString *)account privateKey:(NSString *)privateKey
{
    NSString *key = [E2E_PrivateKey stringByAppendingString:account];
    [UICKeyChainStore setString:privateKey forKey:key service:k_serviceShareKeyChain];
}

+ (NSString *)getEndToEndPassphrase:(NSString *)account
{
    NSString *key = [E2E_Passphrase stringByAppendingString:account];
    return [UICKeyChainStore stringForKey:key service:k_serviceShareKeyChain];
}

+ (void)setEndToEndPassphrase:(NSString *)account passphrase:(NSString *)passphrase
{
    NSString *key = [E2E_Passphrase stringByAppendingString:account];
    [UICKeyChainStore setString:passphrase forKey:key service:k_serviceShareKeyChain];
}

+ (NSString *)getEndToEndPublicKeyServer:(NSString *)account
{
    NSString *key = [E2E_PublicKeyServer stringByAppendingString:account];
    return [UICKeyChainStore stringForKey:key service:k_serviceShareKeyChain];
}

+ (void)setEndToEndPublicKeyServer:(NSString *)account publicKey:(NSString *)publicKey
{
    NSString *key = [E2E_PublicKeyServer stringByAppendingString:account];
    [UICKeyChainStore setString:publicKey forKey:key service:k_serviceShareKeyChain];
}

+ (BOOL)isEndToEndEnabled:(NSString *)account
{
    BOOL isE2EEEnabled = [[NCManageDatabase sharedInstance] getCapabilitiesServerBoolWithAccount:account elements:NCElementsJSON.shared.capabilitiesE2EEEnabled exists:false];
    NSString* versionE2EE = [[NCManageDatabase sharedInstance] getCapabilitiesServerStringWithAccount:account elements:NCElementsJSON.shared.capabilitiesE2EEApiVersion];
    
    NSString *publicKey = [self getEndToEndPublicKey:account];
    NSString *privateKey = [self getEndToEndPrivateKey:account];
    NSString *passphrase = [self getEndToEndPassphrase:account];
    NSString *publicKeyServer = [self getEndToEndPublicKeyServer:account];    
    
    if (passphrase.length > 0 && privateKey.length > 0 && publicKey.length > 0 && publicKeyServer.length > 0 && isE2EEEnabled && [versionE2EE isEqual:k_E2EE_API]) {
       
        return YES;
        
    } else {
        
        return NO;
    }
}

+ (void)clearAllKeysEndToEnd:(NSString *)account
{
    [self setEndToEndPublicKey:account publicKey:nil];
    [self setEndToEndPrivateKey:account privateKey:nil];
    [self setEndToEndPassphrase:account passphrase:nil];
    [self setEndToEndPublicKeyServer:account publicKey:nil];
}

+ (BOOL)getDisableFilesApp
{
    return [[UICKeyChainStore stringForKey:@"disablefilesapp" service:k_serviceShareKeyChain] boolValue];
}

+ (void)setDisableFilesApp:(BOOL)disable
{
    NSString *sDisable = (disable) ? @"true" : @"false";
    [UICKeyChainStore setString:sDisable forKey:@"disablefilesapp" service:k_serviceShareKeyChain];
}

+ (void)setPushNotificationPublicKey:(NSString *)account data:(NSData *)data
{
    NSString *key = [@"PNPublicKey" stringByAppendingString:account];
    [UICKeyChainStore setData:data forKey:key service:k_serviceShareKeyChain];
}

+ (NSData *)getPushNotificationPublicKey:(NSString *)account
{
    NSString *key = [@"PNPublicKey" stringByAppendingString:account];
    return [UICKeyChainStore dataForKey:key service:k_serviceShareKeyChain];
}

+ (void)setPushNotificationSubscribingPublicKey:(NSString *)account publicKey:(NSString *)publicKey
{
    NSString *key = [@"PNSubscribingPublicKey" stringByAppendingString:account];
    [UICKeyChainStore setString:publicKey forKey:key service:k_serviceShareKeyChain];
}

+ (NSString *)getPushNotificationSubscribingPublicKey:(NSString *)account
{
    NSString *key = [@"PNSubscribingPublicKey" stringByAppendingString:account];
    return [UICKeyChainStore stringForKey:key service:k_serviceShareKeyChain];
}

+ (void)setPushNotificationPrivateKey:(NSString *)account data:(NSData *)data
{
    NSString *key = [@"PNPrivateKey" stringByAppendingString:account];
    [UICKeyChainStore setData:data forKey:key service:k_serviceShareKeyChain];
}

+ (NSData *)getPushNotificationPrivateKey:(NSString *)account
{
    NSString *key = [@"PNPrivateKey" stringByAppendingString:account];
    return [UICKeyChainStore dataForKey:key service:k_serviceShareKeyChain];
}

+ (void)setPushNotificationToken:(NSString *)account token:(NSString *)token
{
    NSString *key = [@"PNToken" stringByAppendingString:account];
    [UICKeyChainStore setString:token forKey:key service:k_serviceShareKeyChain];
}

+ (NSString *)getPushNotificationToken:(NSString *)account
{
    NSString *key = [@"PNToken" stringByAppendingString:account];
    return [UICKeyChainStore stringForKey:key service:k_serviceShareKeyChain];
}

+ (void)setPushNotificationDeviceIdentifier:(NSString *)account deviceIdentifier:(NSString *)deviceIdentifier
{
    NSString *key = [@"PNDeviceIdentifier" stringByAppendingString:account];
    [UICKeyChainStore setString:deviceIdentifier forKey:key service:k_serviceShareKeyChain];
}

+ (NSString *)getPushNotificationDeviceIdentifier:(NSString *)account
{
    NSString *key = [@"PNDeviceIdentifier" stringByAppendingString:account];
    return [UICKeyChainStore stringForKey:key service:k_serviceShareKeyChain];
}

+ (void)setPushNotificationDeviceIdentifierSignature:(NSString *)account deviceIdentifierSignature:(NSString *)deviceIdentifierSignature
{
    NSString *key = [@"PNDeviceIdentifierSignature" stringByAppendingString:account];
    [UICKeyChainStore setString:deviceIdentifierSignature forKey:key service:k_serviceShareKeyChain];
}

+ (NSString *)getPushNotificationDeviceIdentifierSignature:(NSString *)account
{
    NSString *key = [@"PNDeviceIdentifierSignature" stringByAppendingString:account];
    return [UICKeyChainStore stringForKey:key service:k_serviceShareKeyChain];
}

+ (void)clearAllKeysPushNotification:(NSString *)account
{
    [self setPushNotificationPublicKey:account data:nil];
    [self setPushNotificationSubscribingPublicKey:account publicKey:nil];
    [self setPushNotificationPrivateKey:account data:nil];
    [self setPushNotificationToken:account token:nil];
    [self setPushNotificationDeviceIdentifier:account deviceIdentifier:nil];
    [self setPushNotificationDeviceIdentifierSignature:account deviceIdentifierSignature:nil];
}

+ (NSInteger)getMediaWidthImage
{
    NSString *width = [UICKeyChainStore stringForKey:@"mediaWidthImage" service:k_serviceShareKeyChain];
    
    if (width == nil) {
        return 80;
    } else {
        return [width integerValue];
    }
}

+ (void)setMediaWidthImage:(NSInteger)width
{
    NSString *widthString = [@(width) stringValue];
    [UICKeyChainStore setString:widthString forKey:@"mediaWidthImage" service:k_serviceShareKeyChain];
}

+ (BOOL)getDisableCrashservice
{
    return [[UICKeyChainStore stringForKey:@"crashservice" service:k_serviceShareKeyChain] boolValue];
}

+ (void)setDisableCrashservice:(BOOL)disable
{
    NSString *sDisable = (disable) ? @"true" : @"false";
    [UICKeyChainStore setString:sDisable forKey:@"crashservice" service:k_serviceShareKeyChain];
}

+ (void)setPassword:(NSString *)account password:(NSString *)password
{
    NSString *key = [@"password" stringByAppendingString:account];
    [UICKeyChainStore setString:password forKey:key service:k_serviceShareKeyChain];
}

+ (NSString *)getPassword:(NSString *)account
{
    NSString *key = [@"password" stringByAppendingString:account];
    return [UICKeyChainStore stringForKey:key service:k_serviceShareKeyChain];
}

+ (void)setHCBusinessType:(NSString *)professions
{
    [UICKeyChainStore setString:professions forKey:@"businessType" service:k_serviceShareKeyChain];
}

+ (NSString *)getHCBusinessType
{
    return [UICKeyChainStore stringForKey:@"businessType" service:k_serviceShareKeyChain];
}

+ (NSData *)getDatabaseEncryptionKey
{
    NSData *key = [UICKeyChainStore dataForKey:@"databaseEncryptionKey" service:k_serviceShareKeyChain];
    if (key == nil) {
        NSMutableData *key = [NSMutableData dataWithLength:64];
        (void)SecRandomCopyBytes(kSecRandomDefault, key.length, (uint8_t *)key.mutableBytes);
        [UICKeyChainStore setData:key forKey:@"databaseEncryptionKey" service:k_serviceShareKeyChain];
        return key;
    } else {
        return key;
    }
}

+ (void)setDatabaseEncryptionKey:(NSData *)data
{
    [UICKeyChainStore setData:data forKey:@"databaseEncryptionKey" service:k_serviceShareKeyChain];
}

+ (BOOL)getCertificateError:(NSString *)account
{
    NSString *key = [@"certificateError" stringByAppendingString:account];
    NSString *error = [UICKeyChainStore stringForKey:key service:k_serviceShareKeyChain];
    
    if (error == nil) {
        
        [self setCertificateError:account error:NO];
        return  NO;
    }
    
    return [error boolValue];
}

+ (void)setCertificateError:(NSString *)account error:(BOOL)error
{
    // In background do not write the error
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    if (error && (state == UIApplicationStateBackground || state == UIApplicationStateInactive)) {
        return;
    }
    
    NSString *key = [@"certificateError" stringByAppendingString:account];
    NSString *sError = (error) ? @"true" : @"false";
    
    [UICKeyChainStore setString:sError forKey:key service:k_serviceShareKeyChain];
}

+ (BOOL)getDisableLocalCacheAfterUpload
{
    return [[UICKeyChainStore stringForKey:@"disableLocalCacheAfterUpload" service:k_serviceShareKeyChain] boolValue];
}

+ (void)setDisableLocalCacheAfterUpload:(BOOL)disable
{
    NSString *sDisable = (disable) ? @"true" : @"false";
    [UICKeyChainStore setString:sDisable forKey:@"disableLocalCacheAfterUpload" service:k_serviceShareKeyChain];
}

+ (BOOL)getDarkMode
{
    NSString *sDisable = [UICKeyChainStore stringForKey:@"darkMode" service:k_serviceShareKeyChain];
    if(!sDisable){
        if (@available(iOS 13.0, *)) {
            if ([CCUtility getDarkModeDetect]) {
                if ([[UITraitCollection currentTraitCollection] userInterfaceStyle] == UIUserInterfaceStyleDark) {
                    sDisable = @"YES";
                    [CCUtility setDarkMode:YES];
                } else {
                    sDisable = @"NO";
                    [CCUtility setDarkMode:NO];
                }
            }
        }
    }
    return [sDisable boolValue];
}

+ (void)setDarkMode:(BOOL)disable
{
    NSString *sDisable = (disable) ? @"true" : @"false";
    [UICKeyChainStore setString:sDisable forKey:@"darkMode" service:k_serviceShareKeyChain];
}

+ (BOOL)getDarkModeDetect
{
    NSString *valueString = [UICKeyChainStore stringForKey:@"darkModeDetect" service:k_serviceShareKeyChain];
    
    // Default TRUE
    if (valueString == nil) {
        [self setDarkModeDetect:YES];
        return true;
    }
    
    return [valueString boolValue];
}

+ (void)setDarkModeDetect:(BOOL)disable
{
    NSString *sDisable = (disable) ? @"true" : @"false";
    [UICKeyChainStore setString:sDisable forKey:@"darkModeDetect" service:k_serviceShareKeyChain];
}

+ (BOOL)getLivePhoto
{
    NSString *valueString = [UICKeyChainStore stringForKey:@"livePhoto" service:k_serviceShareKeyChain];
    
    // Default TRUE
    if (valueString == nil) {
        [self setLivePhoto:YES];
        return true;
    }
    
    return [valueString boolValue];
}

+ (void)setLivePhoto:(BOOL)set
{
    NSString *sSet = (set) ? @"true" : @"false";
    [UICKeyChainStore setString:sSet forKey:@"livePhoto" service:k_serviceShareKeyChain];
}

+ (NSString *)getMediaSortDate
{
    NSString *valueString = [UICKeyChainStore stringForKey:@"mediaSortDate" service:k_serviceShareKeyChain];
    
    // Default TRUE
    if (valueString == nil) {
        [self setMediaSortDate:@"date"];
        return @"date";
    }
    
    return valueString;
}

+ (void)setMediaSortDate:(NSString *)value
{
    [UICKeyChainStore setString:value forKey:@"mediaSortDate" service:k_serviceShareKeyChain];
}

+ (NSInteger)getTextRecognitionStatus
{
    NSString *value = [UICKeyChainStore stringForKey:@"textRecognitionStatus" service:k_serviceShareKeyChain];
    
    if (value == nil) {
        return 0;
    } else {
        return [value integerValue];
    }
}

+ (void)setTextRecognitionStatus:(NSInteger)value
{
    NSString *valueString = [@(value) stringValue];
    [UICKeyChainStore setString:valueString forKey:@"textRecognitionStatus" service:k_serviceShareKeyChain];
}

+ (NSString *)getDirectoryScanDocuments
{
    return [UICKeyChainStore stringForKey:@"directoryScanDocuments" service:k_serviceShareKeyChain];
}

+ (void)setDirectoryScanDocuments:(NSString *)value
{
    [UICKeyChainStore setString:value forKey:@"directoryScanDocuments" service:k_serviceShareKeyChain];
}

+ (NSInteger)getLogLevel
{
    NSString *value = [UICKeyChainStore stringForKey:@"logLevel" service:k_serviceShareKeyChain];
    
    if (value == nil) {
        return 1;
    } else {
        return [value integerValue];
    }
}

+ (void)setLogLevel:(NSInteger)value
{
    NSString *valueString = [@(value) stringValue];
    [UICKeyChainStore setString:valueString forKey:@"logLevel" service:k_serviceShareKeyChain];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Various =====
#pragma --------------------------------------------------------------------------------------------

+ (BOOL)addSkipBackupAttributeToItemAtURL:(NSURL *)URL
{
    assert([[NSFileManager defaultManager] fileExistsAtPath: [URL path]]);
    
    NSError *error = nil;
    BOOL success = [URL setResourceValue:[NSNumber numberWithBool: YES] forKey: NSURLIsExcludedFromBackupKey error: &error];
    if(!success){
        NSLog(@"Error excluding %@ from backup %@", [URL lastPathComponent], error);
    }
    
    return success;
}

+ (NSString *)getUserAgent
{
    NSString *appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *userAgent = [[NCBrandOptions sharedInstance] userAgent];
    
    return [NSString stringWithFormat:@"Mozilla/5.0 (iOS) %@/%@", userAgent, appVersion];
}

+ (NSString *)dateDiff:(NSDate *) convertedDate
{
    NSDate *todayDate = [NSDate date];
    double ti = [convertedDate timeIntervalSinceDate:todayDate];
    ti = ti * -1;
    if (ti < 60) {
        // This minute
        return NSLocalizedString(@"_less_a_minute_", nil);
    } else if (ti < 3600) {
        // This hour
        int diff = round(ti / 60);
        return [NSString stringWithFormat:NSLocalizedString(@"_minutes_ago_", nil), diff];
    } else if (ti < 86400) {
        // This day
        int diff = round(ti / 60 / 60);
        return[NSString stringWithFormat:NSLocalizedString(@"_hours_ago_", nil), diff];
    } else if (ti < 86400 * 30) {
        // This month
        int diff = round(ti / 60 / 60 / 24);
        return[NSString stringWithFormat:NSLocalizedString(@"_days_ago_", nil), diff];
    } else {
        // Older than one month
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setFormatterBehavior:NSDateFormatterBehavior10_4];
        [df setDateStyle:NSDateFormatterMediumStyle];
        return [df stringFromDate:convertedDate];
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
        NSLog(@"[LOG] Date '%@' could not be parsed: %@", dateString, error);
        date = [NSDate date];
    }

    return date;
}

+ (NSString *)transformedSize:(double)value
{
    NSString *string = [NSByteCountFormatter stringFromByteCount:value countStyle:NSByteCountFormatterCountStyleBinary];
    return string;
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

+ (NSString *)createFileName:(NSString *)fileName fileDate:(NSDate *)fileDate fileType:(PHAssetMediaType)fileType keyFileName:(NSString *)keyFileName keyFileNameType:(NSString *)keyFileNameType keyFileNameOriginal:(NSString *)keyFileNameOriginal
{
    BOOL addFileNameType = NO;
    
    // Original FileName ?
    if ([self getOriginalFileName:keyFileNameOriginal]) {
        return fileName;
    }
    
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

+ (void)createDirectoryStandard
{
    NSString *path;
    NSURL *dirGroup = [CCUtility getDirectoryGroup];
    
    NSLog(@"[LOG] Dir Group");
    NSLog(@"%@", [dirGroup path]);
    NSLog(@"[LOG] Program application ");
    NSLog(@"%@", [[CCUtility getDirectoryDocuments] stringByDeletingLastPathComponent]);
    
    // create Directory Documents
    path = [CCUtility getDirectoryDocuments];
    if (![[NSFileManager defaultManager] fileExistsAtPath: path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    
    // create Directory audio => Library, Application Support, audio
    path = [CCUtility getDirectoryAudio];
    if (![[NSFileManager defaultManager] fileExistsAtPath: path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    
    // create Directory database Nextcloud
    path = [[dirGroup URLByAppendingPathComponent:k_appDatabaseNextcloud] path];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    [[NSFileManager defaultManager] setAttributes:@{NSFileProtectionKey:NSFileProtectionNone} ofItemAtPath:path error:nil];
    
    // create Directory User Data
    path = [[dirGroup URLByAppendingPathComponent:k_appUserData] path];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    
    // create Directory Provider Storage
    path = [CCUtility getDirectoryProviderStorage];
    if (![[NSFileManager defaultManager] fileExistsAtPath: path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    
    // create Directory Scan
    path = [[dirGroup URLByAppendingPathComponent:k_appScan] path];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    
    // create Directory Temp
    path = NSTemporaryDirectory();
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    
    // Directory Excluded From Backup
    [CCUtility addSkipBackupAttributeToItemAtURL:[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject]];
    [CCUtility addSkipBackupAttributeToItemAtURL:[[CCUtility getDirectoryGroup] URLByAppendingPathComponent:k_DirectoryProviderStorage]];
    [CCUtility addSkipBackupAttributeToItemAtURL:[[CCUtility getDirectoryGroup] URLByAppendingPathComponent:k_appUserData]];
    
    #ifdef DEBUG
    NSLog(@"[LOG] Copy DB on Documents directory");
    NSString *atPathDB = [NSString stringWithFormat:@"%@/nextcloud.realm", [[dirGroup URLByAppendingPathComponent:k_appDatabaseNextcloud] path]];
    NSString *toPathDB = [NSString stringWithFormat:@"%@/nextcloud.realm", [CCUtility getDirectoryDocuments]];
    [[NSFileManager defaultManager] removeItemAtPath:toPathDB error:nil];
    [[NSFileManager defaultManager] copyItemAtPath:atPathDB toPath:toPathDB error:nil];
    #endif
}

+ (NSURL *)getDirectoryGroup
{
    NSURL *path = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[NCBrandOptions sharedInstance].capabilitiesGroups];
    return path;
}

+ (NSString *)getStringUser:(NSString *)user urlBase:(NSString *)urlBase
{
    NSString *baseUrl = [urlBase lowercaseString];
    NSString *dirUserBaseUrl = @"";

    if ([user length] && [baseUrl length]) {
        
        if ([baseUrl hasPrefix:@"https://"]) baseUrl = [baseUrl substringFromIndex:8];
        if ([baseUrl hasPrefix:@"http://"]) baseUrl = [baseUrl substringFromIndex:7];
        
        dirUserBaseUrl = [NSString stringWithFormat:@"%@-%@", user, baseUrl];
        dirUserBaseUrl = [[self removeForbiddenCharactersFileSystem:dirUserBaseUrl] lowercaseString];
    }
    
    return dirUserBaseUrl;
}

// Return the path of directory Documents -> NSDocumentDirectory
+ (NSString *)getDirectoryDocuments
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    return [paths objectAtIndex:0];
}

+ (NSString *)getDirectoryReaderMetadata
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    
    return [NSString stringWithFormat:@"%@/Reader Metadata", [paths objectAtIndex:0]];
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
    NSString *path = [[[CCUtility getDirectoryGroup] URLByAppendingPathComponent:k_appCertificates] path];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    
    return path;
}

+ (NSString *)getDirectoryUserData
{
    NSString *path = [[[CCUtility getDirectoryGroup] URLByAppendingPathComponent:k_appUserData] path];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    
    return path;
}

+ (NSString *)getDirectoryProviderStorage
{
    NSString *path = [[[CCUtility getDirectoryGroup] URLByAppendingPathComponent:k_DirectoryProviderStorage] path];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];

    return path;
}

+ (NSString *)getDirectoryProviderStorageOcId:(NSString *)ocId
{
    NSString *path = [NSString stringWithFormat:@"%@/%@", [self getDirectoryProviderStorage], ocId];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];

    return path;
}

+ (NSString *)getDirectoryProviderStorageOcId:(NSString *)ocId fileNameView:(NSString *)fileNameView
{
    NSString *fileNamePath = [NSString stringWithFormat:@"%@/%@", [self getDirectoryProviderStorageOcId:ocId], fileNameView];
    
    // if do not exists create file 0 length
    if ([[NSFileManager defaultManager] fileExistsAtPath:fileNamePath] == NO) {
        [[NSFileManager defaultManager] createFileAtPath:fileNamePath contents:nil attributes:nil];
    }
    
    return fileNamePath;
}

+ (NSString *)getDirectoryProviderStorageIconOcId:(NSString *)ocId etag:(NSString *)etag
{
    return [NSString stringWithFormat:@"%@/%@.small.ico", [self getDirectoryProviderStorageOcId:ocId], etag];
}

+ (NSString *)getDirectoryProviderStoragePreviewOcId:(NSString *)ocId etag:(NSString *)etag
{
    return [NSString stringWithFormat:@"%@/%@.preview.ico", [self getDirectoryProviderStorageOcId:ocId], etag];
}

+ (BOOL)fileProviderStorageExists:(NSString *)ocId fileNameView:(NSString *)fileNameView
{
    NSString *fileNamePath = [self getDirectoryProviderStorageOcId:ocId fileNameView:fileNameView];
    
    unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:fileNamePath error:nil] fileSize];
    
    if (fileSize > 0) return true;
    else return false;
}

+ (double)fileProviderStorageSize:(NSString *)ocId fileNameView:(NSString *)fileNameView
{
    NSString *fileNamePath = [self getDirectoryProviderStorageOcId:ocId fileNameView:fileNameView];
    
    double fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:fileNamePath error:nil] fileSize];
    
    return fileSize;
}

+ (BOOL)fileProviderStoragePreviewIconExists:(NSString *)ocId etag:(NSString *)etag
{
    NSString *fileNamePathPreview = [self getDirectoryProviderStoragePreviewOcId:ocId etag:etag];
    NSString *fileNamePathIcon = [self getDirectoryProviderStorageIconOcId:ocId etag:etag];
    
    unsigned long long fileSizePreview = [[[NSFileManager defaultManager] attributesOfItemAtPath:fileNamePathPreview error:nil] fileSize];
    unsigned long long fileSizeIcon = [[[NSFileManager defaultManager] attributesOfItemAtPath:fileNamePathIcon error:nil] fileSize];
    
    if (fileSizePreview > 0 && fileSizeIcon > 0) return true;
    else return false;
}

+ (void)removeGroupApplicationSupport
{
    NSURL *dirGroup = [CCUtility getDirectoryGroup];
    NSString *path = [[dirGroup URLByAppendingPathComponent:k_appApplicationSupport] path];
    
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

+ (void)removeGroupLibraryDirectory
{
    [[NSFileManager defaultManager] removeItemAtPath:[CCUtility getDirectoryScan] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[CCUtility getDirectoryUserData] error:nil];
}

+ (void)removeGroupDirectoryProviderStorage
{
    [[NSFileManager defaultManager] removeItemAtPath:[CCUtility getDirectoryProviderStorage] error:nil];
}

+ (void)removeDocumentsDirectory
{
    [[NSFileManager defaultManager] removeItemAtPath:[CCUtility getDirectoryDocuments] error:nil];
}

+ (void)removeTemporaryDirectory
{
    [[NSFileManager defaultManager] removeItemAtPath:NSTemporaryDirectory() error:nil];
}

+ (void)emptyTemporaryDirectory
{
    NSArray* tmpDirectory = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:NULL];
    for (NSString *file in tmpDirectory) {
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), file] error:NULL];
    }
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

+ (void)moveFileAtPath:(NSString *)atPath toPath:(NSString *)toPath
{
    [[NSFileManager defaultManager] removeItemAtPath:toPath error:nil];
    [[NSFileManager defaultManager] copyItemAtPath:atPath toPath:toPath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:atPath error:nil];
}

+ (void)copyFileAtPath:(NSString *)atPath toPath:(NSString *)toPath
{
    [[NSFileManager defaultManager] removeItemAtPath:toPath error:nil];
    [[NSFileManager defaultManager] copyItemAtPath:atPath toPath:toPath error:nil];
}

+ (void)removeFileAtPath:(NSString *)atPath
{
    [[NSFileManager defaultManager] removeItemAtPath:atPath error:nil];
}

+ (void)createDirectoryAtPath:(NSString *)atPath
{
    [[NSFileManager defaultManager] createDirectoryAtPath:atPath withIntermediateDirectories:true attributes:nil error:nil];
}

+ (NSString *)deletingLastPathComponentFromServerUrl:(NSString *)serverUrl
{
    NSURL *url = [[NSURL URLWithString:[serverUrl stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLFragmentAllowedCharacterSet]]] URLByDeletingLastPathComponent];
    NSString *pather = [[url absoluteString] stringByRemovingPercentEncoding];
    
    return [pather substringToIndex: [pather length] - 1];
}

+ (NSString *)getLastPathFromServerUrl:(NSString *)serverUrl urlBase:(NSString *)urlBase
{
    if ([serverUrl isEqualToString:urlBase])
        return @"";
    
    NSURL *serverUrlURL = [NSURL URLWithString:[serverUrl stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLFragmentAllowedCharacterSet]]];
    NSString *fileName = [serverUrlURL lastPathComponent];

    return fileName;
}

+ (NSString *)returnPathfromServerUrl:(NSString *)serverUrl urlBase:(NSString *)urlBase account:(NSString *)account
{
    NSString *homeServer = [[NCUtility shared] getHomeServerWithUrlBase:urlBase account:account];
    NSString *path = [serverUrl stringByReplacingOccurrencesOfString:homeServer withString:@""];
    return path;
}
                                       
+ (NSString *)returnFileNamePathFromFileName:(NSString *)metadataFileName serverUrl:(NSString *)serverUrl urlBase:(NSString *)urlBase account:(NSString *)account
{
    if (metadataFileName == nil || serverUrl == nil || urlBase == nil) {
        return @"";
    }
    
    NSString *homeServer = [[NCUtility shared] getHomeServerWithUrlBase:urlBase account:account];
    NSString *fileName = [NSString stringWithFormat:@"%@/%@", [serverUrl stringByReplacingOccurrencesOfString:homeServer withString:@""], metadataFileName];
    
    if ([fileName hasPrefix:@"/"]) fileName = [fileName substringFromIndex:1];
    
    return fileName;
}

+ (NSArray *)createNameSubFolder:(NSArray *)assets
{
    NSMutableOrderedSet *datesSubFolder = [NSMutableOrderedSet new];
    
    for (PHAsset *asset in assets) {
        
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

+ (NSString *)getDirectoryScan
{
    NSString *path = [[[CCUtility getDirectoryGroup] URLByAppendingPathComponent:k_appScan] path];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    
    return path;
}

+ (void)writeData:(NSData *)data fileNamePath:(NSString *)fileNamePath
{
    [data writeToFile:fileNamePath atomically:YES];
}

+ (void)selectFileNameFrom:(UITextField *)textField
{
    UITextPosition *endPosition;
    NSRange rangeDot = [textField.text rangeOfString:@"." options:NSBackwardsSearch];
    
    if (rangeDot.location != NSNotFound) {
        endPosition = [textField positionFromPosition:textField.beginningOfDocument offset:rangeDot.location];
    } else {
        endPosition = textField.endOfDocument;
    }
    
    UITextRange *textRange = [textField textRangeFromPosition:textField.beginningOfDocument toPosition:endPosition];
    textField.selectedTextRange = textRange;
}

+ (NSString *)getTimeIntervalSince197
{
    return [NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]];
}

+ (void)extractImageVideoFromAssetLocalIdentifierForUpload:(tableMetadata *)metadataForUpload notification:(BOOL)notification completion:(void(^)(tableMetadata *metadata, NSString* fileNamePath))completion
{
    if (metadataForUpload == nil) {
        completion(nil, nil);
        return;
    }
    
    tableMetadata *metadata = [[NCManageDatabase sharedInstance] copyObjectWithMetadata:metadataForUpload];
    
    PHFetchResult *result = [PHAsset fetchAssetsWithLocalIdentifiers:@[metadata.assetLocalIdentifier] options:nil];
    if (!result.count) {
        if (notification) {
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_uploadedFile object:nil userInfo:@{@"metadata": metadata, @"errorCode": @(k_CCErrorInternalError), @"errorDescription": @"_err_asset_not_found_"}];
        }
        
        completion(nil, nil);
        return;
    }
    
    PHAsset *asset = result[0];
    NSDate *creationDate = asset.creationDate;
    NSDate *modificationDate = asset.modificationDate;
    NSArray *resourceArray = [PHAssetResource assetResourcesForAsset:asset];
    long fileSize = [[resourceArray.firstObject valueForKey:@"fileSize"] longValue];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    
        // IMAGE
        if (asset.mediaType == PHAssetMediaTypeImage) {
            
            PHImageRequestOptions *options = [PHImageRequestOptions new];
            options.networkAccessAllowed = YES;
            options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
            options.synchronous = YES;
            options.progressHandler = ^(double progress, NSError *error, BOOL *stop, NSDictionary *info) {
                
                NSLog(@"cacheAsset: %f", progress);
                
                if (error) {
                    if (notification) {
                        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_uploadedFile object:nil userInfo:@{@"metadata": metadata, @"errorCode": @(error.code), @"errorDescription": [NSString stringWithFormat:@"Image request iCloud failed [%@]", error.description]}];
                    }
                    
                    completion(nil, nil);
                    return;
                }
            };
            
            [[PHImageManager defaultManager] requestImageDataForAsset:asset options:options resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
                
                NSError *error = nil;
                NSString *extensionAsset = [[[asset valueForKey:@"filename"] pathExtension] uppercaseString];
                NSString *fileName = metadata.fileNameView;

                if ([extensionAsset isEqualToString:@"HEIC"] && [CCUtility getFormatCompatibility]) {
                    
                    CIImage *ciImage = [CIImage imageWithData:imageData];
                    CIContext *context = [CIContext context];
                    imageData = [context JPEGRepresentationOfImage:ciImage colorSpace:ciImage.colorSpace options:@{}];
                    
                    NSString *fileNameJPEG = [[metadata.fileName lastPathComponent] stringByDeletingPathExtension];
                    fileName = [fileNameJPEG stringByAppendingString:@".jpg"];
                    metadata.contentType = @"image/jpeg";
                }
                
                NSString *fileNamePath = [NSTemporaryDirectory() stringByAppendingString:fileName];
                
                [[NSFileManager defaultManager]removeItemAtPath:fileNamePath error:nil];
                [imageData writeToFile:fileNamePath options:NSDataWritingAtomic error:&error];
                
                if (metadata.e2eEncrypted) {
                    metadata.fileNameView = fileName;
                } else {
                    metadata.fileNameView = fileName;
                    metadata.fileName = fileName;
                }
                     
                metadata.creationDate = creationDate;
                metadata.date = modificationDate;
                metadata.size = fileSize;
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(metadata, fileNamePath);
                });
            }];
        }
    
        // VIDEO
        if (asset.mediaType == PHAssetMediaTypeVideo) {
            
            PHVideoRequestOptions *options = [PHVideoRequestOptions new];
            options.networkAccessAllowed = YES;
            options.version = PHVideoRequestOptionsVersionOriginal;
            options.progressHandler = ^(double progress, NSError *error, BOOL *stop, NSDictionary *info) {
                
                NSLog(@"cacheAsset: %f", progress);
                
                if (error) {
                    if (notification) {
                        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_uploadedFile object:nil userInfo:@{@"metadata": metadata, @"errorCode": @(error.code), @"errorDescription": [NSString stringWithFormat:@"Video request iCloud failed [%@]", error.description]}];
                    }
                    
                    completion(nil, nil);
                }
            };
            
            [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:options resultHandler:^(AVAsset *asset, AVAudioMix *audioMix, NSDictionary *info) {
                
                if ([asset isKindOfClass:[AVURLAsset class]]) {
                    
                    NSString *fileNamePath = [NSTemporaryDirectory() stringByAppendingString:metadata.fileNameView];
                    NSURL *fileNamePathURL = [[NSURL alloc] initFileURLWithPath:fileNamePath];
                    NSError *error = nil;
                                       
                    [[NSFileManager defaultManager] removeItemAtURL:fileNamePathURL error:nil];
                    [[NSFileManager defaultManager] copyItemAtURL:[(AVURLAsset *)asset URL] toURL:fileNamePathURL error:&error];
                        
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        if (error) {
                            
                            if (notification) {
                                [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_uploadedFile object:nil userInfo:@{@"metadata": metadata, @"errorCode": @(error.code), @"errorDescription": [NSString stringWithFormat:@"Video request iCloud failed [%@]", error.description]}];
                            }
                            
                            completion(nil, nil);
                            
                        } else {
                            
                            metadata.creationDate = creationDate;
                            metadata.date = modificationDate;
                            metadata.size = fileSize;
                            
                            completion(metadata, fileNamePath);
                        }
                    });
                }
            }];
        }
    });
}

+ (void)extractLivePhotoAsset:(PHAsset*)asset filePath:(NSString *)filePath withCompletion:(void (^)(NSURL* url))completion
{    
    [CCUtility removeFileAtPath:filePath];
    NSURL *fileUrl = [NSURL fileURLWithPath:filePath];
    PHLivePhotoRequestOptions *options = [PHLivePhotoRequestOptions new];
    options.deliveryMode = PHImageRequestOptionsDeliveryModeFastFormat;
    options.networkAccessAllowed = YES;
    
    [[PHImageManager defaultManager] requestLivePhotoForAsset:asset targetSize:[UIScreen mainScreen].bounds.size contentMode:PHImageContentModeDefault options:options resultHandler:^(PHLivePhoto * _Nullable livePhoto, NSDictionary * _Nullable info) {
        if (livePhoto) {
            NSArray *assetResources = [PHAssetResource assetResourcesForLivePhoto:livePhoto];
            PHAssetResource *videoResource = nil;
            for(PHAssetResource *resource in assetResources){
                if (resource.type == PHAssetResourceTypePairedVideo) {
                    videoResource = resource;
                    break;
                }
            }
            if(videoResource){
                [[PHAssetResourceManager defaultManager] writeDataForAssetResource:videoResource toFile:fileUrl options:nil completionHandler:^(NSError * _Nullable error) {
                    if (!error) {
                        completion(fileUrl);
                    } else { completion(nil); }
                }];
            } else { completion(nil); }
        } else { completion(nil); }
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== E2E Encrypted =====
#pragma --------------------------------------------------------------------------------------------

+ (NSString *)generateRandomIdentifier
{
    NSString *UUID = [[NSUUID UUID] UUIDString];
    
    return [[UUID stringByReplacingOccurrencesOfString:@"-" withString:@""] lowercaseString];
}

+ (BOOL)isFolderEncrypted:(NSString *)serverUrl e2eEncrypted:(BOOL)e2eEncrypted account:(NSString *)account urlBase:(NSString *)urlBase
{
    NSString *home = [[NCUtility shared] getHomeServerWithUrlBase:urlBase account:account];
        
    if (e2eEncrypted) {
    
        return true;
        
    } else if ([serverUrl isEqualToString:home] || [serverUrl isEqualToString:@".."]) {
        
        return false;

    } else {
       
        tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", account, serverUrl]];
        
        while (directory != nil) {
            if (directory.e2eEncrypted == true) {
                return true;
            }
            serverUrl = [CCUtility deletingLastPathComponentFromServerUrl:serverUrl];
            directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", account, serverUrl]];
        }
        
        return false;
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Share Permissions =====
#pragma --------------------------------------------------------------------------------------------

+ (NSInteger) getPermissionsValueByCanEdit:(BOOL)canEdit andCanCreate:(BOOL)canCreate andCanChange:(BOOL)canChange andCanDelete:(BOOL)canDelete andCanShare:(BOOL)canShare andIsFolder:(BOOL) isFolder
{    
    NSInteger permissionsValue = k_read_share_permission;
    
    if (canEdit && !isFolder) {
        permissionsValue = permissionsValue + k_update_share_permission;
    }
    if (canCreate & isFolder) {
        permissionsValue = permissionsValue + k_create_share_permission;
    }
    if (canChange && isFolder) {
        permissionsValue = permissionsValue + k_update_share_permission;
    }
    if (canDelete & isFolder) {
        permissionsValue = permissionsValue + k_delete_share_permission;
    }
    if (canShare) {
        permissionsValue = permissionsValue + k_share_share_permission;
    }
    
    return permissionsValue;
}

+ (BOOL) isPermissionToCanCreate:(NSInteger) permissionValue {
    BOOL canCreate = ((permissionValue & k_create_share_permission) > 0);
    return canCreate;
}

+ (BOOL) isPermissionToCanChange:(NSInteger) permissionValue {
    BOOL canChange = ((permissionValue & k_update_share_permission) > 0);
    return canChange;
}

+ (BOOL) isPermissionToCanDelete:(NSInteger) permissionValue {
    BOOL canDelete = ((permissionValue & k_delete_share_permission) > 0);
    return canDelete;
}

+ (BOOL) isPermissionToCanShare:(NSInteger) permissionValue {
    BOOL canShare = ((permissionValue & k_share_share_permission) > 0);
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
    BOOL canRead = ((permissionValue & k_read_share_permission) > 0);
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

+ (NSString*)hexRepresentation:(NSData *)data spaces:(BOOL)spaces
{
    const unsigned char* bytes = (const unsigned char*)[data bytes];
    NSUInteger nbBytes = [data length];
    //If spaces is true, insert a space every this many input bytes (twice this many output characters).
    static const NSUInteger spaceEveryThisManyBytes = 4UL;
    //If spaces is true, insert a line-break instead of a space every this many spaces.
    static const NSUInteger lineBreakEveryThisManySpaces = 4UL;
    const NSUInteger lineBreakEveryThisManyBytes = spaceEveryThisManyBytes * lineBreakEveryThisManySpaces;
    NSUInteger strLen = 2*nbBytes + (spaces ? nbBytes/spaceEveryThisManyBytes : 0);
    
    NSMutableString* hex = [[NSMutableString alloc] initWithCapacity:strLen];
    for(NSUInteger i=0; i<nbBytes; ) {
        [hex appendFormat:@"%02X", bytes[i]];
        //We need to increment here so that the every-n-bytes computations are right.
        ++i;
        
        if (spaces) {
            if (i % lineBreakEveryThisManyBytes == 0) [hex appendString:@"\n"];
            else if (i % spaceEveryThisManyBytes == 0) [hex appendString:@" "];
        }
    }
    return hex;
}

+ (NSString *)valueForKey:(NSString *)key fromQueryItems:(NSArray *)queryItems
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name=%@", key];
    NSURLQueryItem *queryItem = [[queryItems filteredArrayUsingPredicate:predicate] firstObject];
    return queryItem.value;
}

@end
