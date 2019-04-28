//
//  OCUserProfile.h
//  ownCloud iOS library
//
//  Created by Marino Faggiana on 16/02/17.
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

@interface OCUserProfile : NSObject

@property (nonatomic, strong) NSString *id;
@property BOOL enabled;

@property (nonatomic, strong) NSString *address;
@property (nonatomic, strong) NSString *businessSize;
@property (nonatomic, strong) NSString *businessType;
@property (nonatomic, strong) NSString *city;
@property (nonatomic, strong) NSString *company;
@property (nonatomic, strong) NSString *country;
@property (nonatomic, strong) NSString *displayName;
@property (nonatomic, strong) NSString *email;
@property (nonatomic, strong) NSString *phone;
@property (nonatomic, strong) NSString *role;
@property (nonatomic, strong) NSString *twitter;
@property (nonatomic, strong) NSString *webpage;
@property (nonatomic, strong) NSString *zip;

@property double quota;
@property double quotaFree;
@property double quotaRelative;
@property double quotaTotal;
@property double quotaUsed;

@end
