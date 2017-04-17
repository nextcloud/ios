//
//  TableMetadata+CoreDataProperties.m
//  Nextcloud
//
//  Created by Marino Faggiana on 17/02/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "TableMetadata+CoreDataProperties.h"

@implementation TableMetadata (CoreDataProperties)

+ (NSFetchRequest<TableMetadata *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"TableMetadata"];
}

@dynamic account;
@dynamic cryptated;
@dynamic date;
@dynamic directory;
@dynamic directoryID;
@dynamic errorPasscode;
@dynamic favorite;
@dynamic fileID;
@dynamic fileName;
@dynamic fileNameData;
@dynamic fileNamePrint;
@dynamic iconName;
@dynamic assetLocalIdentifier;
@dynamic model;
@dynamic nameCurrentDevice;
@dynamic permissions;
@dynamic protocol;
@dynamic rev;
@dynamic session;
@dynamic sessionError;
@dynamic sessionID;
@dynamic sessionSelector;
@dynamic sessionSelectorPost;
@dynamic sessionTaskIdentifier;
@dynamic sessionTaskIdentifierPlist;
@dynamic size;
@dynamic thumbnailExists;
@dynamic title;
@dynamic type;
@dynamic typeFile;
@dynamic uuid;

@end
