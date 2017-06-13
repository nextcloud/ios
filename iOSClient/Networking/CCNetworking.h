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
#import "CCCrypto.h"
#import "CCExifGeo.h"
#import "CCGraphics.h"
#import "CCError.h"

@class tableMetadata;
@class CCMetadataNet;

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
- (void)downloadFile:(NSString *)fileID serverUrl:(NSString *)serverUrl downloadData:(BOOL)downloadData downloadPlist:(BOOL)downloadPlist selector:(NSString *)selector selectorPost:(NSString *)selectorPost session:(NSString *)session taskStatus:(NSInteger)taskStatus delegate:(id)delegate;

// Upload
- (void)uploadFileFromAssetLocalIdentifier:(NSString *)assetLocalIdentifier fileName:(NSString *)fileName serverUrl:(NSString *)serverUrl cryptated:(BOOL)cryptated session:(NSString *)session taskStatus:(NSInteger)taskStatus selector:(NSString *)selector selectorPost:(NSString *)selectorPost errorCode:(NSInteger)errorCode delegate:(id)delegate;
- (void)uploadFile:(NSString *)fileName serverUrl:(NSString *)serverUrl cryptated:(BOOL)cryptated onlyPlist:(BOOL)onlyPlist session:(NSString *)session taskStatus:(NSInteger)taskStatus selector:(NSString *)selector selectorPost:(NSString *)selectorPost errorCode:(NSInteger)errorCode delegate:(id)delegate;
- (void)uploadTemplate:(NSString *)fileNamePrint fileNameCrypto:(NSString *)fileNameCrypto serverUrl:(NSString *)serverUrl session:(NSString *)session taskStatus:(NSInteger)taskStatus selector:(NSString *)selector selectorPost:(NSString *)selectorPost errorCode:(NSInteger)errorCode delegate:(id)delegate;
- (void)uploadFileMetadata:(tableMetadata *)metadata taskStatus:(NSInteger)taskStatus;

// Verify
- (void)verifyDownloadInProgress;
- (void)verifyUploadInProgress;

@end

@protocol CCNetworkingDelegate <NSObject>

@optional - (void)reloadDatasource:(NSString *)serverUrl;

@optional - (void)downloadFileSuccess:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector selectorPost:(NSString *)selectorPost;
@optional - (void)downloadFileFailure:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector message:(NSString *)message errorCode:(NSInteger)errorCode;

@optional - (void)uploadFileSuccess:(CCMetadataNet *)metadataNet fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector selectorPost:(NSString *)selectorPost;
@optional - (void)uploadFileFailure:(CCMetadataNet *)metadataNet fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector message:(NSString *)message errorCode:(NSInteger)errorCode;

@end

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  CCMetadataNet =====
#pragma --------------------------------------------------------------------------------------------


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
@property (nonatomic, strong) NSString *etag;
@property (nonatomic, strong) NSString *expirationTime;
@property (nonatomic, strong) NSString *fileID;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSString *fileNameTo;
@property (nonatomic, strong) NSString *fileNameLocal;
@property (nonatomic, strong) NSString *fileNamePrint;
@property (nonatomic, strong) NSString *assetLocalIdentifier;
@property (nonatomic, strong) id options;
@property (nonatomic, strong) NSString *password;
@property (nonatomic, strong) NSString *pathFolder;
@property NSInteger priority;
@property (nonatomic, strong) NSOperationQueue *queue;
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


