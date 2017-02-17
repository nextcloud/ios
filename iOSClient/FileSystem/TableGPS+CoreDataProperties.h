//
//  TableGPS+CoreDataProperties.h
//  Nextcloud
//
//  Created by Marino Faggiana on 17/02/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "TableGPS+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface TableGPS (CoreDataProperties)

+ (NSFetchRequest<TableGPS *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSDate *dateRecord;
@property (nullable, nonatomic, copy) NSString *latitude;
@property (nullable, nonatomic, copy) NSString *location;
@property (nullable, nonatomic, copy) NSString *longitude;
@property (nullable, nonatomic, copy) NSString *placemarkAdministrativeArea;
@property (nullable, nonatomic, copy) NSString *placemarkCountry;
@property (nullable, nonatomic, copy) NSString *placemarkLocality;
@property (nullable, nonatomic, copy) NSString *placemarkPostalCode;
@property (nullable, nonatomic, copy) NSString *placemarkThoroughfare;

@end

NS_ASSUME_NONNULL_END
