//
//  NCRequestAsset.h
//  Nextcloud
//
//  Created by Marino Faggiana on 16/06/17.
//  Copyright © 2017 TWS. All rights reserved.
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
#import "CCNetworking.h"

@protocol NCRequestAssetDelegate;

@interface NCRequestAsset : NSObject

@property (nonatomic, weak) id <NCRequestAssetDelegate> delegate;

@property (nonatomic, strong) AVAssetExportSession *exportSession;

- (void)writeAssetToSandboxFileName:(NSString *)fileName assetLocalIdentifier:(NSString *)assetLocalIdentifier selector:(NSString *)selector selectorPost:(NSString *)selectorPost errorCode:(NSInteger)errorCode metadataNet:(CCMetadataNet *)metadataNet serverUrl:(NSString *)serverUrl activeUrl:(NSString *)activeUrl directoryUser:(NSString *)directoryUser cryptated:(BOOL)cryptated session:(NSString *)session taskStatus:(NSInteger)taskStatus delegate:(id)delegate;

@end

@protocol NCRequestAssetDelegate <NSObject>

@optional - (void)addDatabaseAutoUpload:(CCMetadataNet *)metadataNet asset:(PHAsset *)asset;

@optional - (void)upload:(NSString *)fileName serverUrl:(NSString *)serverUrl cryptated:(BOOL)cryptated template:(BOOL)template onlyPlist:(BOOL)onlyPlist fileNameTemplate:(NSString *)fileNameTemplate assetLocalIdentifier:(NSString *)assetLocalIdentifier session:(NSString *)session taskStatus:(NSInteger)taskStatus selector:(NSString *)selector selectorPost:(NSString *)selectorPost errorCode:(NSInteger)errorCode delegate:(id)delegate;

@end
