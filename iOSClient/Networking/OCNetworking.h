//
//  OCnetworking.h
//  Nextcloud iOS
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
#import "CCError.h"

@class tableMetadata;

@protocol OCNetworkingDelegate;

@interface OCnetworking : NSOperation <CCNetworkingDelegate>

- (id)initWithDelegate:(id <OCNetworkingDelegate>)delegate metadataNet:(CCMetadataNet *)metadataNet withUser:(NSString *)withUser withUserID:(NSString *)withUserID withPassword:(NSString *)withPassword withUrl:(NSString *)withUrl;

@property (nonatomic, weak) id <OCNetworkingDelegate> delegate;

@property (nonatomic, strong) CCMetadataNet *metadataNet;
@property (nonatomic, assign) BOOL isExecuting;
@property (nonatomic, assign) BOOL isFinished;

- (NSURLSessionTask *)downloadFileNameServerUrl:(NSString *)fileNameServerUrl fileNameLocalPath:(NSString *)fileNameLocalPath communication:(OCCommunication *)communication success:(void (^)(int64_t length))success failure:(void (^)(NSString *message, NSInteger errorCode))failure;
- (NSURLSessionTask *)uploadFileNameServerUrl:(NSString *)fileNameServerUrl fileNameLocalPath:(NSString *)fileNameLocalPath communication:(OCCommunication *)communication success:(void(^)(NSString *fileID, NSString *etag, NSDate *date))success failure:(void (^)(NSString *message, NSInteger errorCode))failure;
- (void)downloadThumbnailWithDimOfThumbnail:(NSString *)dimOfThumbnail fileName:(NSString *)fileName fileNameLocal:(NSString *)fileNameLocal success:(void (^)(void))success failure:(void (^)(NSString *message, NSInteger errorCode))failure;
- (void)readFolderWithServerUrl:(NSString *)serverUrl depth:(NSString *)depth account:(NSString *)account success:(void(^)(NSArray *metadatas, tableMetadata *metadataFolder, NSString *directoryID))success failure:(void (^)(NSString *message, NSInteger errorCode))failure;
- (void)deleteFileOrFolder:(NSString *)fileName serverUrl:(NSString *)serverUrl success:(void (^)(void))success failure:(void (^)(NSString *message, NSInteger errorCode))failure;
- (void)createFolder:(NSString *)fileName serverUrl:(NSString *)serverUrl account:(NSString *)account success:(void(^)(NSString *fileID, NSDate *date))success failure:(void (^)(NSString *message, NSInteger errorCode))failure;

@end

@protocol OCNetworkingDelegate <NSObject>

@optional

- (void)downloadThumbnailSuccessFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)readFolderSuccessFailure:(CCMetadataNet *)metadataNet metadataFolder:(tableMetadata *)metadataFolder metadatas:(NSArray *)metadatas message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)createFolderSuccessFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)deleteFileOrFolderSuccessFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)moveSuccess:(CCMetadataNet *)metadataNet;
- (void)renameSuccess:(CCMetadataNet *)metadataNet;
- (void)renameMoveFileOrFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)readFileSuccessFailure:(CCMetadataNet *)metadataNet metadata:(tableMetadata *)metadata message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)readSharedSuccess:(CCMetadataNet *)metadataNet items:(NSDictionary *)items openWindow:(BOOL)openWindow;
- (void)unShareSuccess:(CCMetadataNet *)metadataNet;
- (void)shareFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)getUserAndGroupSuccess:(CCMetadataNet *)metadataNet items:(NSArray *)items;
- (void)getUserAndGroupFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)getSharePermissionsFileSuccess:(CCMetadataNet *)metadataNet permissions:(NSString *)permissions;
- (void)getSharePermissionsFileFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

// Capabilities
- (void)getCapabilitiesOfServerSuccessFailure:(CCMetadataNet *)metadataNet capabilities:(OCCapabilities *)capabilities message:(NSString *)message errorCode:(NSInteger)errorCode;

// Activity
- (void)getActivityServerSuccessFailure:(CCMetadataNet *)metadataNet listOfActivity:(NSArray *)listOfActivity message:(NSString *)message errorCode:(NSInteger)errorCode;

// External Sites
- (void)getExternalSitesServerSuccessFailure:(CCMetadataNet *)metadataNet listOfExternalSites:(NSArray *)listOfExternalSites message:(NSString *)message errorCode:(NSInteger)errorCode;

// Notification
- (void)getNotificationServerSuccessFailure:(CCMetadataNet *)metadataNet listOfNotifications:(NSArray *)listOfNotifications message:(NSString *)message errorCode:(NSInteger)errorCode;
- (void)setNotificationServerSuccessFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

// User Profile
- (void)getUserProfileSuccessFailure:(CCMetadataNet *)metadataNet userProfile:(OCUserProfile *)userProfile message:(NSString *)message errorCode:(NSInteger)errorCode;

// Search
- (void)searchSuccessFailure:(CCMetadataNet *)metadataNet metadatas:(NSArray *)metadatas message:(NSString *)message errorCode:(NSInteger)errorCode;

// Favorite
- (void)settingFavoriteSuccessFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;
- (void)listingFavoritesSuccessFailure:(CCMetadataNet *)metadataNet metadatas:(NSArray *)metadatas message:(NSString *)message errorCode:(NSInteger)errorCode;

// Subscribing Nextcloud Server
- (void)subscribingNextcloudServerFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

// End-to-End Encryption
- (void)getEndToEndPublicKeysSuccess:(CCMetadataNet *)metadataNet;
- (void)getEndToEndPublicKeysFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;
- (void)signEndToEndPublicKeySuccess:(CCMetadataNet *)metadataNet;
- (void)signEndToEndPublicKeyFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;
- (void)deleteEndToEndPublicKeySuccess:(CCMetadataNet *)metadataNet;
- (void)deleteEndToEndPublicKeyFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)getEndToEndPrivateKeyCipherSuccess:(CCMetadataNet *)metadataNet;
- (void)getEndToEndPrivateKeyCipherFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;
- (void)storeEndToEndPrivateKeyCipherSuccess:(CCMetadataNet *)metadataNet;
- (void)storeEndToEndPrivateKeyCipherFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;
- (void)deleteEndToEndPrivateKeySuccess:(CCMetadataNet *)metadataNet;
- (void)deleteEndToEndPrivateKeyFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)getEndToEndServerPublicKeySuccess:(CCMetadataNet *)metadataNet;
- (void)getEndToEndServerPublicKeyFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

@end

@interface OCURLSessionManager : AFURLSessionManager

@end
