//
//  TableGPS+CoreDataProperties.m
//  Nextcloud
//
//  Created by Marino Faggiana on 17/02/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "TableGPS+CoreDataProperties.h"

@implementation TableGPS (CoreDataProperties)

+ (NSFetchRequest<TableGPS *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"TableGPS"];
}

@dynamic latitude;
@dynamic location;
@dynamic longitude;
@dynamic placemarkAdministrativeArea;
@dynamic placemarkCountry;
@dynamic placemarkLocality;
@dynamic placemarkPostalCode;
@dynamic placemarkThoroughfare;

@end
