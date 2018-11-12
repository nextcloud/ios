//
//  CacheViewController.m
//  KTVHTTPCacheDemo
//
//  Created by Single on 2017/8/13.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "CacheViewController.h"
#import <KTVHTTPCache/KTVHTTPCache.h>
#import "CacheItemZoneCell.h"
#import "CacheItemView.h"

@interface CacheViewController () <UITableViewDelegate, UITableViewDataSource, CacheItemViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView * tableView;
@property (nonatomic, strong) NSArray <KTVHCDataCacheItem *> * cacheItems;

@end

@implementation CacheViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self reloadData];
}

- (void)reloadData
{
    self.cacheItems = [KTVHTTPCache cacheAllCacheItems];
    [self.tableView reloadData];
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.cacheItems.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.cacheItems objectAtIndex:section].zones.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    KTVHCDataCacheItemZone * zone = [[self.cacheItems objectAtIndex:indexPath.section].zones objectAtIndex:indexPath.row];

    CacheItemZoneCell * cell = [tableView dequeueReusableCellWithIdentifier:@"CacheItemZoneCell"];
    [cell configureWithOffset:zone.offset length:zone.length];
    
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    KTVHCDataCacheItem * item = [self.cacheItems objectAtIndex:section];
    CacheItemView * view = [[CacheItemView alloc] initWithURLString:item.URL.absoluteString
                                                        totalLength:item.totalLength
                                                        cacheLength:item.cacheLength];
    view.delegate = self;
    return view;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 120;
}

#pragma mark - CacheItemViewDelegate

- (void)cacheItemView:(CacheItemView *)view deleteButtonDidClick:(NSString *)URLString
{
    [KTVHTTPCache cacheDeleteCacheWithURLString:URLString];
    [self reloadData];
}

- (IBAction)deleteAllCache:(UIButton *)sender
{
    [KTVHTTPCache cacheDeleteAllCaches];
    [self reloadData];
}

@end
