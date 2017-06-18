//
//  JRFFMetadata.m
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/17.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import "JRFFMetadata.h"

@implementation JRFFMetadata

+ (instancetype)metadataWithAVDictionary:(AVDictionary *)avDictionary
{
    return [[self alloc] initWithAVDictionary:avDictionary];
}

- (instancetype)initWithAVDictionary:(AVDictionary *)avDictionary
{
    if (self = [super init]) {
        NSDictionary *dic = JRFFFoundationBrigeOfAVDictionary(avDictionary);
        
        self.metadata = dic;
        self.lenguage = [dic objectForKey:@"language"];
        self.BPS = [[dic objectForKey:@"BPS"] longLongValue];
        self.duration = [dic objectForKey:@"DURATION"];
        self.number_of_bytes = [[dic objectForKey:@"NUMBER_OF_BYTES"] longLongValue];
        self.number_of_frames = [[dic objectForKey:@"NUMBER_OF_FRAMES"] longLongValue];
    }
    return self;
}

@end
