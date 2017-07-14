//
//  TableLocalFile+CoreDataProperties.h
//  Nextcloud
//
//  Created by Marino Faggiana on 17/02/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "TableLocalFile+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface TableLocalFile (CoreDataProperties)

+ (NSFetchRequest<TableLocalFile *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *account;
@property (nullable, nonatomic, copy) NSDate *date;
@property (nullable, nonatomic, copy) NSDate *exifDate;
@property (nullable, nonatomic, copy) NSString *exifLatitude;
@property (nullable, nonatomic, copy) NSString *exifLongitude;
@property (nullable, nonatomic, copy) NSNumber *favorite;
@property (nullable, nonatomic, copy) NSString *fileID;
@property (nullable, nonatomic, copy) NSString *fileName;
@property (nullable, nonatomic, copy) NSString *fileNamePrint;
@property (nullable, nonatomic, copy) NSNumber *offline;
@property (nullable, nonatomic, copy) NSString *rev;
@property (nullable, nonatomic, copy) NSNumber *size;

@end

NS_ASSUME_NONNULL_END
