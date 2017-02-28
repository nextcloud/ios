//
//  TableCertificates+CoreDataProperties.m
//  Nextcloud
//
//  Created by Marino Faggiana on 17/02/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "TableCertificates+CoreDataProperties.h"

@implementation TableCertificates (CoreDataProperties)

+ (NSFetchRequest<TableCertificates *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"TableCertificates"];
}

@dynamic certificateLocation;

@end
