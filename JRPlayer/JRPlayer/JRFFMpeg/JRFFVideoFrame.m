//
//  JRFFVideoFrame.m
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/7.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import "JRFFVideoFrame.h"
#import "JRYUVTools.h"
#import "JRImageTools.h"

@implementation JRFFVideoFrame

- (JRFFFrameType)type
{
    return JRFFFrameTypeAudio;
}

@end

@interface JRFFAVYUVVideoFrame ()

{
    enum AVPixelFormat pixelFormat;
    
    size_t channel_pixels_buffer_size[JRYUVChannelCount];
    int channel_lenghts[JRYUVChannelCount];
    int channel_linesize[JRYUVChannelCount];
}

@property (strong, nonatomic) NSLock *lock;

@end

@implementation JRFFAVYUVVideoFrame

- (JRFFFrameType)type
{
    return JRFFFrameTypeAVYUVVideo;
}

+ (instancetype)videoFrame
{
    return [[self alloc] init];
}

- (instancetype)init
{
    if (self = [super init]) {
        channel_lenghts[JRYUVChannelLuma] = 0;
        channel_lenghts[JRYUVChannelChromaB] = 0;
        channel_lenghts[JRYUVChannelChromaR] = 0;
        channel_pixels_buffer_size[JRYUVChannelLuma] = 0;
        channel_pixels_buffer_size[JRYUVChannelChromaB] = 0;
        channel_pixels_buffer_size[JRYUVChannelChromaR] = 0;
        channel_linesize[JRYUVChannelLuma] = 0;
        channel_linesize[JRYUVChannelChromaB] = 0;
        channel_linesize[JRYUVChannelChromaR] = 0;
        channel_pixels[JRYUVChannelLuma] = NULL;
        channel_pixels[JRYUVChannelChromaB] = NULL;
        channel_pixels[JRYUVChannelChromaR] = NULL;
        self.lock = [[NSLock alloc] init];
    }
    return self;
}

- (void)setFrameData:(AVFrame *)frame width:(int)width height:(int)height
{
    pixelFormat = frame->format;
    self->_width = width;
    self->_height = height;
    
    int linesize_y = frame->linesize[JRYUVChannelLuma];
    int linesize_u = frame->linesize[JRYUVChannelChromaB];
    int linesize_v = frame->linesize[JRYUVChannelChromaR];
    
    channel_linesize[JRYUVChannelLuma] = linesize_y;
    channel_linesize[JRYUVChannelChromaB] = linesize_u;
    channel_linesize[JRYUVChannelChromaR] = linesize_v;
    
    UInt8 * buffer_y = channel_pixels[JRYUVChannelLuma];
    UInt8 * buffer_u = channel_pixels[JRYUVChannelChromaB];
    UInt8 * buffer_v = channel_pixels[JRYUVChannelChromaR];
    
    size_t buffer_size_y = channel_pixels_buffer_size[JRYUVChannelLuma];
    size_t buffer_size_u = channel_pixels_buffer_size[JRYUVChannelChromaB];
    size_t buffer_size_v = channel_pixels_buffer_size[JRYUVChannelChromaR];
    
    int need_size_y = JRYUVChannelFilterNeedSize(linesize_y, width, height, 1);
    channel_lenghts[JRYUVChannelLuma] = need_size_y;
    if (buffer_size_y < need_size_y) {
        if (buffer_size_y > 0 && buffer_y != NULL) {
            free(buffer_y);
        }
        channel_pixels_buffer_size[JRYUVChannelLuma] = need_size_y;
        channel_pixels[JRYUVChannelLuma] = malloc(need_size_y);
    }
    int need_size_u = JRYUVChannelFilterNeedSize(linesize_u, width, height, 1);
    channel_lenghts[JRYUVChannelChromaB] = need_size_u;
    if (buffer_size_u < need_size_u) {
        if (buffer_size_u > 0 && buffer_u != NULL) {
            free(buffer_u);
        }
        channel_pixels_buffer_size[JRYUVChannelChromaB] = need_size_u;
        channel_pixels[JRYUVChannelChromaB] = malloc(need_size_u);
    }
    int need_size_v = JRYUVChannelFilterNeedSize(linesize_v, width, height, 1);
    channel_lenghts[JRYUVChannelChromaR] = need_size_v;
    if (buffer_size_v < need_size_v) {
        if (buffer_size_v > 0 && buffer_v != NULL) {
            free(buffer_v);
        }
        channel_pixels_buffer_size[JRYUVChannelChromaR] = need_size_v;
        channel_pixels[JRYUVChannelChromaR] = malloc(need_size_v);
    }
    JRYUVChannelFilter(frame->data[JRYUVChannelLuma],
                       linesize_y,
                       width,
                       height,
                       channel_pixels[JRYUVChannelLuma],
                       channel_pixels_buffer_size[JRYUVChannelLuma],
                       1);
    JRYUVChannelFilter(frame->data[JRYUVChannelChromaB],
                       linesize_u,
                       width,
                       height,
                       channel_pixels[JRYUVChannelChromaB],
                       channel_pixels_buffer_size[JRYUVChannelChromaB],
                       1);
    JRYUVChannelFilter(frame->data[JRYUVChannelChromaR],
                       linesize_v,
                       width,
                       height,
                       channel_pixels[JRYUVChannelChromaR],
                       channel_pixels_buffer_size[JRYUVChannelChromaR],
                       1);
}



- (void)stopPlaying
{
    [self.lock lock];
    [super stopPlaying];
    [self.lock unlock];
}

- (UIImage *)image
{
    [self.lock lock];
    UIImage *image = JRYUVConvertToImage(channel_pixels, channel_linesize, self.width, self.height, pixelFormat);
    [self.lock unlock];
    return image;
}

- (int)size
{
    return channel_lenghts[JRYUVChannelLuma] + channel_lenghts[JRYUVChannelChromaB] + channel_lenghts[JRYUVChannelChromaR];
}

- (void)dealloc
{
    if (channel_pixels[JRYUVChannelLuma] != NULL && channel_pixels_buffer_size[JRYUVChannelLuma] > 0) {
        free(channel_pixels[JRYUVChannelLuma]);
    }
    if (channel_pixels[JRYUVChannelChromaB] != NULL && channel_pixels_buffer_size[JRYUVChannelChromaB] > 0) {
        free(channel_pixels[JRYUVChannelChromaB]);
    }
    if (channel_pixels[JRYUVChannelChromaR] != NULL && channel_pixels_buffer_size[JRYUVChannelChromaR] > 0) {
        free(channel_pixels[JRYUVChannelChromaR]);
    }
}

@end


@implementation JRFFCVYUVVideoFrame

- (JRFFFrameType)type
{
    return JRFFFrameTypeCVYUVVideo;
}

- (instancetype)initWithAVPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    if (self = [super init]) {
        self->_pixelBuffer = pixelBuffer;
    }
    return self;
}

- (void)dealloc
{
    if (self->_pixelBuffer) {
        CVPixelBufferRelease(self->_pixelBuffer);
        self->_pixelBuffer = NULL;
    }
}

@end
