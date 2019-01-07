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

- (void)checkServerUrl:(NSString *)serverUrl completion:(void (^)(NSString *message, NSInteger errorCode))completion;

- (void)serverStatusUrl:(NSString *)serverUrl completion:(void(^)(NSString *serverProductName, NSInteger versionMajor, NSInteger versionMicro, NSInteger versionMinor, NSString *message, NSInteger errorCode))completion;

- (NSURLSessionTask *)downloadWithAccount:(NSString *)account fileNameServerUrl:(NSString *)fileNameServerUrl fileNameLocalPath:(NSString *)fileNameLocalPath communication:(OCCommunication *)communication completion:(void (^)(NSString *account, int64_t length, NSString *etag, NSDate *date, NSString *message, NSInteger errorCode))completion;

- (NSURLSessionTask *)downloadWithAccount:(NSString *)account url:(NSString *)url fileNameLocalPath:(NSString *)fileNameLocalPath completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion;

- (NSURLSessionTask *)uploadWithAccount:(NSString *)account fileNameServerUrl:(NSString *)fileNameServerUrl fileNameLocalPath:(NSString *)fileNameLocalPath communication:(OCCommunication *)communication completion:(void(^)(NSString *account, NSString *fileID, NSString *etag, NSDate *date, NSString *message, NSInteger errorCode))completion;

//- (void)downloadThumbnailWithMetadata:(tableMetadata*)metadata withWidth:(CGFloat)width andHeight:(CGFloat)height completion:(void (^)(NSString *message, NSInteger errorCode))completion;

- (void)downloadPreviewWithAccount:(NSString *)account metadata:(tableMetadata*)metadata withWidth:(CGFloat)width andHeight:(CGFloat)height completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion;

- (void)downloadPreviewTrashWithAccount:(NSString *)account FileID:(NSString *)fileID fileName:(NSString *)fileName completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion;

- (void)readFolderWithAccount:(NSString *)account serverUrl:(NSString *)serverUrl depth:(NSString *)depth completion:(void(^)(NSString *account, NSArray *metadatas, tableMetadata *metadataFolder, NSString *message, NSInteger errorCode))completion;

- (void)readFileWithAccount:(NSString *)account serverUrl:(NSString *)serverUrl fileName:(NSString *)fileName completion:(void(^)(NSString *account, tableMetadata *metadata, NSString *message, NSInteger errorCode))completion;

- (void)searchWithAccount:(NSString *)account fileName:(NSString *)fileName serverUrl:(NSString *)serverUrl contentType:(NSArray *)contentType date:(NSDate *)date depth:(NSString *)depth completion:(void(^)(NSString *account, NSArray *metadatas, NSString *message, NSInteger errorCode))completion;

- (void)deleteFileOrFolderWithAccount:(NSString *)account path:(NSString *)path completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion;

- (void)createFolderWithAccount:(NSString *)account serverUrl:(NSString *)serverUrl fileName:(NSString *)fileName completion:(void(^)(NSString *account, NSString *fileID, NSDate *date, NSString *message, NSInteger errorCode))completion;

- (void)moveFileOrFolderWithAccount:(NSString *)account fileName:(NSString *)fileName fileNameTo:(NSString *)fileNameTo completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion;

- (void)readShareWithAccount:(NSString *)account completion:(void (^)(NSString *account, NSArray *items, NSString *message, NSInteger errorCode))completion;

- (void)shareWithAccount:(NSString *)account fileName:(NSString *)fileName password:(NSString *)password permission:(NSInteger)permission hideDownload:(BOOL)hideDownload completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion;

- (void)shareUserGroupWithAccount:(NSString *)account userOrGroup:(NSString *)userOrGroup fileName:(NSString *)fileName permission:(NSInteger)permission shareeType:(NSInteger)shareeType completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion;

- (void)shareUpdateAccount:(NSString *)account shareID:(NSInteger)shareID password:(NSString *)password permission:(NSInteger)permission expirationTime:(NSString *)expirationTime hideDownload:(BOOL)hideDownload completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion;

- (void)unshareAccount:(NSString *)account shareID:(NSInteger)shareID completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion;

- (void)settingFavoriteWithAccount:(NSString *)account fileName:(NSString *)fileName favorite:(BOOL)favorite completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion;

- (void)listingFavoritesWithAccount:(NSString *)account completion:(void(^)(NSString *account, NSArray *metadatas, NSString *message, NSInteger errorCode))completion;

- (void)getActivityWithAccount:(NSString *)account completion:(void(^)(NSString *account, NSArray *listOfActivity, NSString *message, NSInteger errorCode))completion;

- (void)getExternalSitesWithAccount:(NSString *)account completion:(void (^)(NSString *account, NSArray *listOfExternalSites, NSString *message, NSInteger errorCode))completion;

- (void)getCapabilitiesWithAccount:(NSString *)account completion:(void (^)(NSString *account, OCCapabilities *capabilities, NSString *message, NSInteger errorCode))completion;

- (void)getNotificationWithAccount:(NSString *)account completion:(void (^)(NSString *account, NSArray *listOfNotifications, NSString *message, NSInteger errorCode))completion;

- (void)setNotificationWithAccount:(NSString *)account serverUrl:(NSString *)serverUrl type:(NSString *)type completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion;

- (void)getUserProfileWithAccount:(NSString *)account completion:(void (^)(NSString *account, OCUserProfile *userProfile, NSString *message, NSInteger errorCode))completion;

- (void)getUserGroupWithAccount:(NSString *)account searchString:(NSString *)searchString completion:(void (^)(NSString *account, NSArray *item, NSString *message, NSInteger errorCode))completion;

- (void)getSharePermissionsFileWithAccount:(NSString *)account fileNamePath:(NSString *)fileNamePath completion:(void (^)(NSString *account, NSString *permissions, NSString *message, NSInteger errorCode))completion;

- (void)subscribingPushNotificationWithAccount:(NSString *)account url:(NSString *)url pushToken:(NSString *)pushToken Hash:(NSString *)pushTokenHash devicePublicKey:(NSString *)devicePublicKey completion:(void(^)(NSString *account, NSString *deviceIdentifier, NSString *deviceIdentifierSignature, NSString *publicKey, NSString *message, NSInteger errorCode))completion;

- (void)unsubscribingPushNotificationWithAccount:(NSString *)account url:(NSString *)url deviceIdentifier:(NSString *)deviceIdentifier deviceIdentifierSignature:(NSString *)deviceIdentifierSignature publicKey:(NSString *)publicKey completion:(void (^)(NSString *account ,NSString *message, NSInteger errorCode))completion;

- (void)createLinkRichdocumentsWithAccount:(NSString *)account fileID:(NSString *)fileID completion:(void(^)(NSString *account, NSString *link, NSString *message, NSInteger errorCode))completion;

- (void)geTemplatesRichdocumentsWithAccount:(NSString *)account typeTemplate:(NSString *)typeTemplate completion:(void(^)(NSString *account, NSArray *listOfTemplate, NSString *message, NSInteger errorCode))completion;

- (void)createNewRichdocumentsWithAccount:(NSString *)account fileName:(NSString *)fileName serverUrl:(NSString *)serverUrl templateID:(NSString *)templateID completion:(void(^)(NSString *account, NSString *url, NSString *message, NSInteger errorCode))completion;

- (void)createAssetRichdocumentsWithAccount:(NSString *)account fileName:(NSString *)fileName serverUrl:(NSString *)serverUrl completion:(void(^)(NSString *account, NSString *link, NSString *message, NSInteger errorCode))completion;

- (void)listingTrashWithAccount:(NSString *)account path:(NSString *)path serverUrl:(NSString *)serverUrl completion:(void (^)(NSString *account, NSArray *items, NSString *message, NSInteger errorCode))completion;

- (void)emptyTrashWithAccount:(NSString *)account completion:(void (^)(NSString *account, NSString *message, NSInteger errorCode))completion;

@end

@protocol OCNetworkingDelegate <NSObject>

@optional

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
