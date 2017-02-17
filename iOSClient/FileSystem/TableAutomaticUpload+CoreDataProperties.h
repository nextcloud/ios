//
//  TableAutomaticUpload+CoreDataProperties.h
//  Nextcloud
//
//  Created by Marino Faggiana on 17/02/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "TableAutomaticUpload+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface TableAutomaticUpload (CoreDataProperties)

+ (NSFetchRequest<TableAutomaticUpload *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *account;
@property (nullable, nonatomic, copy) NSDate *date;
@property (nullable, nonatomic, copy) NSString *fileName;
@property (nullable, nonatomic, copy) NSString *identifier;
@property (nullable, nonatomic, copy) NSNumber *priority;
@property (nullable, nonatomic, copy) NSString *selector;
@property (nullable, nonatomic, copy) NSString *selectorPost;
@property (nullable, nonatomic, copy) NSString *serverUrl;
@property (nullable, nonatomic, copy) NSString *session;

@end

NS_ASSUME_NONNULL_END
