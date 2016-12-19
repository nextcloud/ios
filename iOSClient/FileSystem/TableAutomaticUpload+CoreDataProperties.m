//
//  TableAutomaticUpload+CoreDataProperties.m
//  Nextcloud
//
//  Created by Marino Faggiana on 19/12/16.
//  Copyright © 2016 TWS. All rights reserved.
//

#import "TableAutomaticUpload+CoreDataProperties.h"

@implementation TableAutomaticUpload (CoreDataProperties)

+ (NSFetchRequest<TableAutomaticUpload *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"TableAutomaticUpload"];
}

@dynamic account;
@dynamic assetLocalItentifier;
@dynamic date;
@dynamic fileName;
@dynamic selector;
@dynamic selectorPost;
@dynamic serverUrl;
@dynamic session;
@dynamic startUpload;
@dynamic priority;

@end
