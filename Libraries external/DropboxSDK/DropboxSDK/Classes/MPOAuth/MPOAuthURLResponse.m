//
//  MPOAuthURLResponse.m
//  MPOAuthConnection
//
//  Created by Karl Adam on 08.12.05.
//  Copyright 2008 matrixPointer. All rights reserved.
//

#import "MPOAuthURLResponse.h"

@interface MPOAuthURLResponse ()
@property (nonatomic, readwrite, retain) NSURLResponse *urlResponse;
@property (nonatomic, readwrite, retain) NSDictionary *oauthParameters;
@end

@implementation MPOAuthURLResponse

- (id)init {
	if ((self = [super init])) {
		
	}
	return self;
}

- (oneway void)dealloc {
	self.urlResponse = nil;
	self.oauthParameters = nil;
	
	[super dealloc];
}

@synthesize urlResponse = _urlResponse;
@synthesize oauthParameters = _oauthParameters;

@end
