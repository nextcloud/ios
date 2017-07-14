//
//  TableLocalFile+CoreDataProperties.m
//  Nextcloud
//
//  Created by Marino Faggiana on 17/02/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "TableLocalFile+CoreDataProperties.h"

@implementation TableLocalFile (CoreDataProperties)

+ (NSFetchRequest<TableLocalFile *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"TableLocalFile"];
}

@dynamic account;
@dynamic date;
@dynamic exifDate;
@dynamic exifLatitude;
@dynamic exifLongitude;
@dynamic favorite;
@dynamic fileID;
@dynamic fileName;
@dynamic fileNamePrint;
@dynamic offline;
@dynamic rev;
@dynamic size;

@end
