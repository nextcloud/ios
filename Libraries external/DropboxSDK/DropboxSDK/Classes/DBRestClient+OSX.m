//
//  DBRestClient+OSX.m
//  DropboxSDK
//
//  Created by Brian Smith on 1/22/12.
//  Copyright (c) 2012 Dropbox. All rights reserved.
//

#import "DBRestClient+OSX.h"

#import "DBLog.h"
#import "DBRequest.h"


@interface DBRestClient ()

- (NSMutableURLRequest *)requestWithHost:(NSString *)host path:(NSString *)path parameters:(NSDictionary *)params;

@property (nonatomic, readonly) MPOAuthCredentialConcreteStore *credentialStore;

@end


@implementation DBRestClient (OSX)

- (void)parse:(NSString *)result intoToken:(NSString **)pToken secret:(NSString **)pSecret userId:(NSString **)pUserId {
    for (NSString *param in [result componentsSeparatedByString:@"&"]) {
        NSArray *vals = [param componentsSeparatedByString:@"="];
        if ([vals count] != 2) {
            DBLogError(@"DBRestClient+OSX: error parsing oauth result");
            return;
        }
        NSString *name = [vals objectAtIndex:0];
        NSString *val = [vals objectAtIndex:1];

        if ([name isEqual:@"oauth_token"]) {
            *pToken = val;
        } else if ([name isEqual:@"oauth_token_secret"]) {
            *pSecret = val;
        } else if ([name isEqual:@"uid"]) {
            if (pUserId) {
                *pUserId = val;
            }
        } else {
            DBLogError(@"DBRestClient+Dropbox: unknown parameter received");
        }
    }
}

- (void)loadRequestToken {
    NSURLRequest *urlRequest =
        [self requestWithHost:kDBDropboxAPIHost path:@"/oauth/request_token" parameters:nil];

    DBRequest *request =
        [[[DBRequest alloc]
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidLoadRequestToken:)]
         autorelease];

    [requests addObject:request];
}

- (void)requestDidLoadRequestToken:(DBRequest *)request {
    id<DBRestClientOSXDelegate> delegateExt = (id<DBRestClientOSXDelegate>)delegate;
    if (request.error) {
        if ([delegateExt respondsToSelector:@selector(restClient:loadRequestTokenFailedWithError:)]) {
            [delegateExt restClient:self loadRequestTokenFailedWithError:request.error];
        }
    } else {
        NSString *token = nil;
        NSString *secret = nil;
        [self parse:[request resultString] intoToken:&token secret:&secret userId:nil];
        self.credentialStore.requestToken = token;
        self.credentialStore.requestTokenSecret = secret;
        if ([delegateExt respondsToSelector:@selector(restClientLoadedRequestToken:)]) {
            [delegateExt restClientLoadedRequestToken:self];
        }
    }

    [requests removeObject:request];
}


- (BOOL)requestTokenLoaded {
    return self.credentialStore.requestToken != nil;
}


- (NSURL *)authorizeURL {
    if (![self requestTokenLoaded]) {
        DBLogError(@"DBRestClient: You must get a request token before creating the authorize url");
        return nil;
    }

    NSString *token = self.credentialStore.requestToken;
    NSString *osxProtocol= [NSString stringWithFormat:@"db-%@", self.credentialStore.consumerKey];
    NSString *urlStr = [NSString stringWithFormat:@"%@://%@/%@/oauth/authorize?oauth_token=%@&osx_protocol=%@&embedded=1",
                        kDBProtocolHTTPS, kDBDropboxWebHost, kDBDropboxAPIVersion, token, osxProtocol];
    return [NSURL URLWithString:urlStr];
}


- (void)loadAccessToken {
    if (![self requestTokenLoaded]) {
        DBLogError(@"DBRestClient: You must get a request token and authorize it before getting an access token");
        return;
    }

    NSURLRequest *urlRequest =
        [self requestWithHost:kDBDropboxAPIHost path:@"/oauth/access_token" parameters:nil];

    DBRequest *request =
         [[[DBRequest alloc]
           initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidLoadAccessToken:)]
          autorelease];

    [requests addObject:request];
}

- (void)requestDidLoadAccessToken:(DBRequest *)request {
    id<DBRestClientOSXDelegate> delegateExt = (id<DBRestClientOSXDelegate>)delegate;
    if (request.error) {
        if (request.statusCode == 401 || request.statusCode == 403) {
            // request token probably no longer valid, clear it out to make sure we fetch another one
            self.credentialStore.requestToken = nil;
            self.credentialStore.requestTokenSecret = nil;
        }
        if ([delegateExt respondsToSelector:@selector(restClient:loadAccessTokenFailedWithError:)]) {
            [delegateExt restClient:self loadAccessTokenFailedWithError:request.error];
        }
    } else {
        self.credentialStore.requestToken = nil;
        self.credentialStore.requestTokenSecret = nil;
        NSString *token = nil;
        NSString *secret = nil;
        NSString *uid = nil;
        [self parse:[request resultString] intoToken:&token secret:&secret userId:&uid];
        [session updateAccessToken:token accessTokenSecret:secret forUserId:uid];
        if (userId == nil) {
            // if this client used to link the first user, associate it with that user
            userId = [uid retain];
        }
        if ([delegateExt respondsToSelector:@selector(restClientLoadedAccessToken:)]) {
            [delegateExt restClientLoadedAccessToken:self];
        }
    }

    [requests removeObject:request];
}

@end
