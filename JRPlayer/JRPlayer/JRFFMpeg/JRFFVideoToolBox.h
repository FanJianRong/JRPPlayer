//
//  JRFFVideoToolBox.h
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/8.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "avformat.h"
#import <VideoToolbox/VideoToolbox.h>

@interface JRFFVideoToolBox : NSObject

+ (instancetype)videoToolBoxWithCodecContext:(AVCodecContext *)codecContext;

- (BOOL)sendPacket:(AVPacket)packet needFlush:(BOOL *)needFlush;
- (CVImageBufferRef)imageBuffer;

- (BOOL)trySetupVTSession;
- (void)flush;


@end
