//
//  TableShare+CoreDataProperties.h
//  Nextcloud
//
//  Created by Marino Faggiana on 17/02/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "TableShare+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface TableShare (CoreDataProperties)

+ (NSFetchRequest<TableShare *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *account;
@property (nullable, nonatomic, copy) NSString *fileName;
@property (nullable, nonatomic, copy) NSString *serverUrl;
@property (nullable, nonatomic, copy) NSString *shareLink;
@property (nullable, nonatomic, copy) NSString *shareUserAndGroup;

@end

NS_ASSUME_NONNULL_END
