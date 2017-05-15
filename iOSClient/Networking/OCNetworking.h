//
//  OCnetworking.h
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 10/05/15.
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

#import <Foundation/Foundation.h>

#import "AFURLSessionManager.h"
#import "TWMessageBarManager.h"
#import "CCNetworking.h"
#import "CCMetadata.h"
#import "CCError.h"
#import "CCCoreData.h"


@protocol OCNetworkingDelegate;

@interface OCnetworking : NSOperation <CCNetworkingDelegate>

- (id)initWithDelegate:(id <OCNetworkingDelegate>)delegate metadataNet:(CCMetadataNet *)metadataNet withUser:(NSString *)withUser withPassword:(NSString *)withPassword withUrl:(NSString *)withUrl isCryptoCloudMode:(BOOL)isCryptoCloudMode;

@property (nonatomic, weak) id <OCNetworkingDelegate> delegate;

@property (nonatomic, strong) CCMetadataNet *metadataNet;
@property (nonatomic, assign) BOOL isExecuting;
@property (nonatomic, assign) BOOL isFinished;

- (NSError *)readFileSync:(NSString *)filePathName;
- (NSError *)checkServerSync:(NSString *)serverUrl;
- (BOOL)automaticCreateFolderSync:(NSString *)folderPathName;

@end

@protocol OCNetworkingDelegate <NSObject>

@optional

- (void)downloadTaskSave:(NSURLSessionDownloadTask *)downloadTask;
- (void)downloadFileSuccess:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector selectorPost:(NSString *)selectorPost;
- (void)downloadFileFailure:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)downloadThumbnailSuccess:(CCMetadataNet *)metadataNet;
- (void)downloadThumbnailFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)uploadTaskSave:(NSURLSessionUploadTask *)uploadTask;
- (void)uploadFileSuccess:(CCMetadataNet *)metadataNet fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector selectorPost:(NSString *)selectorPost;
- (void)uploadFileFailure:(CCMetadataNet *)metadataNet fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)readFolderSuccess:(CCMetadataNet *)metadataNet permissions:(NSString *)permissions etag:(NSString *)etag metadatas:(NSArray *)metadatas;
- (void)readFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)createFolderSuccess:(CCMetadataNet *)metadataNet;
- (void)createFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)deleteFileOrFolderSuccess:(CCMetadataNet *)metadataNet;
- (void)deleteFileOrFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)moveSuccess:(CCMetadataNet *)metadataNet revTo:(NSString *)revTo;
- (void)renameSuccess:(CCMetadataNet *)metadataNet;
- (void)renameMoveFileOrFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)readFileSuccess:(CCMetadataNet *)metadataNet metadata:(CCMetadata *)metadata;
- (void)readFileFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)readSharedSuccess:(CCMetadataNet *)metadataNet items:(NSDictionary *)items openWindow:(BOOL)openWindow;
- (void)unShareSuccess:(CCMetadataNet *)metadataNet;
- (void)shareFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)getUserAndGroupSuccess:(CCMetadataNet *)metadataNet items:(NSArray *)items;
- (void)getUserAndGroupFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

// Capabilities
- (void)getCapabilitiesOfServerSuccess:(OCCapabilities *)capabilities;
- (void)getCapabilitiesOfServerFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

// Activity
- (void)getActivityServerSuccess:(NSArray *)listOfActivity;
- (void)getActivityServerFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

// External Sites
- (void)getExternalSitesServerSuccess:(NSArray *)listOfExternalSites;
- (void)getExternalSitesServerFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

// Notification
- (void)getNotificationServerSuccess:(NSArray *)listOfNotifications;
- (void)getNotificationServerFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)setNotificationServerSuccess:(CCMetadataNet *)metadataNet;
- (void)setNotificationServerFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

// User Profile
- (void)getUserProfileSuccess:(CCMetadataNet *)metadataNet userProfile:(OCUserProfile *)userProfile;
- (void)getUserProfileFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

// Search
- (void)searchSuccess:(CCMetadataNet *)metadataNet metadatas:(NSArray *)metadatas;
- (void)searchFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

// Favorite
- (void)settingFavoriteSuccess:(CCMetadataNet *)metadataNet;
- (void)settingFavoriteFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;
- (void)listingFavoritesSuccess:(CCMetadataNet *)metadataNet metadatas:(NSArray *)metadatas;
- (void)listingFavoritesFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

// Subscribing Nextcloud Server
- (void)subscribingNextcloudServerFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

@end

@interface OCURLSessionManager : AFURLSessionManager

@end
