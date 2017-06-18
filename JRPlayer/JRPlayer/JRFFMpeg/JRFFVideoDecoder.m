//
//  JRFFVideoDecoder.m
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/7.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import "JRFFVideoDecoder.h"
#import "JRFFFrameQueue.h"
#import "JRFFPacketQueue.h"
#import "JRFFFramePool.h"
#import <TargetConditionals.h>
#import "JRFFVideoToolBox.h"
#import "JRFFTools.h"

static AVPacket flush_packet;

@interface JRFFVideoDecoder ()

{
    AVCodecContext *_codec_context;
    AVFrame * _temp_frame;
}

@property (assign, nonatomic) NSInteger preferredFramesPerSecond;

@property (assign, nonatomic) BOOL canceled;

@property (strong, nonatomic) JRFFFrameQueue *frameQueue;
@property (strong, nonatomic) JRFFPacketQueue *packetQueue;

@property (strong, nonatomic) JRFFFramePool *framePool;

#if TARGET_OS_IOS
@property (strong, nonatomic) JRFFVideoToolBox *videoToolBox;
#endif

@end

@implementation JRFFVideoDecoder

+ (instancetype)decoderWithCodecContext:(AVCodecContext *)codec_context
                               timebase:(NSTimeInterval)timebase
                                    fps:(NSTimeInterval)fps
                      codecContextAsync:(BOOL)codecContextAsync
                     videoToolBoxEnable:(BOOL)videoToolBoxEnable
                             retateType:(JRVideoFrameRotateType) rotateType
                               delegate:(id<JRFFVideoDecoderDelegate>)delegate
{
    return [[self alloc] initWithCodecContext:codec_context timebase:timebase fps:fps codecContextAsync:codecContextAsync videoToolBoxEnable:videoToolBoxEnable retateType:rotateType delegate:delegate];
}

- (instancetype)initWithCodecContext:(AVCodecContext *)codec_context
                            timebase:(NSTimeInterval)timebase
                                 fps:(NSTimeInterval)fps
                   codecContextAsync:(BOOL)codecContextAsync
                  videoToolBoxEnable:(BOOL)videoToolBoxEnable
                          retateType:(JRVideoFrameRotateType) rotateType
                            delegate:(id<JRFFVideoDecoderDelegate>)delegate
{
    if (self = [super init]) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            av_init_packet(&flush_packet);
            flush_packet.data = (uint8_t *)&flush_packet;
            flush_packet.duration = 0;
        });
        self.delegate = delegate;
        self->_codec_context = codec_context;
        self->_timebase = timebase;
        self->_fps = fps;
        self->_codecContextAsync = codecContextAsync;
        self->_videoToolBoxEnable = videoToolBoxEnable;
        self->_rotateType = rotateType;
        
        
    }
    return self;
}

- (void)setupCodecContext
{
    self.preferredFramesPerSecond = 60;
    self->_temp_frame = av_frame_alloc();
    self.packetQueue = [JRFFPacketQueue packetQueueWithTimebase:self.timebase];
    self.videoToolBoxMaxDecodeFrameCount = 20;
    self.codecContextMaxDacodeFrameCount = 3;
    
#if TARGET_OS_IOS
    if (self.videoToolBoxEnable && _codec_context->codec_id == AV_CODEC_ID_H264) {
        self.videoToolBox = [JRFFVideoToolBox videoToolBoxWithCodecContext:_codec_context];
        if ([self.videoToolBox trySetupVTSession]) {
            self->_videoToolBoxDidOpen = YES;
        } else {
            [self.videoToolBox flush];
            self.videoToolBox = nil;
        }
    }
#endif
    if (self.videoToolBoxDidOpen) {
        self.frameQueue = [JRFFFrameQueue frameQueue];
        self.frameQueue.minFrameCountForGet = 4;
        self->_decodeAsync = YES;
    } else if (self.codecContextAsync) {
        self.frameQueue = [JRFFFrameQueue frameQueue];
        self.framePool = [JRFFFramePool videoPool];
        self->_decodeAsync = YES;
    } else {
        self.framePool = [JRFFFramePool videoPool];
        self->_decodeSync = YES;
        self->_decodeOnMainThread = YES;
    }
}

- (JRFFVideoFrame *)getFrameAsync
{
    if (self.videoToolBoxDidOpen || self.codecContextAsync) {
        return  [self.frameQueue getFrameAsync];
    } else {
        return [self codecContextDecodeSync];
    }
}

- (JRFFVideoFrame *)getFrameAsyncPosition:(NSTimeInterval)position
{
    if (self.videoToolBoxDidOpen || self.codecContextAsync) {
        NSMutableArray <JRFFFrame *> *discardFrames = nil;
        JRFFVideoFrame *videoFrame = [self.frameQueue getFrameAsyncPosition:position discardFrames:&discardFrames];
        for (JRFFVideoFrame *obj in discardFrames) {
            [obj cancel];
        }
        return videoFrame;
    } else {
        return [self codecContextDecodeSync];
    }
}

- (void)discardFrameBeforPosition:(NSTimeInterval)position
{
    if (self.videoToolBoxDidOpen || self.codecContextAsync) {
        NSMutableArray <JRFFFrame *> * discardFrames = [self.frameQueue discardFrameBeforPosition:position];
        for (JRFFVideoFrame *obj in discardFrames) {
            [obj cancel];
        }
    }
}

- (void)putPacket:(AVPacket)packet
{
    NSTimeInterval duration = 0;
    if (packet.duration <= 0 && packet.size > 0 && packet.data != flush_packet.data) {
        duration = 1.0 / self.fps;
    }
    [self.packetQueue putPacket:packet duration:duration];
}

- (void)flush
{
    [self.packetQueue flush];
    [self.frameQueue flush];
    [self.framePool flush];
    [self putPacket:flush_packet];
}

- (void)destroy
{
    self.canceled = YES;
    [self.frameQueue flush];
    [self.framePool flush];
    [self.packetQueue flush];
}

- (void)startDecodeThread
{
    if (self.videoToolBoxDidOpen) {
        [self videoToolBoxDecodeAsyncThread];
    } else {
        [self codecContextDecodecAsyncThread];
    }
}

- (void)codecContextDecodecAsyncThread
{
    while (YES) {
        if (!self.codecContextAsync) {
            break;
        }
        if (self.canceled || self.error) {
            break;
        }
        if (self.endOfFile && self.packetQueue.count <= 0) {
            NSLog(@"decode video finished");
            break;
        }
        if (self.pause) {
            NSLog(@"decode video thread pause sleep");
            [NSThread sleepForTimeInterval:0.03];
            continue;
        }
        AVPacket packet = [self.packetQueue getPacketSync];
        if (packet.data == flush_packet.data) {
            NSLog(@"video codec flush");
            avcodec_flush_buffers(_codec_context);
            [self.frameQueue flush];
            continue;
        }
        if (packet.stream_index < 0 || packet.data == NULL) {
            continue;
        }
        JRFFVideoFrame *videoFrame = nil;
        int result = avcodec_send_packet(_codec_context, &packet);
        if (result < 0) {
            if (result != AVERROR(EAGAIN)  && result != AVERROR_EOF) {
                self->_error = JRFFCheckError(result);
                [self delegateErrorCallback];
            }
        } else {
            while (result >= 0) {
                result = avcodec_receive_frame(_codec_context, _temp_frame);
                if (result < 0) {
                    if (result != AVERROR(EAGAIN) && result != AVERROR_EOF) {
                        self->_error = JRFFCheckError(result);
                        [self delegateErrorCallback];
                    }
                } else {
                    videoFrame = [self videoFrameFromTempFrame:packet.size];
                    if (videoFrame) {
                        [self.frameQueue putSortFrame:videoFrame];
                    }
                }
            }
        }
        av_packet_unref(&packet);
    }
}

#pragma mark - VideoToolBox

- (void)videoToolBoxDecodeAsyncThread
{
#if TARGET_OS_IOS
    while (YES) {
        if (!self.videoToolBoxDidOpen) {
            break;
        }
        if (self.canceled || self.error) {
            NSLog(@"decode video thread quit");
            break;
        }
        if (self.endOfFile && self.packetQueue.count <= 0) {
            NSLog(@"decode video finished");
            break;
        }
        if (self.pause) {
            NSLog(@"decode video thread pause sleep");
            [NSThread sleepForTimeInterval:0.01];
            continue;
        }
        if (self.frameQueue.count >= self.videoToolBoxMaxDecodeFrameCount) {
            NSLog(@"decode video thread sleep");
            [NSThread sleepForTimeInterval:0.03];
            continue;
        }
        AVPacket packet = [self.packetQueue getPacketSync];
        if (packet.data == flush_packet.data) {
            NSLog(@"video codec flush");
            [self.frameQueue flush];
            [self.videoToolBox flush];
            continue;
        }
        if (packet.stream_index < 0 || packet.data == NULL) {
            continue;
        }
        JRFFVideoFrame *videoFrame = nil;
        BOOL vtbEnable = [self.videoToolBox trySetupVTSession];
        if (vtbEnable) {
            BOOL needFlush = NO;
            BOOL result = [self.videoToolBox sendPacket:packet needFlush:&needFlush];
            if (result) {
                videoFrame = [self videoFrameFromToolBox:packet];
            }
        }
        
    }
}

- (JRFFVideoFrame *)videoFrameFromToolBox:(AVPacket)packet
{
    CVImageBufferRef imageBuffer = [self.videoToolBox imageBuffer];
    if (imageBuffer == NULL) {
        return nil;
    }
    JRFFCVYUVVideoFrame *videoFrame = [[JRFFCVYUVVideoFrame alloc] initWithAVPixelBuffer:imageBuffer];
    videoFrame.rotateType = self.rotateType;
    
    if (packet.pts != AV_NOPTS_VALUE) {
        videoFrame.position = packet.pts * self.timebase;
    } else {
        videoFrame.position = packet.dts;
    }
    videoFrame.packetSize = packet.size;
    
    const int64_t frame_duration = packet.duration;
    
    if (frame_duration) {
        videoFrame.duration = frame_duration * self.timebase;
    } else {
        videoFrame.duration = 1.0 / self.fps;
    }
    return videoFrame;
#endif
}

#pragma mark - private

- (JRFFVideoFrame *)codecContextDecodeSync
{
    if (self.canceled || self.error) {
        return nil;
    }
    if (self.pause) {
        return nil;
    }
    if (self.endOfFile && self.packetQueue.count <= 0) {
        return nil;
    }
    AVPacket packet = [self.packetQueue getPacketAsync];
    if (packet.data == flush_packet.data) {
        avcodec_flush_buffers(_codec_context);
        return nil;
    }
    if (packet.stream_index < 0 || packet.data == NULL) {
        return nil;
    }
    JRFFVideoFrame *videoFrame = nil;
    int result = avcodec_send_packet(_codec_context, &packet);
    if (result < 0) {
        if (result != AVERROR(EAGAIN) && result != AVERROR_EOF) {
            self->_error = JRFFCheckError(result);
            [self delegateErrorCallback];
        }
    } else {
        while (result >= 0) {
            result = avcodec_receive_frame(_codec_context, _temp_frame);
            if (result < 0) {
                if (result != AVERROR(EAGAIN) && result != AVERROR_EOF) {
                    self->_error = JRFFCheckError(result);
                    [self delegateErrorCallback];
                }
            } else {
                videoFrame = [self videoFrameFromTempFrame:packet.size];
            }
        }
    }
    av_packet_unref(&packet);
    return videoFrame;
}

- (JRFFAVYUVVideoFrame *)videoFrameFromTempFrame:(int)packetSize
{
    if (!_temp_frame->data[0] || _temp_frame->data[1] || _temp_frame->data[2]) {
        return nil;
    }
    JRFFAVYUVVideoFrame *videoFrame = [self.framePool getUnuseFrame];
    videoFrame.rotateType = self.rotateType;
    
    [videoFrame setFrameData:_temp_frame width:_codec_context->width height:_codec_context->height];
    videoFrame.position = av_frame_get_best_effort_timestamp(_temp_frame) * self.timebase;
    videoFrame.packetSize = packetSize;
    
    const int64_t frame_duration = av_frame_get_pkt_duration(_temp_frame);
    if (frame_duration) {
        videoFrame.duration = frame_duration * self.timebase;
        videoFrame.duration += _temp_frame->repeat_pict * self.timebase * 0.5;
    } else {
        videoFrame.duration = 1.0 / self.fps;
    }
    return videoFrame;
}

- (void)delegateErrorCallback
{
    if (self.error) {
        [self.delegate videoDecoder:self didError:self.error];
    }
}

#pragma mark - setter && getter

- (void)setPreferredFramesPerSecond:(NSInteger)preferredFramesPerSecond
{
    if (_preferredFramesPerSecond != preferredFramesPerSecond) {
        _preferredFramesPerSecond = preferredFramesPerSecond;
        [self.delegate videoDecoder:self didChangePreferredFramesPerSecond:_preferredFramesPerSecond];
    }
}

- (int)size
{
    if (self.videoToolBoxDidOpen || self.codecContextAsync) {
        return self.packetQueue.size + self.frameQueue.packetSize;
    } else {
        return self.packetQueue.size;
    }
}

- (BOOL)empty
{
    if (self.videoToolBoxDidOpen || self.codecContextAsync) {
        return self.packetQueue.count <= 0 && self.frameQueue.count <= 0;
    } else {
        return self.packetQueue.count <= 0;
    }
}

- (NSTimeInterval)duration
{
    if (self.videoToolBoxDidOpen || self.codecContextAsync) {
        return self.packetQueue.duration + self.frameQueue.duration;
    } else {
        return self.packetQueue.duration;
    }
}

- (void)dealloc
{
    if (_temp_frame) {
        av_free(_temp_frame);
        _temp_frame = NULL;
    }
    NSLog(@"JRFFVideoDecoder release");
}


@end
