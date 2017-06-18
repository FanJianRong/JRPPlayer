//
//  JRFFMetadata.h
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/17.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JRFFTools.h"

@interface JRFFMetadata : NSObject

+ (instancetype)metadataWithAVDictionary:(AVDictionary *)avDictionary;

@property (strong, nonatomic) NSDictionary *metadata;

@property (copy, nonatomic) NSString *lenguage;
@property (assign, nonatomic) long long BPS;
@property (copy, nonatomic) NSString *duration;
@property (assign, nonatomic) long long number_of_bytes;
@property (assign, nonatomic) long long number_of_frames;

@end
