//
//  TableDirectory+CoreDataProperties.m
//  Nextcloud
//
//  Created by Marino Faggiana on 17/02/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "TableDirectory+CoreDataProperties.h"

@implementation TableDirectory (CoreDataProperties)

+ (NSFetchRequest<TableDirectory *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"TableDirectory"];
}

@dynamic account;
@dynamic dateReadDirectory;
@dynamic directoryID;
@dynamic favorite;
@dynamic fileID;
@dynamic lock;
@dynamic offline;
@dynamic permissions;
@dynamic rev;
@dynamic serverUrl;
@dynamic synchronized;

@end
