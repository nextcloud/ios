//
//  HCFeatures.h
//
//  Created by Marino Faggiana on 14/04/19.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
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

@interface HCFeatures : NSObject

@property BOOL isTrial;
@property BOOL trialExpired;
@property double trialRemainingSec;
@property double trialEndTime;
@property (nonatomic, strong) NSString *trialEnd;

@property BOOL accountRemoveExpired;
@property double accountRemoveRemainingSec;
@property double accountRemoveTime;
@property (nonatomic, strong) NSString *accountRemove;

@property (nonatomic, strong) NSString *nextGroupExpirationGroup;
@property BOOL nextGroupExpirationGroupExpired;
@property double nextGroupExpirationExpiresTime;
@property (nonatomic, strong) NSString *nextGroupExpirationExpires;


@end
