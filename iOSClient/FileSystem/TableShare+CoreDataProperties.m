//
//  TableShare+CoreDataProperties.m
//  Nextcloud
//
//  Created by Marino Faggiana on 17/02/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "TableShare+CoreDataProperties.h"

@implementation TableShare (CoreDataProperties)

+ (NSFetchRequest<TableShare *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"TableShare"];
}

@dynamic account;
@dynamic dateRecord;
@dynamic fileName;
@dynamic serverUrl;
@dynamic shareLink;
@dynamic shareUserAndGroup;

@end
