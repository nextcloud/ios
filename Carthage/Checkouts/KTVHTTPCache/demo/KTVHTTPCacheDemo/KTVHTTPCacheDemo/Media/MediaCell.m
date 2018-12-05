//
//  MediaCell.m
//  KTVHTTPCacheDemo
//
//  Created by Single on 2017/8/13.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "MediaCell.h"

@interface MediaCell ()

@property (weak, nonatomic) IBOutlet UILabel * titleLabel;

@end

@implementation MediaCell

- (void)configureWithTitle:(NSString *)title
{
    self.titleLabel.text = title;
}

@end
