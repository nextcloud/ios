//
//  TableActivity+CoreDataProperties.h
//  Nextcloud
//
//  Created by Marino Faggiana on 01/03/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "TableActivity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface TableActivity (CoreDataProperties)

+ (NSFetchRequest<TableActivity *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *account;
@property (nullable, nonatomic, copy) NSNumber *idActivity;
@property (nullable, nonatomic, copy) NSDate *date;
@property (nullable, nonatomic, copy) NSString *file;
@property (nullable, nonatomic, copy) NSString *link;
@property (nullable, nonatomic, copy) NSString *message;
@property (nullable, nonatomic, copy) NSString *session;
@property (nullable, nonatomic, copy) NSString *subject;
@property (nullable, nonatomic, copy) NSString *type;
@property (nullable, nonatomic, copy) NSNumber *verbose;

@end

NS_ASSUME_NONNULL_END
