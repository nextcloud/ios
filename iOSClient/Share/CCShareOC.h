//
//  CCShareOC.h
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 13/11/15.
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

#import "XLFormViewController.h"
#import "CCShareUserOC.h"
#import "CCSharePermissionOC.h"

@class tableMetadata;

@protocol CCShareOCDelegate;

@interface CCShareOC : XLFormViewController <CCShareUserOCDelegate, CCSharePermissionOCDelegate>

@property (nonatomic, weak) id <CCShareOCDelegate> delegate;

@property (nonatomic, weak) IBOutlet UIImageView *fileImageView;
@property (nonatomic, weak) IBOutlet UILabel *labelTitle;
@property (nonatomic, weak) IBOutlet UIButton *endButton;

@property (nonatomic, strong) NSString *serverUrl;
@property (nonatomic, strong) NSString *shareLink;
@property (nonatomic, strong) NSString *shareUserAndGroup;
@property (nonatomic, strong) tableMetadata *metadata;

@property (nonatomic, strong) OCSharedDto *itemShareLink;
@property (nonatomic, strong) NSArray *itemsUserAndGroupLink;
@property (nonatomic, strong) NSMutableArray *itemsShareWith;
@property (nonatomic, weak) CCShareUserOC *shareUserOC;
@property (nonatomic, weak) CCSharePermissionOC *sharePermissionOC;

- (void)reloadData;
- (void)reloadUserAndGroup:(NSArray *)items;

- (IBAction)endButtonAction:(id)sender;

@end

@protocol CCShareOCDelegate

- (void)share:(tableMetadata *)metadata serverUrl:(NSString *)serverUrl password:(NSString *)password;
- (void)unShare:(NSString *)share metadata:(tableMetadata *)metadata serverUrl:(NSString *)serverUrl;
- (void)updateShare:(NSString *)share metadata:(tableMetadata *)metadata serverUrl:(NSString *)serverUrl password:(NSString *)password expirationTime:(NSString *)expirationTime permission:(NSInteger)permission;

- (void)reloadDatasource:(NSString *)serverUrl;
- (void)getUserAndGroup:(NSString *)find;
- (void)shareUserAndGroup:(NSString *)user shareeType:(NSInteger)shareeType permission:(NSInteger)permission metadata:(tableMetadata *)metadata directoryID:(NSString *)directoryID serverUrl:(NSString *)serverUrl;

@end
