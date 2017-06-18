//
//  JRFFFrame.h
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/7.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, JRFFFrameType) {
    JRFFFrameTypeVideo,
    JRFFFrameTypeAVYUVVideo,
    JRFFFrameTypeCVYUVVideo,
    JRFFFrameTypeAudio,
    JRFFFrameTypeSubtitle,
    JRFFFrameTypeArkwork,
};

@class JRFFFrame;

@protocol JRFFFrameDelegate <NSObject>

- (void)frameDidStartPlaying:(JRFFFrame *)frame;
- (void)frameDidStopPlaying:(JRFFFrame *)frame;
- (void)frameDidCancel:(JRFFFrame *)frame;

@end

@interface JRFFFrame : NSObject

@property (weak, nonatomic) id<JRFFFrameDelegate> delegate;
@property (assign, nonatomic, readonly) BOOL playing;

@property (assign, nonatomic) JRFFFrameType type;
@property (assign, nonatomic) NSTimeInterval position;
@property (assign, nonatomic) NSTimeInterval duration;
@property (assign, nonatomic, readonly) int size;
@property (assign, nonatomic) int packetSize;


- (void)startPlaying;
- (void)stopPlaying;
- (void)cancel;


@end


@interface JRFFSubtileFrame : JRFFFrame

@end


@interface JRFFArtworkFrame : JRFFFrame

@property (nonatomic, strong) NSData * picture;

@end
