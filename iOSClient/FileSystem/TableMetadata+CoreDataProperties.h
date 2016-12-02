//
//  TableMetadata+CoreDataProperties.h
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

#import "TableMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@interface TableMetadata (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *account;
@property (nullable, nonatomic, retain) NSNumber *cryptated;
@property (nullable, nonatomic, retain) NSDate *date;
@property (nullable, nonatomic, retain) NSDate *dateRecord;
@property (nullable, nonatomic, retain) NSNumber *directory;
@property (nullable, nonatomic, retain) NSString *directoryID;
@property (nullable, nonatomic, retain) NSNumber *errorPasscode;
@property (nullable, nonatomic, retain) NSString *fileID;
@property (nullable, nonatomic, retain) NSString *fileName;
@property (nullable, nonatomic, retain) NSString *fileNameData;
@property (nullable, nonatomic, retain) NSString *fileNamePrint;
@property (nullable, nonatomic, retain) NSString *iconName;
@property (nullable, nonatomic, retain) NSString *localIdentifier;
@property (nullable, nonatomic, retain) NSString *model;
@property (nullable, nonatomic, retain) NSString *nameCurrentDevice;
@property (nullable, nonatomic, retain) NSString *permissions;
@property (nullable, nonatomic, retain) NSString *protocol;
@property (nullable, nonatomic, retain) NSString *rev;
@property (nullable, nonatomic, retain) NSString *session;
@property (nullable, nonatomic, retain) NSString *sessionError;
@property (nullable, nonatomic, retain) NSString *sessionID;
@property (nullable, nonatomic, retain) NSString *sessionSelector;
@property (nullable, nonatomic, retain) NSString *sessionSelectorPost;
@property (nullable, nonatomic, retain) NSNumber *sessionTaskIdentifier;
@property (nullable, nonatomic, retain) NSNumber *sessionTaskIdentifierPlist;
@property (nullable, nonatomic, retain) NSNumber *size;
@property (nullable, nonatomic, retain) NSNumber *thumbnailExists;
@property (nullable, nonatomic, retain) NSString *title;
@property (nullable, nonatomic, retain) NSString *type;
@property (nullable, nonatomic, retain) NSString *typeCloud;
@property (nullable, nonatomic, retain) NSString *typeFile;
@property (nullable, nonatomic, retain) NSString *uuid;

@end

NS_ASSUME_NONNULL_END
