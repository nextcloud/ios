//
//  TableUpload+CoreDataProperties.m
//  Nextcloud
//
//  Created by Marino Faggiana on 18/12/16.
//  Copyright © 2016 TWS. All rights reserved.
//

#import "TableUpload+CoreDataProperties.h"

@implementation TableUpload (CoreDataProperties)

+ (NSFetchRequest<TableUpload *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"TableUpload"];
}

@dynamic account;
@dynamic assetLocalItentifier;
@dynamic date;
@dynamic fileName;
@dynamic queueName;
@dynamic selector;
@dynamic selectorPost;
@dynamic serverUrl;
@dynamic session;
@dynamic startUpload;

@end
