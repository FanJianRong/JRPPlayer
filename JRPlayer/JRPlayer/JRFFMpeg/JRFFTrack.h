//
//  JRFFTrack.h
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/17.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JRFFMetadata.h"

typedef NS_ENUM(NSUInteger, JRFFTrackType) {
    JRFFTrackTypeVideo,
    JRFFTrackTypeAudio,
    JRFFTrackTypeSubtitle,
};

@interface JRFFTrack : NSObject

@property (assign, nonatomic) int index;
@property (assign, nonatomic) JRFFTrackType type;
@property (strong, nonatomic) JRFFMetadata *metadata;

@end
