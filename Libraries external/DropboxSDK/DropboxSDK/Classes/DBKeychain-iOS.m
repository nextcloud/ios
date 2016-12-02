//
//  DBKeychain.m
//  DropboxSDK
//
//  Created by Brian Smith on 4/5/12.
//  Copyright (c) 2012 Dropbox, Inc. All rights reserved.
//

#import "DBKeychain.h"
#import <UIKit/UIKit.h>

#import "DBLog.h"

static NSDictionary *kDBKeychainDict;

@implementation DBKeychain

//TWS modify
+ (void)initialize {
    
	if ([self class] != [DBKeychain class]) return;
    
	//NSString *keychainId = [NSString stringWithFormat:@"%@.dropbox.auth", [[NSBundle mainBundle] bundleIdentifier]];
    //kDBKeychainDict = [[NSDictionary alloc] initWithObjectsAndKeys:(id)kSecClassGenericPassword, (id)kSecClass, keychainId, (id)kSecAttrService, nil];
    
    NSString *keychainId = [NSString stringWithFormat:@"%@.dropbox.auth", [self mainBundleName]];
    kDBKeychainDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                       (id)kSecClassGenericPassword, (id)kSecClass,
                       keychainId, (id)kSecAttrService,
                       @"group.it.twsweb.Crypto-Cloud",(id)kSecAttrAccessGroup,
                       nil];
}

//TWS add
+ (NSString *)mainBundleName
{
    /*
    NSUserDefaults *sharedUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.it.twsweb.Crypto-Cloud"];
    
    // Esiste la chiave versioneprofessional ??
    if ([sharedUserDefaults objectForKey:@"versioneprofessional"]) {
    
        if ([[sharedUserDefaults objectForKey:@"versioneprofessional"] boolValue] == YES)
            return @"it.twsweb.Crypto-Cloud";
        else
            return @"it.twsweb.Crypto-Lite";
    } else {
    */
        NSMutableArray *components = [NSMutableArray arrayWithArray:[[[NSBundle mainBundle] bundleIdentifier] componentsSeparatedByString:@"."]];
        while ([components count] > 3) {
            [components removeLastObject];
        }
        return [components componentsJoinedByString:@"."];
    //}
}

+ (NSDictionary *)credentials {
	NSMutableDictionary *searchDict = [NSMutableDictionary dictionaryWithDictionary:kDBKeychainDict];
	[searchDict setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];
	[searchDict setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnAttributes];
	[searchDict setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];

	NSDictionary *attrDict = nil;
	OSStatus status = SecItemCopyMatching((CFDictionaryRef)searchDict, (CFTypeRef *)&attrDict);
	[attrDict autorelease];
	NSData *foundValue = [attrDict objectForKey:(id)kSecValueData];

	if (status == noErr && foundValue) {
		return [NSKeyedUnarchiver unarchiveObjectWithData:foundValue];
	} else {
		if (status != errSecItemNotFound) {
			DBLogWarning(@"DropboxSDK: error reading stored credentials (%i)", (int32_t)status);
		}
		return nil;
	}
}

+ (void)setCredentials:(NSDictionary *)credentials {
	NSData *credentialData = [NSKeyedArchiver archivedDataWithRootObject:credentials];

	NSMutableDictionary *attrDict = [NSMutableDictionary dictionaryWithDictionary:kDBKeychainDict];
	[attrDict setObject:credentialData forKey:(id)kSecValueData];

	NSArray *version = [[[UIDevice currentDevice] systemVersion] componentsSeparatedByString:@"."];
    if ([[version objectAtIndex:0] intValue] >= 4) {
        [attrDict setObject:(id)kSecAttrAccessibleAfterFirstUnlock forKey:(id)kSecAttrAccessible];
    }

	OSStatus status = noErr;

	if ([self credentials]) {
		[attrDict removeObjectForKey:(id)kSecClass];
		status = SecItemUpdate((CFDictionaryRef)kDBKeychainDict, (CFDictionaryRef)attrDict);
	} else {
		status = SecItemAdd((CFDictionaryRef)attrDict, NULL);
	}

	if (status != noErr) {
		DBLogWarning(@"DropboxSDK: error saving credentials (%i)", (int32_t)status);
	}
}

+ (void)deleteCredentials {
	OSStatus status = SecItemDelete((CFDictionaryRef)kDBKeychainDict);

	if (status != noErr) {
		DBLogWarning(@"DropboxSDK: error deleting credentials (%i)", (int32_t)status);
	}
}

@end
