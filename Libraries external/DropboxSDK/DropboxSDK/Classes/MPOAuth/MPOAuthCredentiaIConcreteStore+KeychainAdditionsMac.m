//
//  MPOAuthCredentialConcreteStore+TokenAdditionsMac.m
//  MPOAuthConnection
//
//  Created by Karl Adam on 08.12.13.
//  Copyright 2008 matrixPointer. All rights reserved.
//

#import "MPOAuthCredentialConcreteStore+KeychainAdditions.h"

#if !TARGET_OS_IPHONE || (TARGET_IPHONE_SIMULATOR && !__IPHONE_3_0)

@interface MPOAuthCredentialConcreteStore (KeychainAdditionsMac)
- (NSString *)findValueFromKeychainUsingName:(NSString *)inName returningItem:(SecKeychainItemRef *)outKeychainItemRef;
@end

@implementation MPOAuthCredentialConcreteStore (KeychainAdditions)

- (void)addToKeychainUsingName:(NSString *)inName andValue:(NSString *)inValue {
	NSString *serverName = [self.baseURL host];
	NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
	NSString *securityDomain = [self.authenticationURL host];
	NSString *uniqueName = [NSString stringWithFormat:@"%@.%@", bundleID, inName];
	SecKeychainItemRef existingKeychainItem = NULL;
	
	if ([self findValueFromKeychainUsingName:inName returningItem:&existingKeychainItem]) {
		// This is MUCH easier than updating the item attributes/data
		SecKeychainItemDelete(existingKeychainItem);
	}
	
	SecKeychainAddInternetPassword(NULL /* default keychain */,
								   (int32_t)[serverName length], [serverName UTF8String],
								   (int32_t)[securityDomain length], [securityDomain UTF8String],
								   (int32_t)[uniqueName length], [uniqueName UTF8String],	/* account name */
								   0, NULL,	/* path */
								   0,
								   'oaut'	/* OAuth, not an official OSType code */,
								   kSecAuthenticationTypeDefault,
								   (int32_t)[inValue length], [inValue UTF8String],
								   NULL);
}

- (NSString *)findValueFromKeychainUsingName:(NSString *)inName {
	return [self findValueFromKeychainUsingName:inName returningItem:NULL];
}

- (NSString *)findValueFromKeychainUsingName:(NSString *)inName returningItem:(SecKeychainItemRef *)outKeychainItemRef {
	NSString *foundPassword = nil;
	NSString *serverName = [self.baseURL host];
	NSString *securityDomain = [self.authenticationURL host];
	NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
	NSString *uniqueName = [NSString stringWithFormat:@"%@.%@", bundleID, inName];
	
	UInt32 passwordLength = 0;
	const char *passwordString = NULL;
	
	OSStatus status = SecKeychainFindInternetPassword(NULL	/* default keychain */,
													  (int32_t)[serverName length], [serverName UTF8String],
													  (int32_t)[securityDomain length], [securityDomain UTF8String],
													  (int32_t)[uniqueName length], [uniqueName UTF8String],
													  0, NULL,	/* path */
													  0,
													  kSecProtocolTypeAny,
													  kSecAuthenticationTypeAny,
													  (UInt32 *)&passwordLength,
													  (void **)&passwordString,
													  outKeychainItemRef);
	
	if (status == noErr && passwordLength) {
		NSData *passwordStringData = [NSData dataWithBytes:passwordString length:passwordLength];
		foundPassword = [[NSString alloc] initWithData:passwordStringData encoding:NSUTF8StringEncoding];
	}
	
	return [foundPassword autorelease];
}

- (void)removeValueFromKeychainUsingName:(NSString *)inName {
	SecKeychainItemRef aKeychainItem = NULL;
	
	[self findValueFromKeychainUsingName:inName returningItem:&aKeychainItem];
	
	if (aKeychainItem) {
		SecKeychainItemDelete(aKeychainItem);
	}
}

@end

#endif
