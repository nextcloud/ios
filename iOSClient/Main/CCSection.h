//
//  CCSection.h
//  Nextcloud
//
//  Created by Marino Faggiana on 04/02/16.
//  Copyright (c) 2016 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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
@property (nonatomic, strong) NSMutableArray *allOcId;
@property (nonatomic, strong) NSMutableArray *sections;
@property (nonatomic, strong) NSMutableDictionary *sectionArrayRow;
@property (nonatomic, strong) NSMutableDictionary *ocIdIndexPath;
@property (nonatomic, strong) NSMutableArray *metadatas;

@property NSInteger video;
@property NSInteger image;

@property NSInteger directories;
@property NSInteger files;
@property double totalSize;

- (id)copyWithZone:(NSZone *)zone;

@end

@interface CCSectionMetadata : NSObject

+ (CCSectionDataSourceMetadata *)creataDataSourseSectionMetadata:(NSArray *)arrayMetadatas listProgressMetadata:(NSMutableDictionary *)listProgressMetadata groupBy:(NSString *)groupBy filterTypeFileImage:(BOOL)filterTypeFileImage filterTypeFileVideo:(BOOL)filterTypeFileVideo filterLivePhoto:(BOOL)filterLivePhoto sort:(NSString *)sort ascending:(BOOL)ascending directoryOnTop:(BOOL)directoryOnTop account:(NSString *)account;

+ (void)removeAllObjectsSectionDataSource:(CCSectionDataSourceMetadata *)sectionDataSource;

@end

// -----------------------------------

@interface CCSectionDataSourceActivity : NSObject

@property (nonatomic, strong) NSMutableArray *sections;
@property (nonatomic, strong) NSMutableDictionary *sectionArrayRow;

@end

@interface CCSectionActivity : NSObject

+ (CCSectionDataSourceActivity *)creataDataSourseSectionActivity:(NSArray *)records account:(NSString *)account;

@end
