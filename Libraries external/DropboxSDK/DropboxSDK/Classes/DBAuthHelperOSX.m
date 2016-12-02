//
//  DBAuthHelperOSX.m
//  DropboxSDK
//
//  Created by Brian Smith on 3/26/12.
//  Copyright (c) 2012 Dropbox, Inc. All rights reserved.
//

#import "DBAuthHelperOSX.h"

#import "DBLog.h"

NSString *DBAuthHelperOSXStateChangedNotification = @"DBAuthHelperOSXStateChangedNotification";


@interface DBAuthHelperOSX () <DBRestClientOSXDelegate>

- (void)postStateChangedNotification:(NSError *)error;

@property (nonatomic, readonly) DBRestClient *restClient;

@end


@implementation DBAuthHelperOSX

@synthesize loading;

+ (DBAuthHelperOSX *)sharedHelper {
	static DBAuthHelperOSX *sharedHelper;
	if (!sharedHelper) {
		sharedHelper = [DBAuthHelperOSX new];
	}

	return sharedHelper;
}

- (id)init {
	if ((self = [super init])) {
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[restClient release];
	[super dealloc];
}


#pragma mark public methods

- (void)authenticate {
	if (loading) {
		DBLogError(@"DropboxSDK: called -[DBAuthHelperOSX authenticate] while the auth helper is already loading. Doing nothing.");
		return;
	} else if ([[DBSession sharedSession] isLinked]) {
		DBLogError(@"DropboxSDK: called -[DBAuthHelperOSX authenticate] when already linked. Doing nothing.");
		return;
	}

	loading = YES;
	[self postStateChangedNotification:nil];

	[self.restClient loadRequestToken];
}


#pragma mark DBRestClientOSXDelegate methods

- (void)restClientLoadedRequestToken:(DBRestClient *)restClient {
    loading = NO;
	[self postStateChangedNotification:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:NSApplicationDidBecomeActiveNotification object:nil];

    NSURL *url = [self.restClient authorizeURL];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (void)restClient:(DBRestClient *)restClient loadRequestTokenFailedWithError:(NSError *)error {
	loading = NO;
	if (![self.restClient requestTokenLoaded]) {
		[[NSNotificationCenter defaultCenter] removeObserver:self];
	}
	[self postStateChangedNotification:error];
}

- (void)restClientLoadedAccessToken:(DBRestClient *)client {
	loading = NO;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[restClient autorelease]; // HAX: having this obj maintain it's own rest client maintain it's own client is bad when session unlinks. Need to fix SDK to not cause this
	restClient = nil;
	[self postStateChangedNotification:nil];
}

- (void)restClient:(DBRestClient *)restClient loadAccessTokenFailedWithError:(NSError *)error {
    loading = NO;
	[self postStateChangedNotification:error];
}


#pragma mark private methods

- (void)postStateChangedNotification:(NSError *)error {
	NSDictionary *userInfo = nil;
	if (error) {
		userInfo = [NSDictionary dictionaryWithObject:error forKey:@"error"];
	}

	[[NSNotificationCenter defaultCenter]
	 postNotificationName:DBAuthHelperOSXStateChangedNotification object:self userInfo:userInfo];
}

- (DBRestClient *)restClient {
	if (!restClient) {
		restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
		restClient.delegate = self;
	}
	return restClient;
}

- (void)applicationDidBecomeActive:(NSNotification*)notification {
	if ([self.restClient requestTokenLoaded] && !loading) {
		[self postStateChangedNotification:nil];

		[self.restClient loadAccessToken];
	}
}

@end
