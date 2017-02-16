//
//  OCUserProfile.h
//  ownCloud iOS library
//
//  Created by Marino Faggiana on 16/02/17.
//  Copyright © 2017 ownCloud. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OCUserProfile : NSObject

@property double quotaFree;
@property double quotaUsed;
@property double quotaTotal;
@property double quotaRelative;
@property double quota;
@property (nonatomic, strong) NSString *email;
@property (nonatomic, strong) NSString *displayName;
@property (nonatomic, strong) NSString *phone;
@property (nonatomic, strong) NSString *address;
@property (nonatomic, strong) NSString *webpage;
@property (nonatomic, strong) NSString *twitter;

@end
