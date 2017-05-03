//
//  TableCapabilities+CoreDataProperties.h
//  Nextcloud
//
//  Created by Marino Faggiana on 24/04/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "TableCapabilities+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface TableCapabilities (CoreDataProperties)

+ (NSFetchRequest<TableCapabilities *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *account;
@property (nullable, nonatomic, copy) NSString *themingBackground;
@property (nullable, nonatomic, copy) NSString *themingColor;
@property (nullable, nonatomic, copy) NSString *themingLogo;
@property (nullable, nonatomic, copy) NSString *themingName;
@property (nullable, nonatomic, copy) NSString *themingSlogan;
@property (nullable, nonatomic, copy) NSString *themingUrl;
@property (nullable, nonatomic, copy) NSNumber *versionMajor;
@property (nullable, nonatomic, copy) NSNumber *versionMicro;
@property (nullable, nonatomic, copy) NSNumber *versionMinor;
@property (nullable, nonatomic, copy) NSString *versionString;

@end

NS_ASSUME_NONNULL_END
