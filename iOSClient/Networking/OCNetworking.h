//
//  OCnetworking.h
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 10/05/15.
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

#import <Foundation/Foundation.h>

#import "AFURLSessionManager.h"
#import "TWMessageBarManager.h"
#import "CCNetworking.h"
#import "CCMetadata.h"
#import "CCError.h"
#import "CCCoreData.h"



@protocol OCNetworkingDelegate;

@interface OCnetworking : NSOperation <CCNetworkingDelegate>

- (id)initWithDelegate:(id <OCNetworkingDelegate>)delegate metadataNet:(CCMetadataNet *)metadataNet withUser:(NSString *)withUser withPassword:(NSString *)withPassword withUrl:(NSString *)withUrl withTypeCloud:(NSString *)withTypeCloud activityIndicator:(BOOL)activityIndicator;

@property (nonatomic, weak) id <OCNetworkingDelegate> delegate;

@property (nonatomic, strong) CCMetadataNet *metadataNet;
@property (nonatomic, assign) BOOL isExecuting;
@property (nonatomic, assign) BOOL isFinished;

- (NSError *)createFolderSync:(NSString *)folderPathName;
- (NSError *)readFileSync:(NSString *)filePathName;
- (NSError *)checkServerSync:(NSString *)serverUrl;

@end

@protocol OCNetworkingDelegate <NSObject>

@optional

- (void)downloadTaskSave:(NSURLSessionDownloadTask *)downloadTask;
- (void)downloadFileSuccess:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector selectorPost:(NSString *)selectorPost;
- (void)downloadFileFailure:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)downloadThumbnailSuccess:(CCMetadataNet *)metadataNet;
- (void)downloadThumbnailFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)uploadTaskSave:(NSURLSessionUploadTask *)uploadTask;
- (void)uploadFileSuccess:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector selectorPost:(NSString *)selectorPost;
- (void)uploadFileFailure:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)readFolderSuccess:(CCMetadataNet *)metadataNet permissions:(NSString *)permissions rev:(NSString *)rev metadatas:(NSArray *)metadatas;
- (void)readFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)createFolderSuccess:(CCMetadataNet *)metadataNet;
- (void)createFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)deleteFileOrFolderSuccess:(CCMetadataNet *)metadataNet;
- (void)deleteFileOrFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)moveSuccess:(CCMetadataNet *)metadataNet revTo:(NSString *)revTo;
- (void)renameSuccess:(CCMetadataNet *)metadataNet revTo:(NSString *)revTo;
- (void)moveFileOrFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)readFileSuccess:(CCMetadataNet *)metadataNet metadata:(CCMetadata *)metadata;
- (void)readFileFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)readSharedSuccess:(CCMetadataNet *)metadataNet items:(NSDictionary *)items openWindow:(BOOL)openWindow;
- (void)unShareSuccess:(CCMetadataNet *)metadataNet;
- (void)shareFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

- (void)getUserAndGroupSuccess:(CCMetadataNet *)metadataNet items:(NSArray *)items;
- (void)getUserAndGroupFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

// Capabilities
- (void)getFeaturesSupportedByServerSuccess:(BOOL)hasCapabilitiesSupport hasForbiddenCharactersSupport:(BOOL)hasForbiddenCharactersSupport hasShareSupport:(BOOL)hasShareSupport hasShareeSupport:(BOOL)hasShareeSupport;
- (void)getCapabilitiesOfServerSuccess:(OCCapabilities *)capabilities;
- (void)getInfoServerFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

// Notification
- (void)getNotificationsOfServerSuccess:(NSArray *)listOfNotifications;
- (void)getNotificationsOfServerFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;

// HUD
- (void)progressTask:(NSString *)fileID serverUrl:(NSString *)serverUrl cryptated:(BOOL)cryptated progress:(float)progress;

@end

@interface OCURLSessionManager : AFURLSessionManager

@end
