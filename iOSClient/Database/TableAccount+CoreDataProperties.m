//
//  TableAccount+CoreDataProperties.m
//  Nextcloud
//
//  Created by Marino Faggiana on 17/02/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "TableAccount+CoreDataProperties.h"

@implementation TableAccount (CoreDataProperties)

+ (NSFetchRequest<TableAccount *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"TableAccount"];
}

@dynamic account;
@dynamic active;
@dynamic cameraUpload;
@dynamic cameraUploadBackground;
@dynamic cameraUploadCreateSubfolder;
@dynamic cameraUploadDatePhoto;
@dynamic cameraUploadDateVideo;
@dynamic cameraUploadFolderName;
@dynamic cameraUploadFolderPath;
@dynamic cameraUploadFull;
@dynamic cameraUploadPhoto;
@dynamic cameraUploadSaveAlbum;
@dynamic cameraUploadVideo;
@dynamic cameraUploadWWAnPhoto;
@dynamic cameraUploadWWAnVideo;
@dynamic optimization;
@dynamic password;
@dynamic url;
@dynamic user;
@dynamic enabled;
@dynamic address;
@dynamic displayName;
@dynamic email;
@dynamic phone;
@dynamic twitter;
@dynamic webpage;
@dynamic quota;
@dynamic quotaFree;
@dynamic quotaRelative;
@dynamic quotaTotal;
@dynamic quotaUsed;

@end
