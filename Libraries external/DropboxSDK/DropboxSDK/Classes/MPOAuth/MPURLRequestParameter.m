//
//  MPURLParameter.m
//  MPOAuthConnection
//
//  Created by Karl Adam on 08.12.05.
//  Copyright 2008 matrixPointer. All rights reserved.
//

#import "MPURLRequestParameter.h"
#import "NSString+URLEscapingAdditions.h"

@implementation MPURLRequestParameter

+ (NSArray *)parametersFromString:(NSString *)inString {
	NSMutableArray *foundParameters = [NSMutableArray arrayWithCapacity:10];
	NSScanner *parameterScanner = [[NSScanner alloc] initWithString:inString];
	NSString *name = nil;
	NSString *value = nil;
	MPURLRequestParameter *currentParameter = nil;
	
	while (![parameterScanner isAtEnd]) {
		name = nil;
		value = nil;
		
		[parameterScanner scanUpToString:@"=" intoString:&name];
		[parameterScanner scanString:@"=" intoString:NULL];
		[parameterScanner scanUpToString:@"&" intoString:&value];
		[parameterScanner scanString:@"&" intoString:NULL];		
		
		currentParameter = [[MPURLRequestParameter alloc] init];
		currentParameter.name = name;
		currentParameter.value = [value stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		
		[foundParameters addObject:currentParameter];
		
		[currentParameter release];
	}
	
	[parameterScanner release];
	
	return foundParameters;
}

+ (NSArray *)parametersFromDictionary:(NSDictionary *)inDictionary {
	NSMutableArray *parameterArray = [[NSMutableArray alloc] init];
	MPURLRequestParameter *aURLParameter = nil;
	
	for (NSString *aKey in [inDictionary allKeys]) {
		aURLParameter = [[MPURLRequestParameter alloc] init];
		aURLParameter.name = aKey;
		aURLParameter.value = [inDictionary objectForKey:aKey];
		
		[parameterArray addObject:aURLParameter];
		[aURLParameter release];
	}
	
	return [parameterArray autorelease];
}

+ (NSDictionary *)parameterDictionaryFromString:(NSString *)inString {
	NSMutableDictionary *foundParameters = [NSMutableDictionary dictionaryWithCapacity:10];
	if (inString) {
		NSScanner *parameterScanner = [[NSScanner alloc] initWithString:inString];
		NSString *name = nil;
		NSString *value = nil;
		
		while (![parameterScanner isAtEnd]) {
			name = nil;
			value = nil;
			
			[parameterScanner scanUpToString:@"=" intoString:&name];
			[parameterScanner scanString:@"=" intoString:NULL];
			[parameterScanner scanUpToString:@"&" intoString:&value];
			[parameterScanner scanString:@"&" intoString:NULL];		
			
			[foundParameters setObject:[value stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] forKey:name];
		}
		
		[parameterScanner release];
	}
	return foundParameters;
}

+ (NSString *)parameterStringForParameters:(NSArray *)inParameters {
	NSMutableString *queryString = [[NSMutableString alloc] init];
	NSUInteger i = 0;
	NSUInteger parameterCount = [inParameters count];
	MPURLRequestParameter *aParameter = nil;
	
	for (; i < parameterCount; i++) {
		aParameter = [inParameters objectAtIndex:i];
		[queryString appendString:[aParameter URLEncodedParameterString]];
		
		if (i < parameterCount - 1) {
			[queryString appendString:@"&"];
		}
	}
	
	return [queryString autorelease];
}

+ (NSString *)parameterStringForDictionary:(NSDictionary *)inParameterDictionary {
	NSArray *parameters = [self parametersFromDictionary:inParameterDictionary];
	NSString *queryString = [self parameterStringForParameters:parameters];
	
	return queryString;
}

#pragma mark -

- (id)init {
	if ((self = [super init])) {
		
	}
	return self;
}

- (id)initWithName:(NSString *)inName andValue:(NSString *)inValue {
	if ((self = [super init])) {
		self.name = inName;
		self.value = inValue;
	}
	return self;
}

- (oneway void)dealloc {
	self.name = nil;
	self.value = nil;
	
	[super dealloc];
}

@synthesize name = _name;
@synthesize value = _value;

#pragma mark -

- (NSString *)URLEncodedParameterString {
	return [NSString stringWithFormat:@"%@=%@", [self.name stringByAddingURIPercentEscapesUsingEncoding:NSUTF8StringEncoding], self.value ? [self.value stringByAddingURIPercentEscapesUsingEncoding:NSUTF8StringEncoding] : @""];
}

#pragma mark -

- (NSComparisonResult)compare:(id)inObject {
	NSComparisonResult result = [self.name compare:[(MPURLRequestParameter *)inObject name]];
	
	if (result == NSOrderedSame) {
		result = [self.value compare:[(MPURLRequestParameter *)inObject value]];
	}
								 
	return result;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p %@>", NSStringFromClass([self class]), self, [self URLEncodedParameterString]];
}

@end
