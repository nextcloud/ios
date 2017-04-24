//
//  TableCapabilities+CoreDataProperties.m
//  Nextcloud
//
//  Created by Marino Faggiana on 24/04/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "TableCapabilities+CoreDataProperties.h"

@implementation TableCapabilities (CoreDataProperties)

+ (NSFetchRequest<TableCapabilities *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"TableCapabilities"];
}

@dynamic account;
@dynamic themingBackground;
@dynamic themingColor;
@dynamic themingLogo;
@dynamic themingName;
@dynamic themingSlogan;
@dynamic themingUrl;

@end
