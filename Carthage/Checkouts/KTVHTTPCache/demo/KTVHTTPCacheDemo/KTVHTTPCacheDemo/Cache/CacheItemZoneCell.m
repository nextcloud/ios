//
//  CacheItemZoneCell.m
//  KTVHTTPCacheDemo
//
//  Created by Single on 2017/8/13.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "CacheItemZoneCell.h"

@interface CacheItemZoneCell ()

@property (weak, nonatomic) IBOutlet UILabel * offsetLabel;
@property (weak, nonatomic) IBOutlet UILabel * lengthLabel;

@end

@implementation CacheItemZoneCell

- (void)configureWithOffset:(long long)offset length:(long long)length
{
    self.offsetLabel.text = [NSString stringWithFormat:@"Offset : %lld", offset];
    self.lengthLabel.text = [NSString stringWithFormat:@"Length : %lld", length];
}

@end
