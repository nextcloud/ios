//
//  DBAccountInfo.m
//  DropboxSDK
//
//  Created by Brian Smith on 5/3/10.
//  Copyright 2010 Dropbox, Inc. All rights reserved.
//

#import "DBAccountInfo.h"


@implementation DBAccountInfo

- (id)initWithDictionary:(NSDictionary*)dict {
    if ((self = [super init])) {
        email = [[dict objectForKey:@"email"] retain];
        country = [[dict objectForKey:@"country"] retain];
        displayName = [[dict objectForKey:@"display_name"] retain];
        if ([dict objectForKey:@"quota_info"]) {
            quota = [[DBQuota alloc] initWithDictionary:[dict objectForKey:@"quota_info"]];
        }
        userId = [[[dict objectForKey:@"uid"] stringValue] retain];
        referralLink = [[dict objectForKey:@"referral_link"] retain];
        original = [dict retain];
    }
    return self;
}

- (void)dealloc {
    [email release];
    [country release];
    [displayName release];
    [quota release];
    [userId release];
    [referralLink release];
    [original release];
    [super dealloc];
}

@synthesize email;
@synthesize country;
@synthesize displayName;
@synthesize quota;
@synthesize userId;
@synthesize referralLink;


#pragma mark NSCoding methods

- (void)encodeWithCoder:(NSCoder*)coder {
    [coder encodeObject:original forKey:@"original"];
}

- (id)initWithCoder:(NSCoder*)coder {
    if ([coder containsValueForKey:@"original"]) {
        return [self initWithDictionary:[coder decodeObjectForKey:@"original"]];
    } else {
        NSMutableDictionary *mDict = [NSMutableDictionary dictionary];

        [mDict setObject:[coder decodeObjectForKey:@"country"] forKey:@"country"];
        [mDict setObject:[coder decodeObjectForKey:@"displayName"] forKey:@"display_name"];

        DBQuota *tempQuota = [coder decodeObjectForKey:@"quota"];
        NSDictionary *quotaDict =
            [NSDictionary dictionaryWithObjectsAndKeys:
             [NSNumber numberWithLongLong:tempQuota.normalConsumedBytes], @"normal",
             [NSNumber numberWithLongLong:tempQuota.sharedConsumedBytes], @"shared",
             [NSNumber numberWithLongLong:tempQuota.totalBytes], @"quota", nil];
        [mDict setObject:quotaDict forKey:@"quota_info"];

        NSNumber *uid = [NSNumber numberWithLongLong:[[coder decodeObjectForKey:@"userId"] longLongValue]];
        [mDict setObject:uid forKey:@"uid"];
        [mDict setObject:[coder decodeObjectForKey:@"referralLink"] forKey:@"referral_link"];
        if ([coder containsValueForKey:@"email"]) {
            [mDict setObject:[coder decodeObjectForKey:@"email"] forKey:@"email"];
        }

        return [self initWithDictionary:mDict];
    }
}

@end
