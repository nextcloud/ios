//
//  DBQuotaInfo.m
//  DropboxSDK
//
//  Created by Brian Smith on 5/3/10.
//  Copyright 2010 Dropbox, Inc. All rights reserved.
//

#import "DBQuota.h"


@implementation DBQuota

- (id)initWithDictionary:(NSDictionary*)dict {
    if ((self = [super init])) {
        normalConsumedBytes = [[dict objectForKey:@"normal"] longLongValue];
        sharedConsumedBytes = [[dict objectForKey:@"shared"] longLongValue];
        totalBytes = [[dict objectForKey:@"quota"] longLongValue];
    }
    return self;
}

- (void)dealloc {
    [super dealloc];
}

@synthesize normalConsumedBytes;
@synthesize sharedConsumedBytes;
@synthesize totalBytes;

- (long long)totalConsumedBytes {
    return normalConsumedBytes + sharedConsumedBytes;
}


#pragma mark NSCoding methods

- (void)encodeWithCoder:(NSCoder*)coder {
    [coder encodeInt64:normalConsumedBytes forKey:@"normalConsumedBytes"];
    [coder encodeInt64:sharedConsumedBytes forKey:@"sharedConsumedBytes"];
    [coder encodeInt64:totalBytes forKey:@"totalBytes"];
}

- (id)initWithCoder:(NSCoder*)coder {
    self = [super init];
    normalConsumedBytes = [coder decodeInt64ForKey:@"normalConsumedBytes"];
    sharedConsumedBytes = [coder decodeInt64ForKey:@"sharedConsumedBytes"];
    totalBytes = [coder decodeInt64ForKey:@"totalBytes"];
    return self;
}

@end
