//
//  TableUpload+CoreDataProperties.h
//  Nextcloud
//
//  Created by Marino Faggiana on 18/12/16.
//  Copyright © 2016 TWS. All rights reserved.
//

#import "TableUpload+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface TableUpload (CoreDataProperties)

+ (NSFetchRequest<TableUpload *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *account;
@property (nullable, nonatomic, copy) NSString *assetLocalItentifier;
@property (nullable, nonatomic, copy) NSDate *date;
@property (nullable, nonatomic, copy) NSString *fileName;
@property (nullable, nonatomic, copy) NSString *queueName;
@property (nullable, nonatomic, copy) NSString *selector;
@property (nullable, nonatomic, copy) NSString *selectorPost;
@property (nullable, nonatomic, copy) NSString *serverUrl;
@property (nullable, nonatomic, copy) NSString *session;
@property (nullable, nonatomic, retain) NSNumber *startUpload;

@end

NS_ASSUME_NONNULL_END
