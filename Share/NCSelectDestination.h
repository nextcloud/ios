//
//  NCSelectDestination.h
//  Nextcloud
//
//  Created by Marino Faggiana on 04/09/14.
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

#import <UIKit/UIKit.h>

#import "CCUtility.h"
#import "CCHud.h"

@class tableMetadata;

@protocol NCSelectDestinationDelegate;

@interface NCSelectDestination : UITableViewController <UIAlertViewDelegate, UITableViewDelegate>

@property (nonatomic, weak) id <NCSelectDestinationDelegate> delegate;

@property BOOL includeDirectoryE2EEncryption;
@property BOOL includeImages;

@property BOOL hideCreateFolder;
@property BOOL hideMoveutton;

@property BOOL selectFile;

@property (nonatomic, strong) NSString *serverUrl;
@property (nonatomic, strong) tableMetadata *passMetadata;
@property (nonatomic, strong) NSString *type;

// Color
@property (nonatomic, strong) UIColor *barTintColor;
@property (nonatomic, strong) UIColor *tintColor;
@property (nonatomic, strong) UIColor *tintColorTitle;

@property (nonatomic, weak) IBOutlet UIBarButtonItem *cancel;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *move;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *create;

@end

@protocol NCSelectDestinationDelegate <NSObject>

@optional - (void)moveServerUrlTo:(NSString *)serverUrlTo title:(NSString *)title type:(NSString *)type;
@optional - (void)dismissMove;
@optional - (void)selectMetadata:(tableMetadata *)metadata serverUrl:(NSString *)serverUrl;

@end
