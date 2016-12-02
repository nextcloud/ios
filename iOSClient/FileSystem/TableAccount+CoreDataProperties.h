//
//  TableAccount+CoreDataProperties.h
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 18/01/16.
//  Copyright (c) 2014 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "TableAccount.h"

NS_ASSUME_NONNULL_BEGIN

@interface TableAccount (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *account;
@property (nullable, nonatomic, retain) NSNumber *active;
@property (nullable, nonatomic, retain) NSNumber *cameraUpload;
@property (nullable, nonatomic, retain) NSNumber *cameraUploadBackground;
@property (nullable, nonatomic, retain) NSNumber *cameraUploadCreateSubfolder;
@property (nullable, nonatomic, retain) NSNumber *cameraUploadCryptatedPhoto;
@property (nullable, nonatomic, retain) NSNumber *cameraUploadCryptatedVideo;
@property (nullable, nonatomic, retain) NSDate *cameraUploadDatePhoto;
@property (nullable, nonatomic, retain) NSDate *cameraUploadDateVideo;
@property (nullable, nonatomic, retain) NSString *cameraUploadFolderName;
@property (nullable, nonatomic, retain) NSString *cameraUploadFolderPath;
@property (nullable, nonatomic, retain) NSNumber *cameraUploadFull;
@property (nullable, nonatomic, retain) NSNumber *cameraUploadPhoto;
@property (nullable, nonatomic, retain) NSNumber *cameraUploadSaveAlbum;
@property (nullable, nonatomic, retain) NSNumber *cameraUploadVideo;
@property (nullable, nonatomic, retain) NSNumber *cameraUploadWWAnPhoto;
@property (nullable, nonatomic, retain) NSNumber *cameraUploadWWAnVideo;
@property (nullable, nonatomic, retain) NSDate *dateRecord;
@property (nullable, nonatomic, retain) NSDate *optimization;
@property (nullable, nonatomic, retain) NSString *password;
@property (nullable, nonatomic, retain) NSString *token;
@property (nullable, nonatomic, retain) NSString *typeCloud;
@property (nullable, nonatomic, retain) NSString *uid;
@property (nullable, nonatomic, retain) NSString *url;
@property (nullable, nonatomic, retain) NSString *user;

@end

NS_ASSUME_NONNULL_END
