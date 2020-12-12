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
#import <CoreLocation/CoreLocation.h>

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
    [UICKeyChainStore removeAllItemsForService:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (void)storeAllChainInService
{
    UICKeyChainStore *store = [UICKeyChainStore keyChainStore];
    
    NSArray *items = store.allItems;
    
    for (NSDictionary *item in items) {
        
        [UICKeyChainStore setString:[item objectForKey:@"value"] forKey:[item objectForKey:@"key"] service:NCBrandGlobal.shared.serviceShareKeyChain];
        [UICKeyChainStore removeItemForKey:[item objectForKey:@"key"]];
    }
}

#pragma ------------------------------ GET/SET

+ (NSString *)getPasscode
{
    return [UICKeyChainStore stringForKey:@"passcodeBlock" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (void)setPasscode:(NSString *)passcode
{
    [UICKeyChainStore setString:passcode forKey:@"passcodeBlock" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (BOOL)getNotPasscodeAtStart
{
    return [[UICKeyChainStore stringForKey:@"notPasscodeAtStart" service:NCBrandGlobal.shared.serviceShareKeyChain] boolValue];
}

+ (void)setNotPasscodeAtStart:(BOOL)set
{
    NSString *sSet = (set) ? @"true" : @"false";
    [UICKeyChainStore setString:sSet forKey:@"notPasscodeAtStart" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (BOOL)getEnableTouchFaceID
{
    NSString *valueString = [UICKeyChainStore stringForKey:@"enableTouchFaceID" service:NCBrandGlobal.shared.serviceShareKeyChain];
    
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
    [UICKeyChainStore setString:sSet forKey:@"enableTouchFaceID" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (NSString *)getGroupBySettings
{
    NSString *groupby = [UICKeyChainStore stringForKey:@"groupby" service:NCBrandGlobal.shared.serviceShareKeyChain];
    
    if (groupby == nil) {
        
        [self setGroupBySettings:@"none"];
        return @"none";
    }
    
    return @"none";
    
    //return groupby;
}

+ (void)setGroupBySettings:(NSString *)groupby
{
    [UICKeyChainStore setString:groupby forKey:@"groupby" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (BOOL)getIntro
{
    // Set compatibility old version don't touch me
    if ([[UICKeyChainStore stringForKey:[INTRO_MessageType stringByAppendingString:@"Intro"] service:NCBrandGlobal.shared.serviceShareKeyChain] boolValue] == YES) {
        [CCUtility setIntro:YES];
        return YES;
    }
    
    return [[UICKeyChainStore stringForKey:@"intro" service:NCBrandGlobal.shared.serviceShareKeyChain] boolValue];
}

+ (BOOL)getIntroMessageOldVersion
{
    NSString *key = [INTRO_MessageType stringByAppendingString:@"Intro"];
    
    return [[UICKeyChainStore stringForKey:key service:NCBrandGlobal.shared.serviceShareKeyChain] boolValue];
}

+ (void)setIntro:(BOOL)set
{
    NSString *sIntro = (set) ? @"true" : @"false";
    [UICKeyChainStore setString:sIntro forKey:@"intro" service:NCBrandGlobal.shared.serviceShareKeyChain];

}

+ (NSString *)getIncrementalNumber
{
    long number = [[UICKeyChainStore stringForKey:@"incrementalnumber" service:NCBrandGlobal.shared.serviceShareKeyChain] intValue];
    
    number++;
    if (number >= 9999) number = 1;
    
    [UICKeyChainStore setString:[NSString stringWithFormat:@"%ld", number] forKey:@"incrementalnumber" service:NCBrandGlobal.shared.serviceShareKeyChain];
    
    return [NSString stringWithFormat:@"%04ld", number];
}

+ (NSString *)getAccountExt
{
    return [UICKeyChainStore stringForKey:@"accountExt" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (void)setAccountExt:(NSString *)account
{
    [UICKeyChainStore setString:account forKey:@"accountExt" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (NSString *)getServerUrlExt
{
    return [UICKeyChainStore stringForKey:@"serverUrlExt" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (void)setServerUrlExt:(NSString *)serverUrl
{
    [UICKeyChainStore setString:serverUrl forKey:@"serverUrlExt" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (NSString *)getTitleServerUrlExt
{
    return [UICKeyChainStore stringForKey:@"titleServerUrlExt" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (void)setTitleServerUrlExt:(NSString *)titleServerUrl
{
    [UICKeyChainStore setString:titleServerUrl forKey:@"titleServerUrlExt" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (NSString *)getFileNameExt
{
    return [UICKeyChainStore stringForKey:@"fileNameExt" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (void)setFileNameExt:(NSString *)fileName
{
    [UICKeyChainStore setString:fileName forKey:@"fileNameExt" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (NSString *)getEmail
{
    return [UICKeyChainStore stringForKey:@"email" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (void)setEmail:(NSString *)email
{
    [UICKeyChainStore setString:email forKey:@"email" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (NSString *)getHint
{
    return [UICKeyChainStore stringForKey:@"hint" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (void)setHint:(NSString *)hint
{
    [UICKeyChainStore setString:hint forKey:@"hint" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (BOOL)getOriginalFileName:(NSString *)key
{
    return [[UICKeyChainStore stringForKey:key service:NCBrandGlobal.shared.serviceShareKeyChain] boolValue];
}

+ (void)setOriginalFileName:(BOOL)value key:(NSString *)key
{
    NSString *sValue = (value) ? @"true" : @"false";
    [UICKeyChainStore setString:sValue forKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (NSString *)getFileNameMask:(NSString *)key
{
    NSString *mask = [UICKeyChainStore stringForKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
    
    if (mask == nil)
        mask = @"";
    
    return mask;
}

+ (void)setFileNameMask:(NSString *)mask key:(NSString *)key
{
    [UICKeyChainStore setString:mask forKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (BOOL)getFileNameType:(NSString *)key
{
    return [[UICKeyChainStore stringForKey:key service:NCBrandGlobal.shared.serviceShareKeyChain] boolValue];
}

+ (void)setFileNameType:(BOOL)prefix key:(NSString *)key
{
    NSString *sPrefix = (prefix) ? @"true" : @"false";
    [UICKeyChainStore setString:sPrefix forKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (BOOL)getFavoriteOffline
{
    return [[UICKeyChainStore stringForKey:@"favoriteOffline" service:NCBrandGlobal.shared.serviceShareKeyChain] boolValue];
}

+ (void)setFavoriteOffline:(BOOL)offline
{
    NSString *sFavoriteOffline = (offline) ? @"true" : @"false";
    [UICKeyChainStore setString:sFavoriteOffline forKey:@"favoriteOffline" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (BOOL)getActivityVerboseHigh
{
    return [[UICKeyChainStore stringForKey:@"activityVerboseHigh" service:NCBrandGlobal.shared.serviceShareKeyChain] boolValue];
}

+ (void)setActivityVerboseHigh:(BOOL)high
{
    NSString *sHigh = (high) ? @"true" : @"false";
    [UICKeyChainStore setString:sHigh forKey:@"activityVerboseHigh" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (BOOL)getShowHiddenFiles
{
    return [[UICKeyChainStore stringForKey:@"showHiddenFiles" service:NCBrandGlobal.shared.serviceShareKeyChain] boolValue];
}

+ (void)setShowHiddenFiles:(BOOL)show
{
    NSString *sShow = (show) ? @"true" : @"false";
    [UICKeyChainStore setString:sShow forKey:@"showHiddenFiles" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (BOOL)getFormatCompatibility
{
    NSString *valueString = [UICKeyChainStore stringForKey:@"formatCompatibility" service:NCBrandGlobal.shared.serviceShareKeyChain];
    
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
    [UICKeyChainStore setString:sSet forKey:@"formatCompatibility" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (NSString *)getEndToEndPublicKey:(NSString *)account
{
    NSString *key = [E2E_PublicKey stringByAppendingString:account];
    return [UICKeyChainStore stringForKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (void)setEndToEndPublicKey:(NSString *)account publicKey:(NSString *)publicKey
{
    NSString *key = [E2E_PublicKey stringByAppendingString:account];
    [UICKeyChainStore setString:publicKey forKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (NSString *)getEndToEndPrivateKey:(NSString *)account
{
    NSString *key = [E2E_PrivateKey stringByAppendingString:account];
    return [UICKeyChainStore stringForKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (void)setEndToEndPrivateKey:(NSString *)account privateKey:(NSString *)privateKey
{
    NSString *key = [E2E_PrivateKey stringByAppendingString:account];
    [UICKeyChainStore setString:privateKey forKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (NSString *)getEndToEndPassphrase:(NSString *)account
{
    NSString *key = [E2E_Passphrase stringByAppendingString:account];
    return [UICKeyChainStore stringForKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (void)setEndToEndPassphrase:(NSString *)account passphrase:(NSString *)passphrase
{
    NSString *key = [E2E_Passphrase stringByAppendingString:account];
    [UICKeyChainStore setString:passphrase forKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (NSString *)getEndToEndPublicKeyServer:(NSString *)account
{
    NSString *key = [E2E_PublicKeyServer stringByAppendingString:account];
    return [UICKeyChainStore stringForKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (void)setEndToEndPublicKeyServer:(NSString *)account publicKey:(NSString *)publicKey
{
    NSString *key = [E2E_PublicKeyServer stringByAppendingString:account];
    [UICKeyChainStore setString:publicKey forKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (BOOL)isEndToEndEnabled:(NSString *)account
{
    BOOL isE2EEEnabled = [[NCManageDatabase shared] getCapabilitiesServerBoolWithAccount:account elements:NCElementsJSON.shared.capabilitiesE2EEEnabled exists:false];
    NSString* versionE2EE = [[NCManageDatabase shared] getCapabilitiesServerStringWithAccount:account elements:NCElementsJSON.shared.capabilitiesE2EEApiVersion];
    
    NSString *publicKey = [self getEndToEndPublicKey:account];
    NSString *privateKey = [self getEndToEndPrivateKey:account];
    NSString *passphrase = [self getEndToEndPassphrase:account];
    NSString *publicKeyServer = [self getEndToEndPublicKeyServer:account];    
            
    if (passphrase.length > 0 && privateKey.length > 0 && publicKey.length > 0 && publicKeyServer.length > 0 && isE2EEEnabled && [versionE2EE isEqual:[[NCBrandGlobal shared] e2eeVersion]]) {
       
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
    return [[UICKeyChainStore stringForKey:@"disablefilesapp" service:NCBrandGlobal.shared.serviceShareKeyChain] boolValue];
}

+ (void)setDisableFilesApp:(BOOL)disable
{
    NSString *sDisable = (disable) ? @"true" : @"false";
    [UICKeyChainStore setString:sDisable forKey:@"disablefilesapp" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (void)setPushNotificationPublicKey:(NSString *)account data:(NSData *)data
{
    NSString *key = [@"PNPublicKey" stringByAppendingString:account];
    [UICKeyChainStore setData:data forKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (NSData *)getPushNotificationPublicKey:(NSString *)account
{
    NSString *key = [@"PNPublicKey" stringByAppendingString:account];
    return [UICKeyChainStore dataForKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (void)setPushNotificationSubscribingPublicKey:(NSString *)account publicKey:(NSString *)publicKey
{
    NSString *key = [@"PNSubscribingPublicKey" stringByAppendingString:account];
    [UICKeyChainStore setString:publicKey forKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (NSString *)getPushNotificationSubscribingPublicKey:(NSString *)account
{
    NSString *key = [@"PNSubscribingPublicKey" stringByAppendingString:account];
    return [UICKeyChainStore stringForKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (void)setPushNotificationPrivateKey:(NSString *)account data:(NSData *)data
{
    NSString *key = [@"PNPrivateKey" stringByAppendingString:account];
    [UICKeyChainStore setData:data forKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (NSData *)getPushNotificationPrivateKey:(NSString *)account
{
    NSString *key = [@"PNPrivateKey" stringByAppendingString:account];
    return [UICKeyChainStore dataForKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (void)setPushNotificationToken:(NSString *)account token:(NSString *)token
{
    NSString *key = [@"PNToken" stringByAppendingString:account];
    [UICKeyChainStore setString:token forKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (NSString *)getPushNotificationToken:(NSString *)account
{
    NSString *key = [@"PNToken" stringByAppendingString:account];
    return [UICKeyChainStore stringForKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (void)setPushNotificationDeviceIdentifier:(NSString *)account deviceIdentifier:(NSString *)deviceIdentifier
{
    NSString *key = [@"PNDeviceIdentifier" stringByAppendingString:account];
    [UICKeyChainStore setString:deviceIdentifier forKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (NSString *)getPushNotificationDeviceIdentifier:(NSString *)account
{
    NSString *key = [@"PNDeviceIdentifier" stringByAppendingString:account];
    return [UICKeyChainStore stringForKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (void)setPushNotificationDeviceIdentifierSignature:(NSString *)account deviceIdentifierSignature:(NSString *)deviceIdentifierSignature
{
    NSString *key = [@"PNDeviceIdentifierSignature" stringByAppendingString:account];
    [UICKeyChainStore setString:deviceIdentifierSignature forKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (NSString *)getPushNotificationDeviceIdentifierSignature:(NSString *)account
{
    NSString *key = [@"PNDeviceIdentifierSignature" stringByAppendingString:account];
    return [UICKeyChainStore stringForKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
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
    NSString *width = [UICKeyChainStore stringForKey:@"mediaWidthImage" service:NCBrandGlobal.shared.serviceShareKeyChain];
    
    if (width == nil) {
        return 80;
    } else {
        return [width integerValue];
    }
}

+ (void)setMediaWidthImage:(NSInteger)width
{
    NSString *widthString = [@(width) stringValue];
    [UICKeyChainStore setString:widthString forKey:@"mediaWidthImage" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (BOOL)getDisableCrashservice
{
    return [[UICKeyChainStore stringForKey:@"crashservice" service:NCBrandGlobal.shared.serviceShareKeyChain] boolValue];
}

+ (void)setDisableCrashservice:(BOOL)disable
{
    NSString *sDisable = (disable) ? @"true" : @"false";
    [UICKeyChainStore setString:sDisable forKey:@"crashservice" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (void)setPassword:(NSString *)account password:(NSString *)password
{
    NSString *key = [@"password" stringByAppendingString:account];
    [UICKeyChainStore setString:password forKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (NSString *)getPassword:(NSString *)account
{
    NSString *key = [@"password" stringByAppendingString:account];
    return [UICKeyChainStore stringForKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (void)setHCBusinessType:(NSString *)professions
{
    [UICKeyChainStore setString:professions forKey:@"businessType" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (NSString *)getHCBusinessType
{
    return [UICKeyChainStore stringForKey:@"businessType" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (NSData *)getDatabaseEncryptionKey
{
    NSData *key = [UICKeyChainStore dataForKey:@"databaseEncryptionKey" service:NCBrandGlobal.shared.serviceShareKeyChain];
    if (key == nil) {
        NSMutableData *key = [NSMutableData dataWithLength:64];
        (void)SecRandomCopyBytes(kSecRandomDefault, key.length, (uint8_t *)key.mutableBytes);
        [UICKeyChainStore setData:key forKey:@"databaseEncryptionKey" service:NCBrandGlobal.shared.serviceShareKeyChain];
        return key;
    } else {
        return key;
    }
}

+ (void)setDatabaseEncryptionKey:(NSData *)data
{
    [UICKeyChainStore setData:data forKey:@"databaseEncryptionKey" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (BOOL)getCertificateError:(NSString *)account
{
    NSString *key = [@"certificateError" stringByAppendingString:account];
    NSString *error = [UICKeyChainStore stringForKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
    
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
    
    [UICKeyChainStore setString:sError forKey:key service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (BOOL)getDisableLocalCacheAfterUpload
{
    return [[UICKeyChainStore stringForKey:@"disableLocalCacheAfterUpload" service:NCBrandGlobal.shared.serviceShareKeyChain] boolValue];
}

+ (void)setDisableLocalCacheAfterUpload:(BOOL)disable
{
    NSString *sDisable = (disable) ? @"true" : @"false";
    [UICKeyChainStore setString:sDisable forKey:@"disableLocalCacheAfterUpload" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (BOOL)getDarkMode
{
    NSString *sDisable = [UICKeyChainStore stringForKey:@"darkMode" service:NCBrandGlobal.shared.serviceShareKeyChain];
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
    [UICKeyChainStore setString:sDisable forKey:@"darkMode" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (BOOL)getDarkModeDetect
{
    NSString *valueString = [UICKeyChainStore stringForKey:@"darkModeDetect" service:NCBrandGlobal.shared.serviceShareKeyChain];
    
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
    [UICKeyChainStore setString:sDisable forKey:@"darkModeDetect" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (BOOL)getLivePhoto
{
    NSString *valueString = [UICKeyChainStore stringForKey:@"livePhoto" service:NCBrandGlobal.shared.serviceShareKeyChain];
    
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
    [UICKeyChainStore setString:sSet forKey:@"livePhoto" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (NSString *)getMediaSortDate
{
    NSString *valueString = [UICKeyChainStore stringForKey:@"mediaSortDate" service:NCBrandGlobal.shared.serviceShareKeyChain];
    
    // Default TRUE
    if (valueString == nil) {
        [self setMediaSortDate:@"date"];
        return @"date";
    }
    
    return valueString;
}

+ (void)setMediaSortDate:(NSString *)value
{
    [UICKeyChainStore setString:value forKey:@"mediaSortDate" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (NSInteger)getTextRecognitionStatus
{
    NSString *value = [UICKeyChainStore stringForKey:@"textRecognitionStatus" service:NCBrandGlobal.shared.serviceShareKeyChain];
    
    if (value == nil) {
        return 0;
    } else {
        return [value integerValue];
    }
}

+ (void)setTextRecognitionStatus:(NSInteger)value
{
    NSString *valueString = [@(value) stringValue];
    [UICKeyChainStore setString:valueString forKey:@"textRecognitionStatus" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (NSString *)getDirectoryScanDocuments
{
    return [UICKeyChainStore stringForKey:@"directoryScanDocuments" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (void)setDirectoryScanDocuments:(NSString *)value
{
    [UICKeyChainStore setString:value forKey:@"directoryScanDocuments" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (NSInteger)getLogLevel
{
    NSString *value = [UICKeyChainStore stringForKey:@"logLevel" service:NCBrandGlobal.shared.serviceShareKeyChain];
    
    if (value == nil) {
        return 1;
    } else {
        return [value integerValue];
    }
}

+ (void)setLogLevel:(NSInteger)value
{
    NSString *valueString = [@(value) stringValue];
    [UICKeyChainStore setString:valueString forKey:@"logLevel" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (BOOL)getAudioMute
{
    return [[UICKeyChainStore stringForKey:@"audioMute" service:NCBrandGlobal.shared.serviceShareKeyChain] boolValue];
}

+ (void)setAudioMute:(BOOL)set
{
    NSString *sSet = (set) ? @"true" : @"false";
    [UICKeyChainStore setString:sSet forKey:@"audioMute" service:NCBrandGlobal.shared.serviceShareKeyChain];
}

+ (BOOL)getAutomaticDownloadImage
{
    return [[UICKeyChainStore stringForKey:@"automaticDownloadImage" service:NCBrandGlobal.shared.serviceShareKeyChain] boolValue];
}

+ (void)setAutomaticDownloadImage:(BOOL)set
{
    NSString *sSet = (set) ? @"true" : @"false";
    [UICKeyChainStore setString:sSet forKey:@"automaticDownloadImage" service:NCBrandGlobal.shared.serviceShareKeyChain];
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
    NSString *userAgent = [[NCBrandOptions shared] userAgent];
    
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

+ (NSString *)transformedSize:(int64_t)value
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
    path = [[dirGroup URLByAppendingPathComponent:[[NCBrandGlobal shared] appDatabaseNextcloud]] path];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    [[NSFileManager defaultManager] setAttributes:@{NSFileProtectionKey:NSFileProtectionNone} ofItemAtPath:path error:nil];
    
    // create Directory User Data
    path = [[dirGroup URLByAppendingPathComponent:NCBrandGlobal.shared.appUserData] path];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    
    // create Directory Provider Storage
    path = [CCUtility getDirectoryProviderStorage];
    if (![[NSFileManager defaultManager] fileExistsAtPath: path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    
    // create Directory Scan
    path = [[dirGroup URLByAppendingPathComponent:NCBrandGlobal.shared.appScan] path];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    
    // create Directory Temp
    path = NSTemporaryDirectory();
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    
    // Directory Excluded From Backup
    [CCUtility addSkipBackupAttributeToItemAtURL:[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject]];
    [CCUtility addSkipBackupAttributeToItemAtURL:[[CCUtility getDirectoryGroup] URLByAppendingPathComponent:NCBrandGlobal.shared.directoryProviderStorage]];
    [CCUtility addSkipBackupAttributeToItemAtURL:[[CCUtility getDirectoryGroup] URLByAppendingPathComponent:NCBrandGlobal.shared.appUserData]];
    
    #ifdef DEBUG
    NSLog(@"[LOG] Copy DB on Documents directory");
    NSString *atPathDB = [NSString stringWithFormat:@"%@/nextcloud.realm", [[dirGroup URLByAppendingPathComponent:[[NCBrandGlobal shared] appDatabaseNextcloud]] path]];
    NSString *toPathDB = [NSString stringWithFormat:@"%@/nextcloud.realm", [CCUtility getDirectoryDocuments]];
    [[NSFileManager defaultManager] removeItemAtPath:toPathDB error:nil];
    [[NSFileManager defaultManager] copyItemAtPath:atPathDB toPath:toPathDB error:nil];
    #endif
}

+ (NSURL *)getDirectoryGroup
{
    NSURL *path = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[NCBrandOptions shared].capabilitiesGroups];
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
    NSString *path = [[[CCUtility getDirectoryGroup] URLByAppendingPathComponent:NCBrandGlobal.shared.appCertificates] path];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    
    return path;
}

+ (NSString *)getDirectoryUserData
{
    NSString *path = [[[CCUtility getDirectoryGroup] URLByAppendingPathComponent:NCBrandGlobal.shared.appUserData] path];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    
    return path;
}

+ (NSString *)getDirectoryProviderStorage
{
    NSString *path = [[[CCUtility getDirectoryGroup] URLByAppendingPathComponent:NCBrandGlobal.shared.directoryProviderStorage] path];
    
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

+ (int64_t)fileProviderStorageSize:(NSString *)ocId fileNameView:(NSString *)fileNameView
{
    NSString *fileNamePath = [self getDirectoryProviderStorageOcId:ocId fileNameView:fileNameView];
    
    int64_t fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:fileNamePath error:nil] fileSize];
    
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
    NSString *path = [[dirGroup URLByAppendingPathComponent:NCBrandGlobal.shared.appApplicationSupport] path];
    
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
    NSString *path = [[[CCUtility getDirectoryGroup] URLByAppendingPathComponent:NCBrandGlobal.shared.appScan] path];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    
    return path;
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
    
    tableMetadata *metadata = [[NCManageDatabase shared] copyObjectWithMetadata:metadataForUpload];
    
    PHFetchResult *result = [PHAsset fetchAssetsWithLocalIdentifiers:@[metadata.assetLocalIdentifier] options:nil];
    if (!result.count) {
        if (notification) {
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:NCBrandGlobal.shared.notificationCenterUploadedFile object:nil userInfo:@{@"ocId": metadata.ocId, @"errorCode": @(NCBrandGlobal.shared.ErrorInternalError), @"errorDescription": @"_err_asset_not_found_"}];
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
                        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:NCBrandGlobal.shared.notificationCenterUploadedFile object:nil userInfo:@{@"ocId": metadata.ocId, @"errorCode": @(error.code), @"errorDescription": [NSString stringWithFormat:@"Image request iCloud failed [%@]", error.description]}];
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
                        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:NCBrandGlobal.shared.notificationCenterUploadedFile object:nil userInfo:@{@"ocId": metadata.ocId, @"errorCode": @(error.code), @"errorDescription": [NSString stringWithFormat:@"Video request iCloud failed [%@]", error.description]}];
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
                                [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:NCBrandGlobal.shared.notificationCenterUploadedFile object:nil userInfo:@{@"ocId": metadata.ocId, @"errorCode": @(error.code), @"errorDescription": [NSString stringWithFormat:@"Video request iCloud failed [%@]", error.description]}];
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
       
        tableDirectory *directory = [[NCManageDatabase shared] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", account, serverUrl]];
        
        while (directory != nil && ![directory.serverUrl isEqualToString:home]) {
            if (directory.e2eEncrypted == true) {
                return true;
            }
            serverUrl = [[NCUtility shared] deletingLastPathComponentWithServerUrl:serverUrl urlBase:urlBase account:account];
            directory = [[NCManageDatabase shared] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", account, serverUrl]];
        }
        
        return false;
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Share Permissions =====
#pragma --------------------------------------------------------------------------------------------

+ (NSInteger) getPermissionsValueByCanEdit:(BOOL)canEdit andCanCreate:(BOOL)canCreate andCanChange:(BOOL)canChange andCanDelete:(BOOL)canDelete andCanShare:(BOOL)canShare andIsFolder:(BOOL) isFolder
{    
    NSInteger permissionsValue = NCBrandGlobal.shared.permissionReadShare;
    
    if (canEdit && !isFolder) {
        permissionsValue = permissionsValue + NCBrandGlobal.shared.permissionUpdateShare;
    }
    if (canCreate & isFolder) {
        permissionsValue = permissionsValue + NCBrandGlobal.shared.permissionCreateShare;
    }
    if (canChange && isFolder) {
        permissionsValue = permissionsValue + NCBrandGlobal.shared.permissionUpdateShare;
    }
    if (canDelete & isFolder) {
        permissionsValue = permissionsValue + NCBrandGlobal.shared.permissionDeleteShare;
    }
    if (canShare) {
        permissionsValue = permissionsValue + NCBrandGlobal.shared.permissionShareShare;
    }
    
    return permissionsValue;
}

+ (BOOL) isPermissionToCanCreate:(NSInteger) permissionValue {
    BOOL canCreate = ((permissionValue & NCBrandGlobal.shared.permissionCreateShare) > 0);
    return canCreate;
}

+ (BOOL) isPermissionToCanChange:(NSInteger) permissionValue {
    BOOL canChange = ((permissionValue & NCBrandGlobal.shared.permissionUpdateShare) > 0);
    return canChange;
}

+ (BOOL) isPermissionToCanDelete:(NSInteger) permissionValue {
    BOOL canDelete = ((permissionValue & NCBrandGlobal.shared.permissionDeleteShare) > 0);
    return canDelete;
}

+ (BOOL) isPermissionToCanShare:(NSInteger) permissionValue {
    BOOL canShare = ((permissionValue & NCBrandGlobal.shared.permissionShareShare) > 0);
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
    BOOL canRead = ((permissionValue & NCBrandGlobal.shared.permissionReadShare) > 0);
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
#pragma mark ===== EXIF =====
#pragma --------------------------------------------------------------------------------------------

+ (void)setExif:(tableMetadata *)metadata withCompletionHandler:(void(^)(double latitude, double longitude, NSString *location, NSDate *date, NSString *lensModel))completition
{
    NSString *dateTime;
    NSString *latitudeRef;
    NSString *longitudeRef;
    NSString *stringLatitude = @"0";
    NSString *stringLongitude = @"0";
    __block NSString *location = @"";
    
    double latitude = 0;
    double longitude = 0;
    
    NSDate *date = [NSDate new];
    long fileSize = 0;
    int pixelY = 0;
    int pixelX = 0;
    NSString *lensModel;

    if (![metadata.typeFile isEqualToString:NCBrandGlobal.shared.metadataTypeFileImage] || ![CCUtility fileProviderStorageExists:metadata.ocId fileNameView:metadata.fileNameView]) {
        completition(latitude, longitude, location, date, lensModel);
        return;
    }
    
    NSURL *url = [NSURL fileURLWithPath:[CCUtility getDirectoryProviderStorageOcId:metadata.ocId fileNameView:metadata.fileNameView]];
    CGImageSourceRef originalSource =  CGImageSourceCreateWithURL((CFURLRef) url, NULL);
    if (!originalSource) {
        completition(latitude, longitude, location, date, lensModel);
        return;
    }
    
    CFDictionaryRef fileProperties = CGImageSourceCopyProperties(originalSource, nil);
    if (!fileProperties) {
        completition(latitude, longitude, location,date, lensModel);
        return;
    }
    
    // FILES PROPERTIES
    NSNumber *fileSizeNumber = CFDictionaryGetValue(fileProperties, kCGImagePropertyFileSize);
    fileSize = [fileSizeNumber longValue];
    
    
    CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(originalSource, 0, NULL);
    if (!imageProperties) {
        completition(latitude, longitude, location,date, lensModel);
        return;
    }

    CFDictionaryRef tiff = CFDictionaryGetValue(imageProperties, kCGImagePropertyTIFFDictionary);
    CFDictionaryRef gps = CFDictionaryGetValue(imageProperties, kCGImagePropertyGPSDictionary);
    CFDictionaryRef exif = CFDictionaryGetValue(imageProperties, kCGImagePropertyExifDictionary);
    
    if (exif) {
        
        NSString *sPixelX = (NSString *)CFDictionaryGetValue(exif, kCGImagePropertyExifPixelXDimension);
        pixelX = [sPixelX intValue];
        NSString *sPixelY = (NSString *)CFDictionaryGetValue(exif, kCGImagePropertyExifPixelYDimension);
        pixelY = [sPixelY intValue];
        lensModel = (NSString *)CFDictionaryGetValue(exif, kCGImagePropertyExifLensModel);
    }
 
    if (tiff) {
        
        dateTime = (NSString *)CFDictionaryGetValue(tiff, kCGImagePropertyTIFFDateTime);
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy:MM:dd HH:mm:ss"];
        date = [dateFormatter dateFromString:dateTime];
        if (!date) date = metadata.date;
    }
    
    if (gps) {
        
        latitude = [(NSString *)CFDictionaryGetValue(gps, kCGImagePropertyGPSLatitude) doubleValue];
        longitude = [(NSString *)CFDictionaryGetValue(gps, kCGImagePropertyGPSLongitude) doubleValue];
        
        latitudeRef = (NSString *)CFDictionaryGetValue(gps, kCGImagePropertyGPSLatitudeRef);
        longitudeRef = (NSString *)CFDictionaryGetValue(gps, kCGImagePropertyGPSLongitudeRef);
        
        // conversion 4 decimal +N -S
        // The latitude in degrees. Positive values indicate latitudes north of the equator. Negative values indicate latitudes south of the equator.
        if ([latitudeRef isEqualToString:@"N"]) {
            stringLatitude = [NSString stringWithFormat:@"+%.4f", latitude];
        } else {
            stringLatitude = [NSString stringWithFormat:@"-%.4f", latitude];
        }
        
        // conversion 4 decimal +E -W
        // The longitude in degrees. Measurements are relative to the zero meridian, with positive values extending east of the meridian
        // and negative values extending west of the meridian.
        if ([longitudeRef isEqualToString:@"E"]) {
            stringLongitude = [NSString stringWithFormat:@"+%.4f", longitude];
        } else {
            stringLongitude = [NSString stringWithFormat:@"-%.4f", longitude];
        }
        
        if (latitude == 0 || longitude == 0) {
            
            stringLatitude = @"0";
            stringLongitude = @"0";
        }
    }

    // Wite data EXIF in DB
    if (tiff || gps) {
        [[NCManageDatabase shared] setLocalFileWithOcId:metadata.ocId exifDate:date exifLatitude:stringLatitude exifLongitude:stringLongitude exifLensModel:lensModel];
        if ([stringLatitude doubleValue] != 0 || [stringLongitude doubleValue] != 0) {
            
            // If exists already geocoder data in TableGPS exit
            location = [[NCManageDatabase shared] getLocationFromGeoLatitude:stringLatitude longitude:stringLongitude];
            if (location != nil) {
                completition(latitude, longitude, location, date, lensModel);
                return;
            }
            
            CLGeocoder *geocoder = [[CLGeocoder alloc] init];
            CLLocation *llocation = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
            
            [geocoder reverseGeocodeLocation:llocation completionHandler:^(NSArray *placemarks, NSError *error) {
                        
                if (error == nil && [placemarks count] > 0) {
                    
                    CLPlacemark *placemark = [placemarks lastObject];
                    
                    NSString *thoroughfare = @"";
                    NSString *postalCode = @"";
                    NSString *locality = @"";
                    NSString *administrativeArea = @"";
                    NSString *country = @"";
                    
                    if (placemark.thoroughfare) thoroughfare = placemark.thoroughfare;
                    if (placemark.postalCode) postalCode = placemark.postalCode;
                    if (placemark.locality) locality = placemark.locality;
                    if (placemark.administrativeArea) administrativeArea = placemark.administrativeArea;
                    if (placemark.country) country = placemark.country;
                    
                    location = [NSString stringWithFormat:@"%@ %@ %@ %@ %@", thoroughfare, postalCode, locality, administrativeArea, country];
                    location = [location stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                    
                    // GPS
                    if ([location length] > 0) {
                        
                        [[NCManageDatabase shared] addGeocoderLocation:location placemarkAdministrativeArea:placemark.administrativeArea placemarkCountry:placemark.country placemarkLocality:placemark.locality placemarkPostalCode:placemark.postalCode placemarkThoroughfare:placemark.thoroughfare latitude:stringLatitude longitude:stringLongitude];
                    }
                    
                    completition(latitude, longitude, location, date, lensModel);
                }
            }];
        } else {
            completition(latitude, longitude, location, date, lensModel);
        }
    } else {
        completition(latitude, longitude, location, date, lensModel);
    }
       
    CFRelease(originalSource);
    CFRelease(imageProperties);
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

@end
