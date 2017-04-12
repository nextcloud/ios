//
//  TableExternalSites+CoreDataProperties.h
//  Nextcloud
//
//  Created by Marino Faggiana on 22/03/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "TableExternalSites+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface TableExternalSites (CoreDataProperties)

+ (NSFetchRequest<TableExternalSites *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *account;
@property (nullable, nonatomic, copy) NSNumber *idExternalSite;
@property (nullable, nonatomic, copy) NSString *name;
@property (nullable, nonatomic, copy) NSString *url;
@property (nullable, nonatomic, copy) NSString *lang;
@property (nullable, nonatomic, copy) NSString *icon;
@property (nullable, nonatomic, copy) NSString *type;

@end

NS_ASSUME_NONNULL_END
