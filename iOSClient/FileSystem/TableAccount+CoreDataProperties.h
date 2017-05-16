//
//  TableAccount+CoreDataProperties.h
//  Nextcloud
//
//  Created by Marino Faggiana on 17/02/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "TableAccount+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface TableAccount (CoreDataProperties)

+ (NSFetchRequest<TableAccount *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *account;
@property (nullable, nonatomic, copy) NSNumber *active;
@property (nullable, nonatomic, copy) NSNumber *cameraUpload;
@property (nullable, nonatomic, copy) NSNumber *cameraUploadBackground;
@property (nullable, nonatomic, copy) NSNumber *cameraUploadCreateSubfolder;
@property (nullable, nonatomic, copy) NSDate *cameraUploadDatePhoto;
@property (nullable, nonatomic, copy) NSDate *cameraUploadDateVideo;
@property (nullable, nonatomic, copy) NSString *cameraUploadFolderName;
@property (nullable, nonatomic, copy) NSString *cameraUploadFolderPath;
@property (nullable, nonatomic, copy) NSNumber *cameraUploadFull;
@property (nullable, nonatomic, copy) NSNumber *cameraUploadPhoto;
@property (nullable, nonatomic, copy) NSNumber *cameraUploadSaveAlbum;
@property (nullable, nonatomic, copy) NSNumber *cameraUploadVideo;
@property (nullable, nonatomic, copy) NSNumber *cameraUploadWWAnPhoto;
@property (nullable, nonatomic, copy) NSNumber *cameraUploadWWAnVideo;
@property (nullable, nonatomic, copy) NSDate *optimization;
@property (nullable, nonatomic, copy) NSString *password;
@property (nullable, nonatomic, copy) NSString *url;
@property (nullable, nonatomic, copy) NSString *user;
@property (nullable, nonatomic, copy) NSNumber *enabled;
@property (nullable, nonatomic, copy) NSString *address;
@property (nullable, nonatomic, copy) NSString *displayName;
@property (nullable, nonatomic, copy) NSString *email;
@property (nullable, nonatomic, copy) NSString *phone;
@property (nullable, nonatomic, copy) NSString *twitter;
@property (nullable, nonatomic, copy) NSString *webpage;
@property (nullable, nonatomic, copy) NSNumber *quota;
@property (nullable, nonatomic, copy) NSNumber *quotaFree;
@property (nullable, nonatomic, copy) NSNumber *quotaRelative;
@property (nullable, nonatomic, copy) NSNumber *quotaTotal;
@property (nullable, nonatomic, copy) NSNumber *quotaUsed;

@end

NS_ASSUME_NONNULL_END
