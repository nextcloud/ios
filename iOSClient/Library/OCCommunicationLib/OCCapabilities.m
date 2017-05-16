//
//  OCCapabilities.m
//  ownCloud iOS library
//
//  Created by Gonzalo Gonzalez on 4/11/15.
//  Copyright © 2015 ownCloud. All rights reserved.
//

#import "OCCapabilities.h"

@implementation OCCapabilities

- (id)init {
    self = [super init];
    if (self) {
        self.versionMajor = 0;
        self.versionMinor = 0;
        self.versionMicro = 0;
        self.versionString = @"";
        self.versionEdition = @"";
        self.corePollInterval = 0;
        self.filesSharingExpireDateDaysNumber = 0;
        
        self.themingBackground = @"";
        self.themingColor = @"";
        self.themingLogo = @"";
        self.themingName = @"";
        self.themingSlogan = @"";
        self.themingUrl = @"";
    }
    return self;
}



@end
