//
//  NCDatabase.m
//  Nextcloud
//
//  Created by Marino Faggiana on 05/05/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "NCDatabase.h"

@implementation DBActivity

// Specify default values for properties

//+ (NSDictionary *)defaultPropertyValues
//{
//    return @{};
//}

// Specify properties to ignore (Realm won't persist these)

//+ (NSArray *)ignoredProperties
//{
//    return @[];
//}

+ (NSArray *)requiredProperties {
    return @[@"account"];
}
    
+ (NSArray *)indexedProperties {
    return @[@"date"];
}

+ (NSDictionary *)defaultPropertyValues {
    return @{@"date" : [NSDate date], @"idActivity" : @0, @"verbose" : @NO};
}

@end
