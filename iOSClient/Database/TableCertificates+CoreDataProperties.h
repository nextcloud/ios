//
//  TableCertificates+CoreDataProperties.h
//  Nextcloud
//
//  Created by Marino Faggiana on 17/02/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "TableCertificates+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface TableCertificates (CoreDataProperties)

+ (NSFetchRequest<TableCertificates *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *certificateLocation;

@end

NS_ASSUME_NONNULL_END
