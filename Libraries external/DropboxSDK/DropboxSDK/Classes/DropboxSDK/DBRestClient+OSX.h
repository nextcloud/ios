//
//  DBRestClient+OSX.h
//  DropboxSDK
//
//  Created by Brian Smith on 1/22/12.
//  Copyright (c) 2012 Dropbox. All rights reserved.
//

#import "DBRestClient.h"

@interface DBRestClient (OSX)

- (void)loadRequestToken;

- (BOOL)requestTokenLoaded;

- (NSURL *)authorizeURL;

- (void)loadAccessToken;

@end


@protocol DBRestClientOSXDelegate <DBRestClientDelegate>

@optional

- (void)restClientLoadedRequestToken:(DBRestClient *)restClient;
- (void)restClient:(DBRestClient *)restClient loadRequestTokenFailedWithError:(NSError *)error;

- (void)restClientLoadedAccessToken:(DBRestClient *)restClient;
- (void)restClient:(DBRestClient *)restClient loadAccessTokenFailedWithError:(NSError *)error;

@end
