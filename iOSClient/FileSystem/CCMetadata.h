//
//  CCMetadata.h
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 04/09/14.
//  Copyright (c) 2017 TWS. All rights reserved.
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

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

@interface CCMetadata : NSObject <NSCopying, NSCoding>

@property (nonatomic, strong) NSString *account;
@property BOOL cryptated;
@property NSDate *date;
@property BOOL directory;
@property (nonatomic, strong) NSString *directoryID;
@property BOOL errorPasscode;
@property BOOL favorite;
@property (nonatomic, strong) NSString *fileID;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSString *fileNameData;
@property (nonatomic, strong) NSString *fileNamePrint;
@property (nonatomic, strong) NSString *iconName;
@property (nonatomic, strong) NSString *assetLocalIdentifier;
@property (nonatomic, strong) NSString *model;
@property (nonatomic ,strong) NSString *nameCurrentDevice;
@property (nonatomic, strong) NSString *permissions;
@property (nonatomic, strong) NSString *protocol;
@property (nonatomic, strong) NSString *rev;
@property (nonatomic, strong) NSString *session;
@property (nonatomic, strong) NSString *sessionError;
@property (nonatomic, strong) NSString *sessionID;
@property (nonatomic, strong) NSString *sessionSelector;
@property (nonatomic, strong) NSString *sessionSelectorPost;
@property int sessionTaskIdentifier;
@property int sessionTaskIdentifierPlist;
@property long size;
@property BOOL thumbnailExists;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *type;
@property (nonatomic, strong) NSString *typeFile;
@property (nonatomic, strong) NSString *uuid;

- (id)copyWithZone:(NSZone *)zone;
- (id)initWithCCMetadata:(CCMetadata *)metadata;

@end


@interface CCMetadataNet : NSObject <NSCopying>

@property (nonatomic, strong) NSString *account;
@property (nonatomic, strong) NSString *action;
@property BOOL cryptated;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, weak) id delegate;
@property BOOL directory;
@property (nonatomic, strong) NSString *directoryID;
@property (nonatomic, strong) NSString *directoryIDTo;
@property BOOL downloadData;
@property BOOL downloadPlist;
@property NSInteger errorCode;
@property NSInteger errorRetry;
@property (nonatomic, strong) NSString *expirationTime;
@property (nonatomic, strong) NSString *fileID;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSString *fileNameTo;
@property (nonatomic, strong) NSString *fileNameLocal;
@property (nonatomic, strong) NSString *fileNamePrint;
@property (nonatomic, strong) NSString *assetLocalIdentifier;
@property (nonatomic, strong) CCMetadata *metadata;
@property (nonatomic, strong) id options;
@property (nonatomic, strong) NSString *password;
@property (nonatomic, strong) NSString *pathFolder;
@property NSInteger priority;
@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic, strong) NSString *rev;
@property (nonatomic, strong) NSString *serverUrl;
@property (nonatomic, strong) NSString *serverUrlTo;
@property (nonatomic, strong) NSString *selector;
@property (nonatomic, strong) NSString *selectorPost;
@property (nonatomic, strong) NSString *session;
@property (nonatomic, strong) NSString *sessionID;
@property (nonatomic, strong) NSString *share;
@property NSInteger shareeType;
@property NSInteger sharePermission;
@property long size;
@property NSInteger taskStatus;

- (id)initWithAccount:(NSString *)withAccount;
- (id)copyWithZone:(NSZone *)zone;

@end
