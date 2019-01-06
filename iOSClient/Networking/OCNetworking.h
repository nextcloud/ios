//
//  OCnetworking.h
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 10/05/15.
//  Copyright (c) 2017 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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

- (id)initWithDelegate:(id)delegate metadataNet:(CCMetadataNet *)metadataNet withUser:(NSString *)withUser withUserID:(NSString *)withUserID withPassword:(NSString *)withPassword withUrl:(NSString *)withUrl;

@property (nonatomic, weak) id delegate;

@property (nonatomic, strong) CCMetadataNet *metadataNet;
@property (nonatomic, assign) BOOL isExecuting;
@property (nonatomic, assign) BOOL isFinished;

- (void)checkServer:(NSString *)serverUrl success:(void (^)(void))success failure:(void (^)(NSString *message, NSInteger errorCode))failure;
- (void)serverStatus:(NSString *)serverUrl success:(void(^)(NSString *serverProductName, NSInteger versionMajor, NSInteger versionMicro, NSInteger versionMinor))success failure:(void (^)(NSString *message, NSInteger errorCode))failure;

- (NSURLSessionTask *)downloadFileNameServerUrl:(NSString *)fileNameServerUrl fileNameLocalPath:(NSString *)fileNameLocalPath communication:(OCCommunication *)communication success:(void (^)(int64_t length, NSString *etag, NSDate *date))success failure:(void (^)(NSString *message, NSInteger errorCode))failure;

- (NSURLSessionTask *)downloadFile:(NSString *)url fileNameLocalPath:(NSString *)fileNameLocalPath  success:(void (^)())success failure:(void (^)(NSString *message, NSInteger errorCode))failure;

- (NSURLSessionTask *)uploadFileNameServerUrl:(NSString *)fileNameServerUrl fileNameLocalPath:(NSString *)fileNameLocalPath communication:(OCCommunication *)communication success:(void(^)(NSString *fileID, NSString *etag, NSDate *date))success failure:(void (^)(NSString *message, NSInteger errorCode))failure;

//- (void)downloadThumbnailWithMetadata:(tableMetadata*)metadata withWidth:(CGFloat)width andHeight:(CGFloat)height completion:(void (^)(NSString *message, NSInteger errorCode))completion;
- (void)downloadPreviewWithMetadata:(tableMetadata*)metadata withWidth:(CGFloat)width andHeight:(CGFloat)height completion:(void (^)(NSString *message, NSInteger errorCode))completion;
- (void)downloadPreviewTrashWithFileID:(NSString *)fileID fileName:(NSString *)fileName account:(NSString *)account completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion;

- (void)readFolder:(NSString *)serverUrl depth:(NSString *)depth account:(NSString *)account success:(void(^)(NSString *account, NSArray *metadatas, tableMetadata *metadataFolder))success failure:(void (^)(NSString *account, NSString *message, NSInteger errorCode))failure;

- (void)readFile:(NSString *)fileName serverUrl:(NSString *)serverUrl account:(NSString *)account success:(void(^)(NSString *account, tableMetadata *metadata))success failure:(void (^)(NSString *account, NSString *message, NSInteger errorCode))failure;

- (void)deleteFileOrFolder:(NSString *)path account:(NSString *)account completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion;

- (void)createFolder:(NSString *)fileName serverUrl:(NSString *)serverUrl account:(NSString *)account success:(void(^)(NSString *account, NSString *fileID, NSDate *date))success failure:(void (^)(NSString *account, NSString *message, NSInteger errorCode))failure;

- (void)moveFileOrFolder:(NSString *)fileName fileNameTo:(NSString *)fileNameTo account:(NSString *)account success:(void (^)(NSString *account))success failure:(void (^)(NSString *account, NSString *message, NSInteger errorCode))failure;

- (void)readShareServer:(NSString *)account completion:(void (^)(NSString *account, NSArray *items, NSString *message, NSInteger errorCode))completion;

- (void)settingFavorite:(NSString *)fileName account:(NSString *)account favorite:(BOOL)favorite completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion;

- (void)listingFavorites:(NSString *)serverUrl account:(NSString *)account success:(void(^)(NSString *account, NSArray *metadatas))success failure:(void (^)(NSString* account, NSString *message, NSInteger errorCode))failure;

- (void)getActivityServer:(NSString *)account success:(void(^)(NSString *account, NSArray *listOfActivity))success failure:(void (^)(NSString *account, NSString *message, NSInteger errorCode))failure;

- (void)getExternalSitesServer:(NSString *)account completion:(void (^)(NSString *account, NSArray *listOfExternalSites, NSString *message, NSInteger errorCode))completion;

- (void)getCapabilitiesOfServer:(NSString *)account completion:(void (^)(NSString *account, OCCapabilities *capabilities, NSString *message, NSInteger errorCode))completion;

- (void)getNotificationServer:(NSString *)account completion:(void (^)(NSString *account, NSArray *listOfNotifications, NSString *message, NSInteger errorCode))completion;

- (void)setNotificationServer:(NSString *)account serverUrl:(NSString *)serverUrl type:(NSString *)type completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion;

- (void)getUserProfile:(NSString *)account completion:(void (^)(NSString *account, OCUserProfile *userProfile, NSString *message, NSInteger errorCode))completion;

- (void)subscribingPushNotificationServer:(NSString *)url pushToken:(NSString *)pushToken Hash:(NSString *)pushTokenHash devicePublicKey:(NSString *)devicePublicKey success:(void(^)(NSString *deviceIdentifier, NSString *deviceIdentifierSignature, NSString *publicKey))success failure:(void (^)(NSString *message, NSInteger errorCode))failure;

- (void)unsubscribingPushNotificationServer:(NSString *)url deviceIdentifier:(NSString *)deviceIdentifier deviceIdentifierSignature:(NSString *)deviceIdentifierSignature publicKey:(NSString *)publicKey success:(void (^)(void))success failure:(void (^)(NSString *message, NSInteger errorCode))failure;

- (void)createLinkRichdocumentsWithFileID:(NSString *)fileID success:(void(^)(NSString *link))success failure:(void (^)(NSString *message, NSInteger errorCode))failure;

- (void)geTemplatesRichdocumentsWithTypeTemplate:(NSString *)typeTemplate success:(void(^)(NSArray *listOfTemplate))success failure:(void (^)(NSString *message, NSInteger errorCode))failure;

- (void)createNewRichdocumentsWithFileName:(NSString *)fileName serverUrl:(NSString *)serverUrl templateID:(NSString *)templateID success:(void(^)(NSString *url))success failure:(void (^)(NSString *message, NSInteger errorCode))failure;

- (void)createAssetRichdocumentsWithFileName:(NSString *)fileName serverUrl:(NSString *)serverUrl success:(void(^)(NSString *link))success failure:(void (^)(NSString *message, NSInteger errorCode))failure;

- (void)listingTrash:(NSString *)serverUrl path:(NSString *)path account:(NSString *)account success:(void(^)(NSArray *items))success failure:(void (^)(NSString *message, NSInteger errorCode))failure;

- (void)emptyTrash:(void (^)(NSString *message, NSInteger errorCode))completion;

@end

@protocol OCNetworkingDelegate <NSObject>

@optional

- (void)unShareSuccess:(CCMetadataNet *)metadataNet;
- (void)shareFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)getUserAndGroupSuccess:(CCMetadataNet *)metadataNet items:(NSArray *)items;
- (void)getUserAndGroupFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)getSharePermissionsFileSuccess:(CCMetadataNet *)metadataNet permissions:(NSString *)permissions;
- (void)getSharePermissionsFileFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

// Search
- (void)searchSuccessFailure:(CCMetadataNet *)metadataNet metadatas:(NSArray *)metadatas message:(NSString *)message errorCode:(NSInteger)errorCode;

// Favorite
- (void)settingFavoriteSuccessFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;
- (void)listingFavoritesSuccessFailure:(CCMetadataNet *)metadataNet metadatas:(NSArray *)metadatas message:(NSString *)message errorCode:(NSInteger)errorCode;

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
