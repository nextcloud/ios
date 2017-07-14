//
//  TableDirectory+CoreDataProperties.h
//  Nextcloud
//
//  Created by Marino Faggiana on 17/02/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "TableDirectory+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface TableDirectory (CoreDataProperties)

+ (NSFetchRequest<TableDirectory *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *account;
@property (nullable, nonatomic, copy) NSDate *dateReadDirectory;
@property (nullable, nonatomic, copy) NSString *directoryID;
@property (nullable, nonatomic, copy) NSNumber *favorite;
@property (nullable, nonatomic, copy) NSString *fileID;
@property (nullable, nonatomic, copy) NSNumber *lock;
@property (nullable, nonatomic, copy) NSNumber *offline;
@property (nullable, nonatomic, copy) NSString *permissions;
@property (nullable, nonatomic, copy) NSString *rev;
@property (nullable, nonatomic, copy) NSString *serverUrl;
@property (nullable, nonatomic, copy) NSNumber *synchronized;

@end

NS_ASSUME_NONNULL_END
