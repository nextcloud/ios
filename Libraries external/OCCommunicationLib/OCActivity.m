//
//  OCActivity.m
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

#import "OCActivity.h"

@implementation OCActivity

- (id)init {
    
    self = [super init];
    
    if (self) {
        
        self.idActivity = 0;
        self.date = [NSDate date];
        self.app = @"";
        self.type = @"";
        self.user = @"";
        self.message = @"";
        self.message_rich = [NSArray new];
        self.icon = @"";
        self.link = @"";
        self.previews = [NSArray new];
        self.subject = @"";
        self.subject_rich = [NSArray new];
        self.object_type = @"";
        self.object_id = 0;
        self.object_name = @"";
    }
    
    return self;
}

@end
