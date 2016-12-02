//
//  MPOAuthAuthenticationMethod.m
//  MPOAuthConnection
//
//  Created by Karl Adam on 09.12.19.
//  Copyright 2009 matrixPointer. All rights reserved.
//

#import "MPOAuthAuthenticationMethod.h"
#import "MPOAuthAuthenticationMethodOAuth.h"
#import "MPOAuthCredentialConcreteStore.h"
#import "MPURLRequestParameter.h"

#import "NSURL+MPURLParameterAdditions.h"

NSString * const MPOAuthAccessTokenURLKey					= @"MPOAuthAccessTokenURL";

@interface MPOAuthAuthenticationMethod ()
@property (nonatomic, readwrite, retain) NSTimer *refreshTimer;

+ (Class)_authorizationMethodClassForURL:(NSURL *)inBaseURL withConfiguration:(NSDictionary **)outConfig;
- (id)initWithAPI:(MPOAuthAPI *)inAPI forURL:(NSURL *)inURL withConfiguration:(NSDictionary *)inConfig;
- (void)_automaticallyRefreshAccessToken:(NSTimer *)inTimer;
@end

@implementation MPOAuthAuthenticationMethod
- (id)initWithAPI:(MPOAuthAPI *)inAPI forURL:(NSURL *)inURL {
	return [self initWithAPI:inAPI forURL:inURL withConfiguration:nil];
}

- (id)initWithAPI:(MPOAuthAPI *)inAPI forURL:(NSURL *)inURL withConfiguration:(NSDictionary *)inConfig {
	if ([[self class] isEqual:[MPOAuthAuthenticationMethod class]]) {
		NSDictionary *configuration = nil;
		Class methodClass = [[self class] _authorizationMethodClassForURL:inURL withConfiguration:&configuration];
		[self release];
		
		self = [[methodClass alloc] initWithAPI:inAPI forURL:inURL withConfiguration:configuration];
	} else if ((self = [super init])) {
		self.oauthAPI = inAPI;		
	}
	
	return self;
}

- (oneway void)dealloc {
	self.oauthAPI = nil;
	self.oauthGetAccessTokenURL = nil;

	[self.refreshTimer invalidate];
	self.refreshTimer = nil;

	[super dealloc];
}

@synthesize oauthAPI = oauthAPI_;
@synthesize oauthGetAccessTokenURL = oauthGetAccessTokenURL_;
@synthesize refreshTimer = refreshTimer_;

#pragma mark -

+ (Class)_authorizationMethodClassForURL:(NSURL *)inBaseURL withConfiguration:(NSDictionary **)outConfig {
	Class methodClass = [MPOAuthAuthenticationMethodOAuth class];
	NSString *oauthConfigPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"oauthAutoConfig" ofType:@"plist"];
	NSDictionary *oauthConfigDictionary = [NSDictionary dictionaryWithContentsOfFile:oauthConfigPath];
	
	for ( NSString *domainString in [oauthConfigDictionary keyEnumerator]) {
		if ([inBaseURL domainMatches:domainString]) {
			NSDictionary *oauthConfig = [oauthConfigDictionary objectForKey:domainString];
			
			NSArray *requestedMethods = [oauthConfig objectForKey:@"MPOAuthAuthenticationPreferredMethods"];
			NSString *requestedMethod = nil;
			for (requestedMethod in requestedMethods) {
				Class requestedMethodClass = NSClassFromString(requestedMethod);
				
				if (requestedMethodClass) {
					methodClass = requestedMethodClass;
				}
				break;
			}
			
			if (requestedMethod) {
				*outConfig = [oauthConfig objectForKey:requestedMethod];
			} else {
				*outConfig = oauthConfig;
			}

			break;
		}
	}
	
	return methodClass; 
}

#pragma mark -

- (void)authenticate {
	[NSException raise:@"Not Implemented" format:@"All subclasses of MPOAuthAuthenticationMethod are required to implement -authenticate"];
}

- (void)setTokenRefreshInterval:(NSTimeInterval)inTimeInterval {
	if (!self.refreshTimer && inTimeInterval > 0.0) {
		self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:inTimeInterval target:self selector:@selector(_automaticallyRefreshAccessToken:) userInfo:nil repeats:YES];	
	}
}

- (void)refreshAccessToken {
	MPURLRequestParameter *sessionHandleParameter = nil;
	MPOAuthCredentialConcreteStore *credentials = (MPOAuthCredentialConcreteStore *)[self.oauthAPI credentials];
	
	if (credentials.sessionHandle) {
		sessionHandleParameter = [[MPURLRequestParameter alloc] init];
		sessionHandleParameter.name = @"oauth_session_handle";
		sessionHandleParameter.value = credentials.sessionHandle;
	}
	
	[self.oauthAPI performMethod:nil
						   atURL:self.oauthGetAccessTokenURL
				  withParameters:sessionHandleParameter ? [NSArray arrayWithObject:sessionHandleParameter] : nil
					  withTarget:nil
					   andAction:nil];
	
	[sessionHandleParameter release];	
}

#pragma mark -

- (void)_automaticallyRefreshAccessToken:(NSTimer *)inTimer {
	[self refreshAccessToken];
}

@end
