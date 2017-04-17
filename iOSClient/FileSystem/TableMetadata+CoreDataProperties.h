//
//  TableMetadata+CoreDataProperties.h
//  Nextcloud
//
//  Created by Marino Faggiana on 17/02/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "TableMetadata+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface TableMetadata (CoreDataProperties)

+ (NSFetchRequest<TableMetadata *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *account;
@property (nullable, nonatomic, copy) NSNumber *cryptated;
@property (nullable, nonatomic, copy) NSDate *date;
@property (nullable, nonatomic, copy) NSNumber *directory;
@property (nullable, nonatomic, copy) NSString *directoryID;
@property (nullable, nonatomic, copy) NSNumber *errorPasscode;
@property (nullable, nonatomic, copy) NSNumber *favorite;
@property (nullable, nonatomic, copy) NSString *fileID;
@property (nullable, nonatomic, copy) NSString *fileName;
@property (nullable, nonatomic, copy) NSString *fileNameData;
@property (nullable, nonatomic, copy) NSString *fileNamePrint;
@property (nullable, nonatomic, copy) NSString *iconName;
@property (nullable, nonatomic, copy) NSString *assetLocalIdentifier;
@property (nullable, nonatomic, copy) NSString *model;
@property (nullable, nonatomic, copy) NSString *nameCurrentDevice;
@property (nullable, nonatomic, copy) NSString *permissions;
@property (nullable, nonatomic, copy) NSString *protocol;
@property (nullable, nonatomic, copy) NSString *rev;
@property (nullable, nonatomic, copy) NSString *session;
@property (nullable, nonatomic, copy) NSString *sessionError;
@property (nullable, nonatomic, copy) NSString *sessionID;
@property (nullable, nonatomic, copy) NSString *sessionSelector;
@property (nullable, nonatomic, copy) NSString *sessionSelectorPost;
@property (nullable, nonatomic, copy) NSNumber *sessionTaskIdentifier;
@property (nullable, nonatomic, copy) NSNumber *sessionTaskIdentifierPlist;
@property (nullable, nonatomic, copy) NSNumber *size;
@property (nullable, nonatomic, copy) NSNumber *thumbnailExists;
@property (nullable, nonatomic, copy) NSString *title;
@property (nullable, nonatomic, copy) NSString *type;
@property (nullable, nonatomic, copy) NSString *typeFile;
@property (nullable, nonatomic, copy) NSString *uuid;

@end

NS_ASSUME_NONNULL_END
