//
//  ViewController.m
//  KTVHTTPCacheDemo
//
//  Created by Single on 2017/8/10.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "ViewController.h"
#import "MediaViewController.h"
#import "MediaItem.h"
#import "MediaCell.h"
#import <KTVHTTPCache/KTVHTTPCache.h>

@interface ViewController () <UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView * tableView;
@property (nonatomic, strong) NSArray <MediaItem *> * medaiItems;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self setupHTTPCache];
    });
    [self reloadData];
}

- (void)setupHTTPCache
{
    [KTVHTTPCache logSetConsoleLogEnable:YES];
    NSError * error;
    [KTVHTTPCache proxyStart:&error];
    if (error) {
        NSLog(@"Proxy Start Failure, %@", error);
    } else {
        NSLog(@"Proxy Start Success");
    }
    [KTVHTTPCache tokenSetURLFilter:^NSURL * (NSURL * URL) {
        NSLog(@"URL Filter reviced URL : %@", URL);
        return URL;
    }];
    [KTVHTTPCache downloadSetUnsupportContentTypeFilter:^BOOL(NSURL * URL, NSString * contentType) {
        NSLog(@"Unsupport Content-Type Filter reviced URL : %@, %@", URL, contentType);
        return NO;
    }];
}

- (void)reloadData
{
    MediaItem * item1 = [[MediaItem alloc] initWithTitle:@"萧亚轩 - 冲动"
                                               URLString:@"http://aliuwmp3.changba.com/userdata/video/45F6BD5E445E4C029C33DC5901307461.mp4"];
    MediaItem * item2 = [[MediaItem alloc] initWithTitle:@"张惠妹 - 你是爱我的"
                                               URLString:@"http://aliuwmp3.changba.com/userdata/video/3B1DDE764577E0529C33DC5901307461.mp4"];
    MediaItem * item3 = [[MediaItem alloc] initWithTitle:@"hush! - 都是你害的"
                                               URLString:@"http://qiniuuwmp3.changba.com/941946870.mp4"];
    MediaItem * item4 = [[MediaItem alloc] initWithTitle:@"张学友 - 我真的受伤了"
                                               URLString:@"http://lzaiuw.changba.com/userdata/video/940071102.mp4"];
    self.medaiItems = @[item1, item2, item3, item4];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.medaiItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    MediaCell * cell = [tableView dequeueReusableCellWithIdentifier:@"MediaCell"];
    [cell configureWithTitle:[self.medaiItems objectAtIndex:indexPath.row].title];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    MediaItem * mediaItem = [self.medaiItems objectAtIndex:indexPath.row];
    NSString * URLString = [mediaItem.URLString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];

    NSString * proxyURLString = [KTVHTTPCache proxyURLStringWithOriginalURLString:URLString];
    
    MediaViewController * viewController = [[MediaViewController alloc] initWithURLString:proxyURLString];
    [self presentViewController:viewController animated:YES completion:nil];
}


@end
