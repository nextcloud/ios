//
//  NCComments.m
//
//  Created by Marino Faggiana on 08/08/19.
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

#import "NCComments.h"

@implementation NCComments

- (id)init
{
    self = [super init];
    
    self.verb = @"";
    self.actorType = @"";
    self.actorId = @"";
    self.creationDateTime = [NSDate date];
    self.objectType = @"";
    self.actorDisplayName = @"";
    self.message = @"";
    self.messageID = @"";
    self.objectId = @"";
    
    return self;
}
@end
