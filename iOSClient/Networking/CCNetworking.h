//
//  CCNetworking.h
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 01/06/15.
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
#import <Photos/Photos.h>

#import "OCCommunication.h"
#import "OCFrameworkConstants.h"
#import "AFURLSessionManager.h"
#import "TWMessageBarManager.h"
#import "PHAsset+Utility.h"
#import "CCCoreData.h"
#import "CCCrypto.h"
#import "CCMetadata.h"
#import "CCExifGeo.h"
#import "CCGraphics.h"
#import "CCError.h"

@protocol CCNetworkingDelegate;

@interface CCNetworking : NSObject <NSURLSessionTaskDelegate, NSURLSessionDelegate, NSURLSessionDownloadDelegate>

@property (nonatomic, weak) id <CCNetworkingDelegate> delegate;
@property (nonatomic, strong) NSMutableDictionary *delegates;

+ (CCNetworking *)sharedNetworking;

- (void)settingDelegate:(id <CCNetworkingDelegate>)delegate;
- (void)settingAccount;

// Sessions - Task
- (OCCommunication *)sharedOCCommunication;
- (NSURLSession *)getSessionfromSessionDescription:(NSString *)sessionDescription;

- (void)invalidateAndCancelAllSession;
- (void)settingSessionsDownload:(BOOL)download upload:(BOOL)upload taskStatus:(NSInteger)taskStatus activeAccount:(NSString *)activeAccount activeUser:(NSString *)activeUser activeUrl:(NSString *)activeUrl;
- (void)settingSession:(NSString *)sessionDescription sessionTaskIdentifier:(NSUInteger)sessionTaskIdentifier taskStatus:(NSInteger)taskStatus;

// Download
- (void)downloadFile:(CCMetadata *)metadata serverUrl:(NSString *)serverUrl downloadData:(BOOL)downloadData downloadPlist:(BOOL)downloadPlist selector:(NSString *)selector selectorPost:(NSString *)selectorPost session:(NSString *)session taskStatus:(NSInteger)taskStatus delegate:(id)delegate;

// Upload
- (void)uploadFileFromAssetLocalIdentifier:(NSString *)assetLocalIdentifier fileName:(NSString *)fileName serverUrl:(NSString *)serverUrl cryptated:(BOOL)cryptated session:(NSString *)session taskStatus:(NSInteger)taskStatus selector:(NSString *)selector selectorPost:(NSString *)selectorPost errorCode:(NSInteger)errorCode delegate:(id)delegate;
- (void)uploadFile:(NSString *)fileName serverUrl:(NSString *)serverUrl cryptated:(BOOL)cryptated onlyPlist:(BOOL)onlyPlist session:(NSString *)session taskStatus:(NSInteger)taskStatus selector:(NSString *)selector selectorPost:(NSString *)selectorPost errorCode:(NSInteger)errorCode delegate:(id)delegate;
- (void)uploadTemplate:(NSString *)fileNamePrint fileNameCrypto:(NSString *)fileNameCrypto serverUrl:(NSString *)serverUrl session:(NSString *)session taskStatus:(NSInteger)taskStatus selector:(NSString *)selector selectorPost:(NSString *)selectorPost errorCode:(NSInteger)errorCode delegate:(id)delegate;
- (void)uploadFileMetadata:(CCMetadata *)metadata taskStatus:(NSInteger)taskStatus;

// Verify
- (void)verifyDownloadInProgress;
- (void)automaticDownloadInError;

- (void)verifyUploadInProgress;
- (void)automaticUploadInError;

@end

@protocol CCNetworkingDelegate <NSObject>

@optional - (void)reloadDatasource:(NSString *)serverUrl fileID:(NSString *)fileID selector:(NSString *)selector;
@optional - (void)comandoCreaCartella:(NSString *)fileNameFolder cameraUpload:(BOOL)cameraUpload;

@optional - (void)downloadTaskSave:(NSURLSessionDownloadTask *)downloadTask;
@optional - (void)downloadFileSuccess:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector selectorPost:(NSString *)selectorPost;
@optional - (void)downloadFileFailure:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector message:(NSString *)message errorCode:(NSInteger)errorCode;

@optional - (void)uploadTaskSave:(NSURLSessionUploadTask *)uploadTask;
@optional - (void)uploadFileSuccess:(CCMetadataNet *)metadataNet fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector selectorPost:(NSString *)selectorPost;
@optional - (void)uploadFileFailure:(CCMetadataNet *)metadataNet fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector message:(NSString *)message errorCode:(NSInteger)errorCode;

@end
