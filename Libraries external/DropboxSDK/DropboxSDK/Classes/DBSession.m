//
//  DBSession.m
//  DropboxSDK
//
//  Created by Brian Smith on 4/8/10.
//  Copyright 2010 Dropbox, Inc. All rights reserved.
//

#import "DBSession.h"

#import "DBKeychain.h"
#import "DBLog.h"
#import "MPOAuthCredentialConcreteStore.h"
#import "MPOAuthSignatureParameter.h"

NSString *kDBSDKVersion = @"1.3.14"; // TODO: parameterize from build system

NSString *kDBDropboxAPIHost = @"api.dropbox.com";
NSString *kDBDropboxAPIContentHost = @"api-content.dropbox.com";
NSString *kDBDropboxWebHost = @"www.dropbox.com";
NSString *kDBDropboxAPIVersion = @"1";

NSString *kDBRootDropbox = @"dropbox";
NSString *kDBRootAppFolder = @"sandbox";

NSString *kDBProtocolHTTPS = @"https";

NSString *kDBDropboxUnknownUserId = @"unknown";

static DBSession *_sharedSession = nil;
static NSString *kDBDropboxSavedCredentialsOldOld = @"kDBDropboxSavedCredentialsKey";
static NSString *kDBDropboxSavedCredentialsOld = @"kDBDropboxSavedCredentials";
static NSString *kDBDropboxUserCredentials = @"kDBDropboxUserCredentials";
static NSString *kDBDropboxUserId = @"kDBDropboxUserId";
static NSString *kDBCredentialsVersionKey = @"DBCredentialVersion";
static int kDBCredentialsVersion = 3;



@interface DBSession ()

- (void)saveCredentials;
- (void)setAccessToken:(NSString *)token accessTokenSecret:(NSString *)secret forUserId:(NSString *)userId;

@end


@implementation DBSession

+ (DBSession *)sharedSession {
    return _sharedSession;
}

+ (void)setSharedSession:(DBSession *)session {
    if (session == _sharedSession) return;
    [_sharedSession release];
    _sharedSession = [session retain];
}

- (id)initWithAppKey:(NSString *)key appSecret:(NSString *)secret root:(NSString *)theRoot {
    if ((self = [super init])) {
        
        baseCredentials = 
            [[NSDictionary alloc] initWithObjectsAndKeys:
                key, kMPOAuthCredentialConsumerKey,
                secret, kMPOAuthCredentialConsumerSecret, 
                kMPOAuthSignatureMethodPlaintext, kMPOAuthSignatureMethod, nil];
                
        credentialStores = [NSMutableDictionary new];
        
        NSDictionary *oldOldCredentials =
            [[NSUserDefaults standardUserDefaults] objectForKey:kDBDropboxSavedCredentialsOldOld];
        if (oldOldCredentials) {
            if ([key isEqual:[oldOldCredentials objectForKey:kMPOAuthCredentialConsumerKey]]) {
                // These credentials are the same structure as version 1, but in userDefaults
                NSString *token = [oldOldCredentials objectForKey:kMPOAuthCredentialAccessToken];
                NSString *secret = [oldOldCredentials objectForKey:kMPOAuthCredentialAccessTokenSecret];
                [self updateAccessToken:token accessTokenSecret:secret forUserId:kDBDropboxUnknownUserId];
            }
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDBDropboxSavedCredentialsOldOld];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }

        NSDictionary *oldCredentials =
            [[NSUserDefaults standardUserDefaults] objectForKey:kDBDropboxSavedCredentialsOld];
        if (oldCredentials) {
            if ([key isEqual:[oldCredentials objectForKey:kMPOAuthCredentialConsumerKey]]) {
                // These credentials are the same structure as version 2, but in userDefaults and missing version
				NSArray *allUserCredentials = [oldCredentials objectForKey:kDBDropboxUserCredentials];
				for (NSDictionary *userCredentials in allUserCredentials) {
					NSString *userId = [userCredentials objectForKey:kDBDropboxUserId];
					NSString *token = [userCredentials objectForKey:kMPOAuthCredentialAccessToken];
					NSString *secret = [userCredentials objectForKey:kMPOAuthCredentialAccessTokenSecret];
					[self setAccessToken:token accessTokenSecret:secret forUserId:userId];
				}
				[self saveCredentials];
            }
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDBDropboxSavedCredentialsOld];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }

        NSDictionary *savedCredentials = [DBKeychain credentials];
        if (savedCredentials != nil) {
            if ([key isEqualToString:[savedCredentials objectForKey:kMPOAuthCredentialConsumerKey]]) {
                NSInteger version = [[savedCredentials objectForKey:kDBCredentialsVersionKey] intValue];
                if (version == 1) {
                    // These credentials are version 1 in the keychain
                    NSString *token = [savedCredentials objectForKey:kMPOAuthCredentialAccessToken];
                    NSString *secret = [savedCredentials objectForKey:kMPOAuthCredentialAccessTokenSecret];
                    [self updateAccessToken:token accessTokenSecret:secret forUserId:kDBDropboxUnknownUserId];
                } else {
                    // These credentials are version 2 or 3 in the keychain
                    NSArray *allUserCredentials = [savedCredentials objectForKey:kDBDropboxUserCredentials];
                    for (NSDictionary *userCredentials in allUserCredentials) {
                        NSString *userId = [userCredentials objectForKey:kDBDropboxUserId];
                        NSString *token = [userCredentials objectForKey:kMPOAuthCredentialAccessToken];
                        NSString *secret = [userCredentials objectForKey:kMPOAuthCredentialAccessTokenSecret];
                        if (version < 3) {
                            // version 2 of the API used a different keychain access mode and needs
                            // to be set again with the newer one
                            [self updateAccessToken:token accessTokenSecret:secret forUserId:userId];
                        } else {
                            [self setAccessToken:token accessTokenSecret:secret forUserId:userId];
                        }
                    }
                }
            } else {
                [DBKeychain deleteCredentials];
            }
        }
        
        root = [theRoot retain];
    }
    return self;
}

- (void)dealloc {
    [baseCredentials release];
    [credentialStores release];
    [anonymousStore release];
    [root release];
    [super dealloc];
}

@synthesize root;
@synthesize delegate;

- (void)updateAccessToken:(NSString *)token accessTokenSecret:(NSString *)secret forUserId:(NSString *)userId {
    [self setAccessToken:token accessTokenSecret:secret forUserId:userId];
    [self saveCredentials];
}

- (void)setAccessToken:(NSString *)token accessTokenSecret:(NSString *)secret forUserId:(NSString *)userId {
    MPOAuthCredentialConcreteStore *credentialStore = [credentialStores objectForKey:userId];
    if (!credentialStore) {
        credentialStore = 
            [[MPOAuthCredentialConcreteStore alloc] initWithCredentials:baseCredentials];
        [credentialStores setObject:credentialStore forKey:userId];
        [credentialStore release];
        
        if (![userId isEqual:kDBDropboxUnknownUserId] && [credentialStores objectForKey:kDBDropboxUnknownUserId]) {
            // If the unknown user is in credential store, replace it with this new entry
            [credentialStores removeObjectForKey:kDBDropboxUnknownUserId];
        }
    }
    credentialStore.accessToken = token;
    credentialStore.accessTokenSecret = secret;
}

- (BOOL)isLinked {
    return [credentialStores count] != 0;
}

- (void)unlinkAll {
    [credentialStores removeAllObjects];
    [DBKeychain deleteCredentials];
}

- (void)unlinkUserId:(NSString *)userId {
    [credentialStores removeObjectForKey:userId];
    [self saveCredentials];
}

- (MPOAuthCredentialConcreteStore *)credentialStoreForUserId:(NSString *)userId {
    if (!userId) {
        if (!anonymousStore) {
            anonymousStore = [[MPOAuthCredentialConcreteStore alloc] initWithCredentials:baseCredentials];
        }
        return anonymousStore;
    }
    return [credentialStores objectForKey:userId];
}

- (NSArray *)userIds {
    return [credentialStores allKeys];
}


#pragma mark private methods

- (void)saveCredentials {
    NSMutableDictionary *credentials = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                        [baseCredentials objectForKey:kMPOAuthCredentialConsumerKey], kMPOAuthCredentialConsumerKey,
                                        [NSNumber numberWithInt:kDBCredentialsVersion], kDBCredentialsVersionKey,
                                        nil];

    NSMutableArray *allUserCredentials = [NSMutableArray array];
    for (NSString *userId in [credentialStores allKeys]) {
        MPOAuthCredentialConcreteStore *store = [credentialStores objectForKey:userId];
        NSMutableDictionary *userCredentials = [NSMutableDictionary new];
        [userCredentials setObject:userId forKey:kDBDropboxUserId];
        [userCredentials setObject:store.accessToken forKey:kMPOAuthCredentialAccessToken];
        [userCredentials setObject:store.accessTokenSecret forKey:kMPOAuthCredentialAccessTokenSecret];
        [allUserCredentials addObject:userCredentials];
        [userCredentials release];
    }
    [credentials setObject:allUserCredentials forKey:kDBDropboxUserCredentials];
    [DBKeychain setCredentials:credentials];
}

@end
