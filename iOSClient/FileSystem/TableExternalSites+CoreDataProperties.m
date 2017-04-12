//
//  TableExternalSites+CoreDataProperties.m
//  Nextcloud
//
//  Created by Marino Faggiana on 22/03/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "TableExternalSites+CoreDataProperties.h"

@implementation TableExternalSites (CoreDataProperties)

+ (NSFetchRequest<TableExternalSites *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"TableExternalSites"];
}

@dynamic account;
@dynamic idExternalSite;
@dynamic name;
@dynamic url;
@dynamic lang;
@dynamic icon;
@dynamic type;

@end
