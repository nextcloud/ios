//
//  AHKActionSheetViewController.m
//  AHKActionSheetExample
//
//  Created by Arkadiusz on 09-04-14.
//  Copyright (c) 2014 Arkadiusz Holko. All rights reserved.
//

#import "AHKActionSheetViewController.h"
#import "AHKActionSheet.h"

@interface AHKActionSheetViewController ()

@property (nonatomic) BOOL viewAlreadyAppear;
@property (nonatomic) UIInterfaceOrientation storeOrientation;

@end

@implementation AHKActionSheetViewController

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRotateDeviceChangeNotification:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
    _storeOrientation = [[UIApplication sharedApplication] statusBarOrientation];

    [self.view addSubview:self.actionSheet];
    self.actionSheet.frame = self.view.bounds;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    self.viewAlreadyAppear = YES;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];

    self.actionSheet.frame = self.view.bounds;
}

- (BOOL)shouldAutorotate
{
    // doesn't allow autorotation after the view did appear (rotation messes up a blurred background)
    return !self.viewAlreadyAppear;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 90000
- (NSUInteger)supportedInterfaceOrientations
#else
- (UIInterfaceOrientationMask)supportedInterfaceOrientations
#endif
{
    return UIInterfaceOrientationMaskAll;
}

-(void)didRotateDeviceChangeNotification:(NSNotification *)notification
{
    UIInterfaceOrientation currentOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    
    if (currentOrientation != _storeOrientation) {
        [self.actionSheet dismissAnimated:NO];
    }
    
    _storeOrientation = currentOrientation;
}

@end
