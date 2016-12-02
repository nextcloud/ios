//
//  DBSession+iOS.m
//  DropboxSDK
//
//  Created by Brian Smith on 3/7/12.
//  Copyright (c) 2012 Dropbox. All rights reserved.
//

#import "DBSession+iOS.h"

#import <CommonCrypto/CommonDigest.h>

#import "DBConnectController.h"
#import "DBLog.h"


static NSString *kDBProtocolDropbox = @"dbapi-2";
static NSString *kDBProtocolDropboxEMM = @"dbapi-8-emm";

/* A key to keep track of the nonce for the current link flow */
static NSString *kDBLinkNonce = @"dropbox.sync.nonce";


@implementation DBSession (iOS)

+ (NSDictionary*)parseURLParams:(NSString *)query {
    NSArray *pairs = [query componentsSeparatedByString:@"&"];
    NSMutableDictionary *params = [[[NSMutableDictionary alloc] init] autorelease];
    for (NSString *pair in pairs) {
        NSArray *kv = [pair componentsSeparatedByString:@"="];
        NSString *val =
        [[kv objectAtIndex:1]
         stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

        [params setObject:val forKey:[kv objectAtIndex:0]];
    }
    return params;
}

- (NSString *)appScheme {
    NSString *consumerKey = [baseCredentials objectForKey:kMPOAuthCredentialConsumerKey];
    return [NSString stringWithFormat:@"db-%@", consumerKey];
}

- (BOOL)appConformsToScheme {
    NSString *appScheme = [self appScheme];

    NSDictionary *loadedPlist = [[NSBundle mainBundle] infoDictionary];

    NSArray *urlTypes = [loadedPlist objectForKey:@"CFBundleURLTypes"];
    for (NSDictionary *urlType in urlTypes) {
        NSArray *schemes = [urlType objectForKey:@"CFBundleURLSchemes"];
        for (NSString *scheme in schemes) {
            if ([scheme isEqual:appScheme]) {
                return YES;
            }
        }
    }
    return NO;
}

- (void)linkUserId:(NSString *)userId fromController:(UIViewController *)rootController {
    if (![self appConformsToScheme]) {
        DBLogError(@"DropboxSDK: unable to link; app isn't registered for correct URL scheme (%@)", [self appScheme]);
        return;
    }

    extern NSString *kDBDropboxUnknownUserId;
    NSString *userIdStr = @"";
    if (userId && ![userId isEqual:kDBDropboxUnknownUserId]) {
        userIdStr = [NSString stringWithFormat:@"&u=%@", userId];
    }

    NSString *consumerKey = [baseCredentials objectForKey:kMPOAuthCredentialConsumerKey];

    NSData *consumerSecret =
    [[baseCredentials objectForKey:kMPOAuthCredentialConsumerSecret] dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char md[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(consumerSecret.bytes, (uint32_t)[consumerSecret length], md);
    uint32_t sha_32 = htonl(((uint32_t *)md)[CC_SHA1_DIGEST_LENGTH/sizeof(uint32_t) - 1]);
    NSString *secret = [NSString stringWithFormat:@"%x", sha_32];

    CFUUIDRef uuid = CFUUIDCreate(NULL);
    CFStringRef uuid_str = CFUUIDCreateString(NULL, uuid);
    CFRelease(uuid);
    NSString *nonce = [(NSString *)uuid_str autorelease];
    [[NSUserDefaults standardUserDefaults] setObject:nonce forKey:kDBLinkNonce];
    [[NSUserDefaults standardUserDefaults] synchronize];

    NSString *urlStr = nil;

    NSURL *dbURL = [DBSession db_checkedURLForProtocol:kDBProtocolDropbox];
    if (!dbURL) {
        dbURL = [DBSession db_checkedURLForProtocol: kDBProtocolDropboxEMM];
    }

    if (dbURL) {
        urlStr = [NSString stringWithFormat:@"%@?k=%@&s=%@&state=%@%@",
				  dbURL, consumerKey, secret, nonce, userIdStr];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlStr]];
    } else {
        urlStr = [NSString stringWithFormat:@"%@://%@/%@/connect_login?k=%@&s=%@&state=%@&easl=1%@",
                  kDBProtocolHTTPS, kDBDropboxWebHost, kDBDropboxAPIVersion,
                  consumerKey, secret, nonce, userIdStr];
        UIViewController *connectController = [[[DBConnectController alloc] initWithUrl:[NSURL URLWithString:urlStr] fromController:rootController session:self] autorelease];
        UINavigationController *navController = [[[UINavigationController alloc] initWithRootViewController:connectController] autorelease];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            connectController.modalPresentationStyle = UIModalPresentationFormSheet;
            navController.modalPresentationStyle = UIModalPresentationFormSheet;
        }

        [rootController presentModalViewController:navController animated:YES];
    }
}

- (void)linkFromController:(UIViewController *)rootController {
    [self linkUserId:nil fromController:rootController];
}

+ (NSURL *)db_checkedURLForProtocol:(NSString *)protocol
{
    if (!protocol) {
        return nil;
    }

    NSURL *url =
    [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@/connect", protocol, kDBDropboxAPIVersion]];

    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        return url;
    }

    return nil;
}

- (BOOL)handleOpenURL:(NSURL *)url {
    NSString *expected = [NSString stringWithFormat:@"%@://%@/", [self appScheme], kDBDropboxAPIVersion];
    if (![[url absoluteString] hasPrefix:expected]) {
        return NO;
    }

    NSArray *components = [[url path] pathComponents];
    NSString *methodName = [components count] > 1 ? [components objectAtIndex:1] : nil;

    if ([methodName isEqual:@"connect"]) {
        NSDictionary *params = [DBSession parseURLParams:[url query]];
        NSString *token = [params objectForKey:@"oauth_token"];
        NSString *secret = [params objectForKey:@"oauth_token_secret"];
        NSString *userId = [params objectForKey:@"uid"];

		NSString *state = [params objectForKey:@"state"];
		NSString *nonce = [[NSUserDefaults standardUserDefaults] objectForKey:kDBLinkNonce];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:kDBLinkNonce];
		[[NSUserDefaults standardUserDefaults] synchronize];
		if (![nonce isEqual:state]) {
			DBLogError(@"unable to verify link request");
			return NO;
		}

        [self updateAccessToken:token accessTokenSecret:secret forUserId:userId];
    } else if ([methodName isEqual:@"cancel"]) {
        DBLogInfo(@"DropboxSDK: user cancelled Dropbox link");
    }

    return YES;
}

@end
