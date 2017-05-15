//
//  CCPatenteGuida.h
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 25/11/14.
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
#import "CCTemplates.h"

@protocol CCPatenteGuidaDelegate <NSObject>

- (void)readFolderWithForced:(BOOL)forced serverUrl:(NSString *)serverUrl;

@end

@interface CCPatenteGuida : XLFormViewController

@property(nonatomic, weak) id <CCPatenteGuidaDelegate> delegate;

- (id)initWithDelegate:(id <CCPatenteGuidaDelegate>)delegate fileName:(NSString *)fileName uuid:(NSString *)uuid fileID:(NSString *)fileID isLocal:(BOOL)isLocal serverUrl:(NSString *)serverUrl;

@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSString *uuid;
@property (nonatomic, strong) NSString *rev;
@property (nonatomic, strong) NSString *fileID;
@property (nonatomic, strong) NSString *serverUrl;
@property BOOL isLocal;

@end
