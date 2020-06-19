//
//  OCActivity.h
//  ownCloud iOS library
//
//  Created by Marino Faggiana on 01/03/17.
//  Copyright © 2017 Marino Faggiana. All rights reserved.
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

@interface OCActivity : NSObject

@property NSInteger idActivity;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, strong) NSString *app;
@property (nonatomic, strong) NSString *type;
@property (nonatomic, strong) NSString *user;
@property (nonatomic, strong) NSString *subject;
@property (nonatomic, strong) NSArray *subject_rich;
@property (nonatomic, strong) NSString *message;
@property (nonatomic, strong) NSArray *message_rich;
@property (nonatomic, strong) NSString *icon;
@property (nonatomic, strong) NSString *link;
@property (nonatomic, strong) NSString *object_type;
@property NSInteger object_id;
@property (nonatomic, strong) NSString *object_name;
@property (nonatomic, strong) NSArray *previews;

@end

