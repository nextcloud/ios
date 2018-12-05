//
//  ViewController.m
//
//  Copyright (c) 2015-2016 Evgeny Aleksandrov. License: MIT.

#import "ViewController.h"
#import <EARestrictedScrollView/EARestrictedScrollView.h>

@interface ViewController () {
    EARestrictedScrollView *restrictedScrollView;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view setBackgroundColor:[UIColor blackColor]];
    
    restrictedScrollView = [[EARestrictedScrollView alloc] initWithFrame:self.view.frame];
    restrictedScrollView.alwaysBounceHorizontal = YES;
    restrictedScrollView.alwaysBounceVertical = YES;
    [self.view addSubview:restrictedScrollView];
    
    UIImage *bgImage = [UIImage imageNamed:@"milky-way.jpg"];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:bgImage];
    [restrictedScrollView addSubview:imageView];
    [restrictedScrollView setContentSize:imageView.frame.size];
    
    [self addViewWithControlsAtFrame:CGRectMake(20.f, 50.f, self.view.frame.size.width, self.view.frame.size.height)];
    [self addViewWithControlsAtFrame:CGRectMake(50.f + self.view.frame.size.width, 50.f, self.view.frame.size.width * 1.5f, self.view.frame.size.height * 1.5f)];
}

- (void)addViewWithControlsAtFrame:(CGRect)viewFrame {
    UIView *restrictionArea = [[UIView alloc] initWithFrame:viewFrame];
    restrictionArea.layer.cornerRadius = 10.f;
    restrictionArea.layer.borderColor = [UIColor whiteColor].CGColor;
    restrictionArea.layer.borderWidth = 2.f;
    
    UISwitch *areaSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
    [areaSwitch setFrame:CGRectMake((restrictionArea.frame.size.width - areaSwitch.frame.size.width)/2, (restrictionArea.frame.size.height - areaSwitch.frame.size.height)/2, 0, 0)];
    [areaSwitch addTarget:self action:@selector(changeSwitch:) forControlEvents:UIControlEventValueChanged];
    [restrictionArea addSubview:areaSwitch];
    
    [restrictedScrollView addSubview:restrictionArea];
}

- (void)changeSwitch:(id)sender {
    UISwitch *areaSwitch = (UISwitch *)sender;
    
    if([areaSwitch isOn]){
        [restrictedScrollView setRestrictionArea:areaSwitch.superview.frame];
    } else {
        [restrictedScrollView setRestrictionArea:CGRectZero];
    }
}

@end
