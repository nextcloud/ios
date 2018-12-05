//
//  Tests.m
//
//  Copyright (c) 2015-2016 Evgeny Aleksandrov. License: MIT.

#import <EARestrictedScrollView/EARestrictedScrollView.h>

SpecBegin(Main)

__block UIWindow *window;
__block EARestrictedScrollView *restrictedScrollView;

beforeEach(^{
    window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    UIViewController *vc = [[UIViewController alloc] init];
    window.rootViewController = vc;
    restrictedScrollView = [[EARestrictedScrollView alloc] initWithFrame:vc.view.bounds];
    [vc.view addSubview:restrictedScrollView];
    [window makeKeyAndVisible];
    
    UIImage *bgImage = [UIImage imageNamed:@"milky-way.jpg"];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:bgImage];
    [restrictedScrollView addSubview:imageView];
    [restrictedScrollView setContentSize:imageView.frame.size];
    
    expect(vc.view).willNot.beNil();
    expect(restrictedScrollView).willNot.beNil();
});


it(@"looks normal on init", ^{
    expect(window).to.haveValidSnapshotNamed(@"InitState");
});

it(@"have restriction area = view.frame", ^{
    CGRect restrRect = CGRectMake(300.f, 300.f, restrictedScrollView.bounds.size.width, restrictedScrollView.bounds.size.height);
    
    [restrictedScrollView setRestrictionArea:restrRect];
    
    expect(restrictedScrollView.contentOffset.x).to.equal(restrRect.origin.x);
    expect(restrictedScrollView.contentOffset.y).to.equal(restrRect.origin.y);
    
    expect(window).to.haveValidSnapshotNamed(@"RestrictionAreaEqualsSelf");
    
    [restrictedScrollView setRestrictionArea:CGRectZero];
    
    expect(restrictedScrollView.contentOffset.x).to.equal(restrRect.origin.x);
    expect(restrictedScrollView.contentOffset.y).to.equal(restrRect.origin.y);
});

it(@"have restriction area bigger than view.frame", ^{
    CGRect restrRect = CGRectMake(400.f, 400.f, restrictedScrollView.bounds.size.width * 1.5, restrictedScrollView.bounds.size.height * 1.5);
    
    [restrictedScrollView setRestrictionArea:restrRect];
    
    expect(restrictedScrollView.contentOffset.x).to.equal(restrRect.origin.x);
    expect(restrictedScrollView.contentOffset.y).to.equal(restrRect.origin.y);
    
    expect(window).to.haveValidSnapshotNamed(@"BiggerRestrictionFrameInit");
});


it(@"have restriction area bigger than view.frame + offset", ^{
    CGRect restrRect = CGRectMake(400.f, 400.f, restrictedScrollView.bounds.size.width * 1.5, restrictedScrollView.bounds.size.height * 1.5);
    
    [restrictedScrollView setRestrictionArea:restrRect];
    
    CGPoint newOffset = CGPointMake(restrRect.origin.x + 50, restrRect.origin.y + 50);
    
    [restrictedScrollView setContentOffset:newOffset animated:NO];
    
    expect(restrictedScrollView.contentOffset.x).to.equal(newOffset.x);
    expect(restrictedScrollView.contentOffset.y).to.equal(newOffset.y);
    
    [restrictedScrollView setRestrictionArea:CGRectZero];
    
    expect(restrictedScrollView.contentOffset.x).to.equal(newOffset.x);
    expect(restrictedScrollView.contentOffset.y).to.equal(newOffset.y);
});

SpecEnd
