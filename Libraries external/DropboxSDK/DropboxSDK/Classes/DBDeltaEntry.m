//
//  DBDeltaEntry.m
//  DropboxSDK
//
//  Created by Brian Smith on 3/25/12.
//  Copyright (c) 2012 Dropbox, Inc. All rights reserved.
//

#import "DBDeltaEntry.h"

@implementation DBDeltaEntry

@synthesize lowercasePath;
@synthesize metadata;

- (id)initWithArray:(NSArray *)array {
    if ((self = [super init])) {
        lowercasePath = [[array objectAtIndex:0] retain];
        NSObject *maybeMetadata = [array objectAtIndex:1];
        if (maybeMetadata != [NSNull null]) {
            metadata = [[DBMetadata alloc] initWithDictionary:[array objectAtIndex:1]];
        }
    }
    return self;
}

- (void)dealloc {
    [lowercasePath release];
    [metadata release];
    [super dealloc];
}

- (BOOL)isEqualToDeltaEntry:(DBDeltaEntry *)entry {
    if (self == entry) return YES;
    return
        (lowercasePath == entry.lowercasePath || [lowercasePath isEqual:entry.lowercasePath]) &&
        (metadata == entry.metadata || [metadata isEqual:entry.metadata]);
}

- (BOOL)isEqual:(id)other {
    if (other == self) return YES;
    if (!other || ![other isKindOfClass:[self class]]) return NO;
    return [self isEqualToDeltaEntry:other];
}


#pragma mark NSCoding methods

- (id)initWithCoder:(NSCoder*)coder {
    if ((self = [super init])) {
        lowercasePath = [[coder decodeObjectForKey:@"lowercasePath"] retain];
        metadata = [[coder decodeObjectForKey:@"metadata"] retain];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder*)coder {
    [coder encodeObject:lowercasePath forKey:@"lowercasePath"];
    [coder encodeObject:metadata forKey:@"metadata"];
}


@end
