//
//  PPCollectionViewCell.m
//  PPImageScrollingTableViewControllerDemo
//
//  Created by popochess on 13/8/10.
//  Copyright (c) 2013年 popochess. All rights reserved.
//

#import "PPCollectionViewCell.h"

@interface PPCollectionViewCell ()

@property (strong, nonatomic) UIImageView *imageView;
@property (strong, nonatomic) UITextView *imageTitle;

@end

@implementation PPCollectionViewCell

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        self.imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0., 0., frame.size.width, frame.size.height)];
    }
    return self;
}

-(void)setImage:(UIImage *)image
{
    self.imageView.image = image;
}

- (void)setImageTitleLabelWitdh:(CGFloat)width withHeight:(CGFloat)height
{
    self.imageTitle = [[UITextView alloc] initWithFrame:CGRectMake(0., _imageView.frame.size.height/2+5, width,height)];
    self.imageTitle.contentInset = UIEdgeInsetsMake(1,1,1,1);
    self.imageTitle.userInteractionEnabled = NO;
}

- (void)setImageTitleTextColor:(UIColor*)textColor withBackgroundColor:(UIColor*)bgColor
{
    self.imageTitle.textColor = textColor;
    self.imageTitle.backgroundColor = bgColor;
}

- (void)setTitle:(NSString*)title ;
{
    if ([self.contentView subviews]){
        for (UILabel *subview in [self.contentView subviews]) {
            [subview removeFromSuperview];
        }
    }
    [self.contentView addSubview:self.imageView];

    self.imageTitle.text = title;
    [self.contentView addSubview:self.imageTitle];
    
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
