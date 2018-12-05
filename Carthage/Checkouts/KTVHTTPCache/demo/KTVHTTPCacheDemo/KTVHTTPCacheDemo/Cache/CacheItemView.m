//
//  CacheItemView.m
//  KTVHTTPCacheDemo
//
//  Created by Single on 2017/8/13.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "CacheItemView.h"

@interface CacheItemView ()

@property (nonatomic, strong) UILabel * totalLengthLabel;
@property (nonatomic, strong) UILabel * cacheLengthLabel;
@property (nonatomic, strong) UILabel * textLabel;
@property (nonatomic, strong) UIButton * deleteButton;

@end

@implementation CacheItemView

- (instancetype)initWithURLString:(NSString *)URLString
                      totalLength:(long long)totalLength
                      cacheLength:(long long)cacheLength
{
    if (self = [super initWithFrame:CGRectZero])
    {
        self.backgroundColor = [UIColor whiteColor];
        
        self.totalLengthLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.totalLengthLabel.textColor = self.totalLengthLabel.tintColor;
        self.totalLengthLabel.font = [UIFont systemFontOfSize:14];
        self.totalLengthLabel.text = [NSString stringWithFormat:@"Total Length : %lld", totalLength];
        
        self.cacheLengthLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.cacheLengthLabel.textColor = self.cacheLengthLabel.tintColor;
        self.cacheLengthLabel.font = [UIFont systemFontOfSize:14];
        self.cacheLengthLabel.text = [NSString stringWithFormat:@"Cache Length : %lld", cacheLength];
        
        self.textLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.textLabel.textColor = self.textLabel.tintColor;
        self.textLabel.font = [UIFont systemFontOfSize:14];
        self.textLabel.text = URLString;
        self.textLabel.numberOfLines = 0;
        
        self.deleteButton = [[UIButton alloc] initWithFrame:CGRectZero];
        [self.deleteButton addTarget:self action:@selector(deleteButtonAction) forControlEvents:UIControlEventTouchUpInside];
        [self.deleteButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        [self.deleteButton setTitle:@"Delete" forState:UIControlStateNormal];
        self.deleteButton.titleLabel.font = [UIFont systemFontOfSize:15];
        
        [self addSubview:self.totalLengthLabel];
        [self addSubview:self.cacheLengthLabel];
        [self addSubview:self.textLabel];
        [self addSubview:self.deleteButton];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    self.totalLengthLabel.frame = CGRectMake(20,
                                             15,
                                             self.bounds.size.width - 40,
                                             18);
    self.cacheLengthLabel.frame = CGRectMake(20,
                                             33,
                                             self.bounds.size.width - 40,
                                             18);
    self.textLabel.frame = CGRectMake(20,
                                      CGRectGetMaxY(self.cacheLengthLabel.frame) + 5,
                                      self.bounds.size.width - 40,
                                      self.bounds.size.height - 60);
    self.deleteButton.frame = CGRectMake(self.bounds.size.width - 40 - 80,
                                         20,
                                         80,
                                         26);
}

- (void)deleteButtonAction
{
    if ([self.delegate respondsToSelector:@selector(cacheItemView:deleteButtonDidClick:)]) {
        [self.delegate cacheItemView:self deleteButtonDidClick:self.textLabel.text];
    }
}

@end
