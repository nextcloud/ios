//
//  TableAutomaticUpload+CoreDataProperties.m
//  Nextcloud
//
//  Created by Marino Faggiana on 17/02/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "TableAutomaticUpload+CoreDataProperties.h"

@implementation TableAutomaticUpload (CoreDataProperties)

+ (NSFetchRequest<TableAutomaticUpload *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"TableAutomaticUpload"];
}

@dynamic account;
@dynamic date;
@dynamic fileName;
@dynamic identifier;
@dynamic lock;
@dynamic priority;
@dynamic selector;
@dynamic selectorPost;
@dynamic serverUrl;
@dynamic session;

@end
