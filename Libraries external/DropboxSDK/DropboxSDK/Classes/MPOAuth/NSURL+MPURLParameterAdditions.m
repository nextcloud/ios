//
//  NSURL+MPURLParameterAdditions.m
//  MPOAuthConnection
//
//  Created by Karl Adam on 08.12.08.
//  Copyright 2008 matrixPointer. All rights reserved.
//

#import "NSURL+MPURLParameterAdditions.h"

#import "MPURLRequestParameter.h"
#import "NSString+URLEscapingAdditions.h"

@implementation NSURL (MPURLParameterAdditions)

- (NSURL *)urlByAddingParameters:(NSArray *)inParameters {
	NSMutableArray *parameters = [[NSMutableArray alloc] init];
	NSString *queryString = [self query];
	NSString *absoluteString = [self absoluteString];
	NSRange parameterRange = [absoluteString rangeOfString:@"?"];
	
	if (parameterRange.location != NSNotFound) {
		parameterRange.length = [absoluteString length] - parameterRange.location;
		[parameters addObjectsFromArray:[MPURLRequestParameter parametersFromString:queryString]];
		absoluteString = [absoluteString substringToIndex:parameterRange.location];
	}
	
	[parameters addObjectsFromArray:inParameters];
	
	return [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@", absoluteString, [MPURLRequestParameter parameterStringForParameters:[parameters autorelease]]]];
}

- (NSURL *)urlByAddingParameterDictionary:(NSDictionary *)inParameterDictionary {
	NSMutableDictionary *parameterDictionary = [inParameterDictionary mutableCopy];
	NSString *queryString = [self query];
	NSString *absoluteString = [self absoluteString];
	NSRange parameterRange = [absoluteString rangeOfString:@"?"];
	NSURL *composedURL = self;
	
	if (parameterRange.location != NSNotFound) {
		parameterRange.length = [absoluteString length] - parameterRange.location;
		
		//[parameterDictionary addEntriesFromDictionary:inParameterDictionary];
		[parameterDictionary addEntriesFromDictionary:[MPURLRequestParameter parameterDictionaryFromString:queryString]];
		
		composedURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@", [absoluteString substringToIndex:parameterRange.location], [MPURLRequestParameter parameterStringForDictionary:parameterDictionary]]];
	} else if ([parameterDictionary count]) {
		composedURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@", absoluteString, [MPURLRequestParameter parameterStringForDictionary:parameterDictionary]]];
	}
	
	[parameterDictionary release];

	return composedURL;
}

- (NSURL *)urlByRemovingQuery {
	NSURL *composedURL = self;
	NSString *absoluteString = [self absoluteString];
	NSRange queryRange = [absoluteString rangeOfString:@"?"];
	
	if (queryRange.location != NSNotFound) {
		NSString *urlSansQuery = [absoluteString substringToIndex:queryRange.location];
		composedURL = [NSURL URLWithString:urlSansQuery];
	}
	
	return composedURL;
}

- (NSString *)absoluteNormalizedString {
	NSString *normalizedString = [self absoluteString];

	if ([[self path] length] == 0 && [[self query] length] == 0) {
		normalizedString = [NSString stringWithFormat:@"%@/", [self absoluteString]];
	}
	
	return normalizedString;
}

- (BOOL)domainMatches:(NSString *)inString {
	BOOL matches = NO;
	
	NSString *domain = [self host];
	matches = [domain isIPAddress] && [domain isEqualToString:inString];
	
	NSUInteger domainLength = [domain length];
	NSUInteger requestedDomainLength = [inString length];
	
	if (!matches) {
		if (domainLength > requestedDomainLength) {
			matches = [domain rangeOfString:inString].location == (domainLength - requestedDomainLength);
		} else if (domainLength == (requestedDomainLength - 1)) {
			matches = ([inString compare:domain options:NSCaseInsensitiveSearch range:NSMakeRange(1, domainLength)] == NSOrderedSame);
		}
	}
	
	return matches;
}

@end
