//
//  JRFFFormatContext.h
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/17.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JRFFVideoFrame.h"
#import "JRFFTrack.h"

@class JRFFFormatContext;

@protocol JRFFFormatContextDelegate <NSObject>

- (BOOL)formatContextNeedInterrupt:(JRFFFormatContext *)formatContext;

@end

@interface JRFFFormatContext : NSObject

{
@public
    AVFormatContext * _format_context;
    AVCodecContext * _video_codec_context;
    AVCodecContext * _audio_codec_context;
}

+ (instancetype)formatContextWithContentURL:(NSURL *)contentURL delegae:(id<JRFFFormatContextDelegate>)delegate;

@property (weak, nonatomic) id<JRFFFormatContextDelegate> delegate;

@property (copy, nonatomic, readonly) NSError *error;

@property (copy, nonatomic, readonly) NSDictionary *metadata;
@property (assign, nonatomic, readonly) NSTimeInterval bitrate;
@property (assign, nonatomic, readonly) NSTimeInterval duration;

@property (assign, nonatomic, readonly) BOOL videoEnable;
@property (assign, nonatomic, readonly) BOOL audioEnable;

@property (strong, nonatomic, readonly) JRFFTrack *videoTrack;
@property (strong, nonatomic, readonly) JRFFTrack *audioTrack;

@property (strong, nonatomic, readonly) NSArray <JRFFTrack *> *videoTracks;
@property (strong, nonatomic, readonly) NSArray <JRFFTrack *> *audioTracks;

@property (assign, nonatomic, readonly) NSTimeInterval videoTimebase;
@property (assign, nonatomic, readonly) NSTimeInterval videoFPS;
@property (assign, nonatomic, readonly) CGSize videoPresentationSize;
@property (assign, nonatomic, readonly) CGFloat videoAspect;
@property (assign, nonatomic, readonly) JRVideoFrameRotateType videoFrameRotateType;

@property (assign, nonatomic, readonly) NSTimeInterval audioTimebase;

@property (strong, nonatomic) NSDictionary *formatContextOptions;
@property (strong, nonatomic) NSDictionary *codecContextOptions;

- (void)setupSync;
- (void)destroy;

- (BOOL)seekEnable;
- (void)seekFileWithFFTimebase:(NSTimeInterval)time;

- (int)readFrame:(AVPacket *)packet;

- (BOOL)containAudioTrack:(int)audioTrackIndex;
- (NSError *)selectAudioTrackIndex:(int)audioTrakIndex;


@end
