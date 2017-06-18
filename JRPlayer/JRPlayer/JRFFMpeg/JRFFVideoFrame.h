//
//  JRFFVideoFrame.h
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/7.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import "JRFFFrame.h"
#import "avformat.h"
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, JRYUVChannel) {
    JRYUVChannelLuma = 0,
    JRYUVChannelChromaB = 1,
    JRYUVChannelChromaR = 2,
    JRYUVChannelCount = 3,
};

typedef NS_ENUM(NSUInteger, JRVideoFrameRotateType) {
    JRVideoFrameRotateType0,
    JRVideoFrameRotateType90,
    JRVideoFrameRotateType180,
    JRVideoFrameRotateType270,
};


@interface JRFFVideoFrame : JRFFFrame

@property (assign, nonatomic) JRVideoFrameRotateType rotateType;

@end


@interface JRFFAVYUVVideoFrame : JRFFVideoFrame

{
    @public
    UInt8 *channel_pixels[JRYUVChannelCount];
}

@property (assign, nonatomic, readonly) int width;
@property (assign, nonatomic, readonly) int height;

+ (instancetype)videoFrame;
- (void)setFrameData:(AVFrame *)frame width:(int)width height:(int)height;

- (UIImage *)image;

@end


@interface JRFFCVYUVVideoFrame : JRFFVideoFrame

@property (assign, nonatomic, readonly) CVPixelBufferRef pixelBuffer;

- (instancetype)initWithAVPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end






