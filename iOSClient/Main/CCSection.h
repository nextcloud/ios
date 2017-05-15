//
//  CCSection.h
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 04/02/16.
//  Copyright (c) 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import <Foundation/Foundation.h>

@interface CCSectionDataSourceMetadata : NSObject
    
@property (nonatomic, strong) NSMutableDictionary *allRecordsDataSource;
@property (nonatomic, strong) NSMutableArray *allFileID;
@property (nonatomic, strong) NSMutableArray *sections;
@property (nonatomic, strong) NSMutableDictionary *sectionArrayRow;
@property (nonatomic, strong) NSMutableDictionary *fileIDIndexPath;

@property NSInteger video;
@property NSInteger image;

@property NSInteger directories;
@property NSInteger files;
@property double totalSize;

@end

@interface CCSectionMetadata : NSObject

+ (CCSectionDataSourceMetadata *)creataDataSourseSectionMetadata:(NSArray *)records listProgressMetadata:(NSMutableDictionary *)listProgressMetadata groupByField:(NSString *)groupByField replaceDateToExifDate:(BOOL)replaceDateToExifDate activeAccount:(NSString *)activeAccount;

+ (void)removeAllObjectsSectionDataSource:(CCSectionDataSourceMetadata *)sectionDataSource;

@end

// -----------------------------------

@interface CCSectionDataSourceActivity : NSObject

@property (nonatomic, strong) NSMutableArray *sections;
@property (nonatomic, strong) NSMutableDictionary *sectionArrayRow;

@end

@interface CCSectionActivity : NSObject

+ (CCSectionDataSourceActivity *)creataDataSourseSectionActivity:(NSArray *)records activeAccount:(NSString *)activeAccount;

@end
